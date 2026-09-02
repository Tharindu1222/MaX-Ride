import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_client.dart';
import '../../core/dev_env.dart';
import '../../core/theme.dart';
import '../../widgets/driver_ui.dart';
import '../../widgets/ride_map.dart';

/// Driver map phases for navigation guidance.
enum _NavPhase {
  idle,
  toPickup,
  atPickup,
  toDropoff,
  completed,
}

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  Map<String, dynamic>? me;
  List offers = [];
  Map<String, dynamic>? activeRide;
  bool online = false;
  bool loading = false;
  String? message;
  final pinCtrl = TextEditingController();
  Timer? locationTimer;
  Timer? pollTimer;
  Timer? readyTimer;
  Timer? gpsPollTimer;
  DateTime? lastServerPush;

  LatLng? driverPos;
  double? driverHeading;
  bool gpsLive = false;
  /// Real phones/tablets: Fused GPS. Emulators: LocationManager (crash workaround).
  bool _physicalDevice = true;
  bool followMe = true;
  bool navigating = false;
  String? locationStatus;
  List<LatLng> routePoints = [];
  String? routeDistanceText;
  String? routeDurationText;
  String? routeProvider;
  int? routeDistanceMeters;
  int? routeDurationSeconds;
  DateTime? lastRerouteAt;
  bool routeLoading = false;
  String? lastRouteKey;
  /// Delay embedding GoogleMap until activity/GL is ready (emulator crash fix).
  bool mapMounted = false;

  static const _inProgress = {
    'DRIVER_ASSIGNED',
    'DRIVER_ARRIVED',
    'TRIP_STARTED',
  };

  _NavPhase get phase {
    final s = activeRide?['status']?.toString();
    if (s == 'TRIP_COMPLETED') return _NavPhase.completed;
    if (s == 'TRIP_STARTED') return _NavPhase.toDropoff;
    if (s == 'DRIVER_ARRIVED') return _NavPhase.atPickup;
    if (s == 'DRIVER_ASSIGNED') return _NavPhase.toPickup;
    return _NavPhase.idle;
  }

  LatLng? get pickupLatLng => activeRide == null
      ? null
      : latLngFrom(activeRide!['pickupLat'], activeRide!['pickupLng']);

  LatLng? get dropoffLatLng => activeRide == null
      ? null
      : latLngFrom(activeRide!['dropoffLat'], activeRide!['dropoffLng']);

  String get driverEmoji {
    String? code;
    final cat = activeRide?['category'];
    if (cat is Map) code = cat['code']?.toString();
    if (code == null || code.isEmpty) {
      final assignments = me?['assignments'];
      if (assignments is List && assignments.isNotEmpty) {
        final first = assignments.first;
        if (first is Map) {
          final vehicle = first['vehicle'];
          if (vehicle is Map) {
            final vcat = vehicle['category'];
            if (vcat is Map) code = vcat['code']?.toString();
          }
        }
      }
    }
    switch (code?.toUpperCase()) {
      case 'TUKTUK':
        return '🛺';
      case 'VAN':
        return '🚐';
      default:
        return '🚗';
    }
  }

  /// Navigation target based on trip stage.
  /// Pickup only until the driver taps "I've arrived"; then drop-off.
  LatLng? get navDestination {
    switch (phase) {
      case _NavPhase.toPickup:
        return pickupLatLng;
      case _NavPhase.atPickup:
      case _NavPhase.toDropoff:
        return dropoffLatLng;
      default:
        return null;
    }
  }

  String get navTitle {
    if (navigating && phase == _NavPhase.toPickup) {
      return 'Live navigation to pickup';
    }
    if (navigating && phase == _NavPhase.toDropoff) {
      return 'Live navigation to drop-off';
    }
    switch (phase) {
      case _NavPhase.toPickup:
        return 'Navigate to passenger pickup';
      case _NavPhase.atPickup:
        return 'At pickup — enter passenger PIN';
      case _NavPhase.toDropoff:
        return 'Navigate to passenger drop-off';
      case _NavPhase.completed:
        return 'Trip completed';
      case _NavPhase.idle:
        return online ? 'Waiting for requests' : 'You are offline';
    }
  }

  @override
  void initState() {
    super.initState();
    // Do NOT start GPS or GoogleMap on the exact same frame as first paint —
    // concurrent GMS maps_core + LocationManager init kills some emulators.
    _load();
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOffers());
    isPhysicalDevice().then((v) {
      if (mounted) _physicalDevice = v;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => mapMounted = true);
      });
    });
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    pollTimer?.cancel();
    readyTimer?.cancel();
    gpsPollTimer?.cancel();
    pinCtrl.dispose();
    super.dispose();
  }

  /// Fused GPS on real devices. LocationManager only on emulators (Fused can crash them).
  LocationSettings _safeLocationSettings({
    Duration? timeLimit,
    bool highAccuracy = false,
  }) {
    final accuracy =
        highAccuracy ? LocationAccuracy.high : LocationAccuracy.best;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: 0,
        forceLocationManager: !_physicalDevice,
        intervalDuration: const Duration(seconds: 2),
        timeLimit: timeLimit,
        useMSLAltitude: false,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: 0,
      timeLimit: timeLimit,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (mounted) {
          setState(() => locationStatus = 'Location OFF — enable GPS');
        }
        return false;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => locationStatus = 'Location permission denied');
        }
        return false;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => locationStatus = 'Allow location in App settings');
        }
        return false;
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => locationStatus = 'Location check failed');
      }
      return false;
    }
  }

  /// Poll GPS with safe settings (no Fused/NMEA stream) so the process does not crash.
  Future<void> _startLiveLocation() async {
    gpsPollTimer?.cancel();

    final ok = await _ensureLocationPermission();
    if (!ok) {
      if (mounted) {
        setState(() {
          gpsLive = false;
          locationStatus ??= 'Location off — enable GPS';
        });
      }
      return;
    }

    // Last known does not start NMEA listeners
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _applyGpsFix(last);
      }
    } catch (_) {}

    // One-shot safe read
    await _pollGpsOnce();

    // Periodic poll — more stable than getPositionStream on emulators
    gpsPollTimer?.cancel();
    gpsPollTimer = Timer.periodic(
      Duration(seconds: navigating ? 2 : 5),
      (_) => _pollGpsOnce(),
    );
  }

  Future<void> _pollGpsOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _safeLocationSettings(
          timeLimit: const Duration(seconds: 12),
          highAccuracy: true,
        ),
      );
      if (mounted) _applyGpsFix(pos);
    } catch (_) {
      // Keep last good fix; do not crash
      if (mounted && !gpsLive) {
        setState(() {
          locationStatus =
              'Waiting for GPS… go outdoors and tap locate';
        });
      }
    }
  }

  void _applyGpsFix(Position pos) {
    final next = LatLng(pos.latitude, pos.longitude);
    if (!mounted) return;
    setState(() {
      driverPos = next;
      if (pos.heading.isFinite && pos.heading >= 0 && pos.heading <= 360) {
        driverHeading = pos.heading;
      }
      gpsLive = true;
      final acc =
          pos.accuracy.isFinite ? ' · ±${pos.accuracy.round()}m' : '';
      locationStatus =
          'Live · ${next.latitude.toStringAsFixed(5)}, ${next.longitude.toStringAsFixed(5)}$acc';
    });

    if (navigating) {
      _advanceAlongRoute(next);
    }

    if (online ||
        phase == _NavPhase.toPickup ||
        phase == _NavPhase.toDropoff ||
        phase == _NavPhase.atPickup) {
      final now = DateTime.now();
      if (lastServerPush == null ||
          now.difference(lastServerPush!) > const Duration(seconds: 4)) {
        lastServerPush = now;
        _pushLocation(force: next);
      }
    }
  }

  Future<LatLng?> _readGps() async {
    try {
      if (!await _ensureLocationPermission()) return driverPos;
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: _safeLocationSettings(
            timeLimit: const Duration(seconds: 12),
            highAccuracy: true,
          ),
        );
        return LatLng(pos.latitude, pos.longitude);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LatLng(last.latitude, last.longitude);
        }
      }
      return driverPos;
    } catch (_) {
      return driverPos;
    }
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/drivers/me');
      if (!mounted) return;
      setState(() {
        me = Map<String, dynamic>.from(res['data'] as Map);
        online = me?['operationalStatus'] == 'ONLINE' ||
            me?['operationalStatus'] == 'BUSY' ||
            me?['operationalStatus'] == 'ON_TRIP';
      });
      if (online) {
        locationTimer?.cancel();
        locationTimer =
            Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
      }
      await _pollOffers();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
  }

  Future<void> _pollOffers() async {
    try {
      final api = ref.read(apiClientProvider);
      final o = await api.get('/drivers/me/offers');
      final a = await api.get('/drivers/me/active-ride');
      if (!mounted) return;

      final prevStatus = activeRide?['status']?.toString();
      setState(() {
        offers = (o['data'] as List?) ?? [];
        if (offers.isNotEmpty &&
            activeRide?['status']?.toString() == 'TRIP_COMPLETED') {
          activeRide = null;
        }
        final ad = a['data'];
        if (ad != null && ad is Map) {
          activeRide = Map<String, dynamic>.from(ad);
        } else {
          final localStatus = activeRide?['status']?.toString();
          if (localStatus != 'TRIP_COMPLETED') {
            activeRide = null;
          }
        }
      });

      final nextStatus = activeRide?['status']?.toString();
      if (nextStatus != prevStatus ||
          (activeRide != null && routePoints.isEmpty)) {
        await _refreshRoute();
      }
    } catch (_) {}
  }

  Future<void> _refreshRoute() async {
    final dest = navDestination;
    if (dest == null || phase == _NavPhase.idle || phase == _NavPhase.completed) {
      if (routePoints.isNotEmpty && mounted) {
        setState(() {
          routePoints = [];
          routeDistanceText = null;
          routeDurationText = null;
          lastRouteKey = null;
        });
      }
      return;
    }

    final origin = driverPos;
    if (origin == null) return;

    final key =
        '${phase.name}|${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}|'
        '${dest.latitude.toStringAsFixed(4)},${dest.longitude.toStringAsFixed(4)}';
    // Throttle identical route lookups slightly
    if (key == lastRouteKey && routePoints.isNotEmpty) return;

    setState(() => routeLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/maps/directions'
        '?originLat=${origin.latitude}&originLng=${origin.longitude}'
        '&destLat=${dest.latitude}&destLng=${dest.longitude}',
      );
      final data = res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : res;
      final pts = <LatLng>[];
      final raw = data['points'];
      if (raw is List) {
        for (final p in raw) {
          if (p is Map) {
            final ll = latLngFrom(p['lat'], p['lng']);
            if (ll != null) pts.add(ll);
          }
        }
      }
      if (pts.length < 2) {
        pts
          ..clear()
          ..add(origin)
          ..add(dest);
      }
      if (!mounted) return;
      setState(() {
        routePoints = pts;
        routeDistanceText = data['distanceText']?.toString();
        routeDurationText = data['durationText']?.toString();
        routeProvider = data['provider']?.toString();
        final dm = data['distanceMeters'];
        final ds = data['durationSeconds'];
        routeDistanceMeters = dm is num ? dm.round() : int.tryParse('$dm');
        routeDurationSeconds = ds is num ? ds.round() : int.tryParse('$ds');
        lastRouteKey = key;
        routeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        routePoints = [origin, dest];
        routeLoading = false;
        message = 'Route unavailable — showing straight line';
      });
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/drivers/me/online', {'online': value});
      final pos = await _readGps();
      if (pos == null) {
        setState(() {
          loading = false;
          message = 'Need live GPS to go online';
        });
        return;
      }
      setState(() => driverPos = pos);
      await api.post('/drivers/me/location', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'heading': 0,
      });
      setState(() => online = value);
      if (value) {
        locationTimer?.cancel();
        locationTimer =
            Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
        // Push again so GEO is fresh after online flip
        await _pushLocation(force: pos);
        await _pollOffers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Online at ${pos.latitude.toStringAsFixed(5)}, '
                '${pos.longitude.toStringAsFixed(5)}',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        locationTimer?.cancel();
      }
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pushLocation({LatLng? force}) async {
    try {
      final pos = force ?? (await _readGps());
      if (pos == null) return;
      if (mounted) {
        setState(() => driverPos = pos);
      }
      final api = ref.read(apiClientProvider);
      await api.post('/drivers/me/location', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        if (driverHeading != null) 'heading': driverHeading,
      });
      if (phase == _NavPhase.toPickup ||
          phase == _NavPhase.atPickup ||
          phase == _NavPhase.toDropoff) {
        await _maybeReroute();
      }
    } catch (_) {}
  }

  String _fmtDistance(double meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  String _fmtDuration(int seconds) {
    final mins = (seconds / 60).ceil().clamp(1, 999);
    return '$mins min';
  }

  void _advanceAlongRoute(LatLng here) {
    if (!navigating || routePoints.length < 2) return;
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < routePoints.length; i++) {
      final d = Geolocator.distanceBetween(
        here.latitude,
        here.longitude,
        routePoints[i].latitude,
        routePoints[i].longitude,
      );
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    final dest = navDestination;
    final skip = best < 18 ? nearest + 1 : nearest;
    final remaining = <LatLng>[
      here,
      ...routePoints.skip(skip.clamp(0, routePoints.length)),
    ];
    if (dest != null &&
        (remaining.length < 2 || remaining.last != dest)) {
      remaining.add(dest);
    }

    double meters = 0;
    for (var i = 1; i < remaining.length; i++) {
      meters += Geolocator.distanceBetween(
        remaining[i - 1].latitude,
        remaining[i - 1].longitude,
        remaining[i].latitude,
        remaining[i].longitude,
      );
    }

    if (!mounted) return;
    setState(() {
      routePoints = remaining.length >= 2
          ? remaining
          : (dest != null ? [here, dest] : remaining);
      if (meters > 0) {
        routeDistanceText = _fmtDistance(meters);
        final fullM = routeDistanceMeters;
        final fullS = routeDurationSeconds;
        if (fullM != null && fullM > 0 && fullS != null) {
          routeDurationText =
              _fmtDuration((fullS * (meters / fullM)).round());
        }
      }
    });

    if (best > 90) {
      _maybeReroute();
    }
  }

  Future<void> _maybeReroute({bool force = false}) async {
    if (!navigating && !force) return;
    final now = DateTime.now();
    if (!force &&
        lastRerouteAt != null &&
        now.difference(lastRerouteAt!) < const Duration(seconds: 12)) {
      return;
    }
    lastRerouteAt = now;
    lastRouteKey = null;
    await _refreshRoute();
  }

  Future<void> _beginInAppNavigation() async {
    if (!mounted) return;
    setState(() {
      navigating = true;
      followMe = true;
    });
    lastRouteKey = null;
    await _startLiveLocation();
    await _refreshRoute();
  }

  Future<void> _openGoogleNavigation(LatLng dest) async {
    final destQ = '${dest.latitude},${dest.longitude}';
    final origin = driverPos;
    final uris = <Uri>[
      Uri.parse('google.navigation:q=$destQ&mode=d'),
      if (origin != null)
        Uri.parse(
          'comgooglemaps://?saddr=${origin.latitude},${origin.longitude}&daddr=$destQ&directionsmode=driving',
        ),
      Uri.parse(
        origin == null
            ? 'https://www.google.com/maps/dir/?api=1'
                '&destination=$destQ'
                '&travelmode=driving'
                '&dir_action=navigate'
            : 'https://www.google.com/maps/dir/?api=1'
                '&origin=${origin.latitude},${origin.longitude}'
                '&destination=$destQ'
                '&travelmode=driving'
                '&dir_action=navigate',
      ),
    ];

    for (final uri in uris) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open Google Maps. Install Google Maps and try again.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _navigateForPhase() async {
    final dest = navDestination;
    if (dest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pickup or drop-off location yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _beginInAppNavigation();
  }

  Future<void> _recenterOnMe() async {
    setState(() {
      followMe = true;
      locationStatus = 'Getting GPS…';
    });
    if (!await _ensureLocationPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(locationStatus ?? 'Turn on location permission'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _safeLocationSettings(
          timeLimit: const Duration(seconds: 15),
          highAccuracy: true,
        ),
      );
      if (!mounted) return;
      _applyGpsFix(pos);
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          _applyGpsFix(last);
        } else if (mounted) {
          setState(() => locationStatus = 'GPS timeout — try outdoors');
        }
      } catch (_) {
        if (mounted) {
          setState(() => locationStatus = 'GPS failed — enable Location');
        }
      }
    }
    if (gpsPollTimer == null) {
      await _startLiveLocation();
    }
    if (navigating) {
      await _beginInAppNavigation();
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/offers/$offerId/accept');
      setState(() {
        activeRide = Map<String, dynamic>.from(res['data'] as Map);
        offers = [];
        message = 'Accepted — in-app navigation to pickup';
        lastRouteKey = null;
        navigating = true;
        followMe = true;
      });
      await _pushLocation();
      await _beginInAppNavigation();
    } catch (e) {
      setState(() => message = e.toString());
    }
  }

  Future<void> _arrived() async {
    if (activeRide == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/${activeRide!['id']}/arrived');
      setState(() {
        activeRide = Map<String, dynamic>.from(res['data'] as Map);
        message = 'Arrived at pickup — showing drop-off';
        lastRouteKey = null;
        navigating = false;
      });
      await _refreshRoute();
    } catch (e) {
      setState(() => message = e.toString());
    }
  }

  Future<void> _start() async {
    if (activeRide == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/${activeRide!['id']}/start', {
        'pin': pinCtrl.text.trim(),
      });
      setState(() {
        activeRide = Map<String, dynamic>.from(res['data'] as Map);
        message = 'Trip started — live navigation to drop-off';
        lastRouteKey = null;
        navigating = true;
        followMe = true;
      });
      await _beginInAppNavigation();
    } catch (e) {
      setState(() => message = e.toString());
    }
  }

  Future<void> _complete() async {
    if (activeRide == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/${activeRide!['id']}/complete');
      final completed = Map<String, dynamic>.from(res['data'] as Map);
      final fare = completed['finalFare'];

      setState(() {
        activeRide = {...completed, 'status': 'TRIP_COMPLETED'};
        message = 'Trip completed · LKR $fare';
        routePoints = [];
        navigating = false;
        followMe = true;
      });

      try {
        await api.post('/drivers/me/online', {'online': true});
        final here = driverPos ?? await _readGps();
        if (here != null) {
          await api.post('/drivers/me/location', {
            'latitude': here.latitude,
            'longitude': here.longitude,
          });
        }
        setState(() => online = true);
        locationTimer?.cancel();
        locationTimer =
            Timer.periodic(const Duration(seconds: 5), (_) => _pushLocation());
      } catch (e) {
        if (mounted) {
          setState(() => message = 'Could not go back online: $e');
        }
      }

      readyTimer?.cancel();
      if (mounted) await _readyForNextTrip();
    } catch (e) {
      setState(() => message = e.toString());
    }
  }

  Future<void> _readyForNextTrip() async {
    readyTimer?.cancel();
    pinCtrl.clear();
    setState(() {
      activeRide = null;
      routePoints = [];
      routeDistanceText = null;
      routeDurationText = null;
      lastRouteKey = null;
      navigating = false;
      followMe = true;
      routeDistanceMeters = null;
      routeDurationSeconds = null;
      message = online
          ? 'Ready for next request — waiting for offers…'
          : 'Go online to receive new requests';
    });
    await _pollOffers();
  }

  @override
  Widget build(BuildContext context) {
    final status = me?['approvalStatus']?.toString() ?? '…';
    final rideStatus = activeRide?['status']?.toString();
    final showActive = activeRide != null &&
        (_inProgress.contains(rideStatus) || rideStatus == 'TRIP_COMPLETED');
    final topPad = MediaQuery.paddingOf(context).top;

    // Markers for offer preview (first offer)
    LatLng? offerPickup;
    LatLng? offerDropoff;
    if (!showActive && offers.isNotEmpty) {
      final ride = (offers.first as Map)['ride'] as Map?;
      if (ride != null) {
        offerPickup = latLngFrom(ride['pickupLat'], ride['pickupLng']);
        offerDropoff = latLngFrom(ride['dropoffLat'], ride['dropoffLng']);
      }
    }

    return Scaffold(
      backgroundColor: maxSand,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (mapMounted)
            RideMap(
              driver: driverPos,
              pickup: showActive
                  ? (phase == _NavPhase.toPickup ? pickupLatLng : null)
                  : offerPickup,
              dropoff: showActive
                  ? ((phase == _NavPhase.atPickup ||
                          phase == _NavPhase.toDropoff)
                      ? dropoffLatLng
                      : null)
                  : (phase == _NavPhase.idle ? offerDropoff : null),
              destination: navDestination,
              routePoints: routePoints,
              myLocationEnabled: false,
              followDriver: followMe,
              navigationMode: navigating && followMe,
              driverHeading: driverHeading,
              driverEmoji: driverEmoji,
              passengerEmoji: (showActive && phase == _NavPhase.toPickup) ||
                      (!showActive && offerPickup != null)
                  ? '🧍'
                  : null,
              routeColor: (phase == _NavPhase.atPickup ||
                      phase == _NavPhase.toDropoff)
                  ? maxDropoff
                  : maxForest,
              onMapCreated: (_) {
                if (gpsPollTimer == null) {
                  Future.delayed(const Duration(milliseconds: 900), () {
                    if (mounted) _startLiveLocation();
                  });
                }
              },
              onCameraMoveStarted: () {
                if (followMe) setState(() => followMe = false);
              },
            )
          else
            const ColoredBox(
              color: maxForest,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: maxLime),
                    SizedBox(height: 12),
                    Text(
                      'Loading map…',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            top: topPad + 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DriverGlassCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: online ? maxPickup : maxMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'MaX Driver',
                              style: TextStyle(
                                color: maxMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          navTitle,
                          style: const TextStyle(
                            color: maxInk,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (routeDistanceText != null ||
                            routeDurationText != null)
                          Text(
                            [
                              if (routeDurationText != null) routeDurationText!,
                              if (routeDistanceText != null) routeDistanceText!,
                              if (navigating) 'Live',
                            ].join(' · '),
                            style: const TextStyle(
                              color: maxMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (routeLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: maxForest,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DriverCircleButton(
                  icon: Icons.badge_outlined,
                  tooltip: 'Driver profile',
                  onTap: () => context.push('/onboarding'),
                ),
                const SizedBox(width: 8),
                DriverCircleButton(
                  icon: Icons.account_balance_wallet_outlined,
                  tooltip: 'Earnings',
                  onTap: () => context.push('/earnings'),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.42 + 16,
            child: Column(
              children: [
                DriverCircleButton(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Recenter on me',
                  emphasized: followMe,
                  onTap: _recenterOnMe,
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: maxSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: maxShadowSoft,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.44,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DriverSheetHandle(),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: online ? maxForest : maxSand,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      online ? "You're online" : "You're offline",
                                      style: TextStyle(
                                        color: online ? Colors.white : maxInk,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      status == 'APPROVED'
                                          ? 'Approved to drive'
                                          : status.replaceAll('_', ' '),
                                      style: TextStyle(
                                        color: online
                                            ? Colors.white.withValues(alpha: 0.75)
                                            : maxMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Semantics(
                                label: online ? 'Go offline' : 'Go online',
                                toggled: online,
                                child: Switch(
                                  value: online,
                                  activeThumbColor: maxLime,
                                  activeTrackColor:
                                      maxLime.withValues(alpha: 0.35),
                                  onChanged: loading ? null : _toggleOnline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              gpsLive
                                  ? Icons.gps_fixed_rounded
                                  : Icons.gps_not_fixed_rounded,
                              size: 16,
                              color: gpsLive ? maxPickup : maxMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                locationStatus ??
                                    (gpsLive
                                        ? 'Live GPS'
                                        : 'Waiting for GPS'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: maxMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (!showActive) ...[
                          if (offers.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: [
                                  Text(
                                    driverEmoji,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    online
                                        ? 'No requests yet'
                                        : 'Go online to get rides',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    online
                                        ? 'Stay nearby. New offers appear here.'
                                        : 'Turn on the switch above when you are ready to drive.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: maxMuted,
                                      height: 1.4,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _pollOffers,
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...offers.map((o) {
                              final m = o as Map;
                              final ride = m['ride'] as Map?;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: maxSand,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.radio_button_checked,
                                          color: maxPickup,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ride?['pickupAddress']?.toString() ??
                                                'Pickup',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(left: 7, top: 2, bottom: 2),
                                      child: SizedBox(
                                        height: 10,
                                        child: VerticalDivider(
                                          color: maxLine,
                                          thickness: 2,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.flag_rounded,
                                          color: maxDropoff,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ride?['dropoffAddress']
                                                    ?.toString() ??
                                                'Drop-off',
                                            style: const TextStyle(
                                              color: maxMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'LKR ${ride?['estimatedFare']} · '
                                      '${m['pickupDistanceMeters']} m away',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: maxForest,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _acceptOffer(m['id'].toString()),
                                        child: const Text('Accept ride'),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ] else ...[
                          _phaseBanner(rideStatus),
                          const SizedBox(height: 10),
                          Text(
                            phase == _NavPhase.toPickup
                                ? activeRide!['pickupAddress']?.toString() ?? ''
                                : (phase == _NavPhase.atPickup ||
                                        phase == _NavPhase.toDropoff)
                                    ? activeRide!['dropoffAddress']
                                            ?.toString() ??
                                        ''
                                    : '${activeRide!['pickupAddress']}\n${activeRide!['dropoffAddress']}',
                            style: const TextStyle(
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (rideStatus == 'DRIVER_ASSIGNED') ...[
                            ElevatedButton.icon(
                              onPressed: _navigateForPhase,
                              icon: const Icon(Icons.navigation_rounded),
                              label: Text(
                                navigating
                                    ? 'Recenter navigation'
                                    : 'Go to pickup',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _arrived,
                              child: const Text("I've arrived"),
                            ),
                            TextButton(
                              onPressed: () {
                                final dest = pickupLatLng;
                                if (dest != null) _openGoogleNavigation(dest);
                              },
                              child: const Text('Open in Google Maps'),
                            ),
                          ],
                          if (rideStatus == 'DRIVER_ARRIVED') ...[
                            TextField(
                              controller: pinCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Passenger PIN',
                                hintText: '4-digit start PIN',
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _start,
                              icon: const Icon(Icons.navigation_rounded),
                              label: const Text('Start trip'),
                            ),
                          ],
                          if (rideStatus == 'TRIP_STARTED') ...[
                            ElevatedButton.icon(
                              onPressed: _navigateForPhase,
                              icon: const Icon(Icons.navigation_rounded),
                              label: Text(
                                navigating
                                    ? 'Recenter navigation'
                                    : 'Go to drop-off',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _complete,
                              child: const Text('Complete trip'),
                            ),
                            TextButton(
                              onPressed: () {
                                final dest = dropoffLatLng;
                                if (dest != null) _openGoogleNavigation(dest);
                              },
                              child: const Text('Open in Google Maps'),
                            ),
                          ],
                          if (rideStatus == 'TRIP_COMPLETED') ...[
                            Text(
                              'Fare · LKR ${activeRide!['finalFare']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: maxForest,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Ready for the next request.',
                              style: TextStyle(color: maxMuted),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _readyForNextTrip,
                              child: const Text('Find next ride'),
                            ),
                          ],
                        ],
                        if (message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            message!,
                            style: const TextStyle(
                              color: maxMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseBanner(String? rideStatus) {
    String label;
    Color bg;
    Color fg;
    final canNavigate =
        rideStatus == 'DRIVER_ASSIGNED' || rideStatus == 'TRIP_STARTED';
    switch (rideStatus) {
      case 'DRIVER_ASSIGNED':
        bg = maxForest;
        fg = Colors.white;
        label = navigating ? 'Navigating to pickup' : 'Head to pickup';
        break;
      case 'DRIVER_ARRIVED':
        bg = const Color(0x1A0F3D2E);
        fg = maxForest;
        label = 'Ask for the passenger PIN';
        break;
      case 'TRIP_STARTED':
        bg = maxForest;
        fg = Colors.white;
        label = navigating ? 'Navigating to drop-off' : 'Head to drop-off';
        break;
      case 'TRIP_COMPLETED':
        bg = const Color(0x1A0F3D2E);
        fg = maxForest;
        label = 'Trip completed';
        break;
      default:
        bg = maxSand;
        fg = maxInk;
        label = (rideStatus ?? '').replaceAll('_', ' ');
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canNavigate ? _navigateForPhase : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (canNavigate) ...[
                Icon(Icons.navigation_rounded, color: fg, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (canNavigate)
                Text(
                  navigating ? 'In app' : 'Start',
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
