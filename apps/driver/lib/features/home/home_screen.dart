import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/ride_map.dart';

/// Colombo Fort — MaX Ride demo zone (matches dispatch seed).
const LatLng kColomboFort = LatLng(6.9344, 79.8428);

/// Emulators often report Mountain View (US). Only use GPS if inside Sri Lanka.
bool isInSriLanka(double lat, double lng) {
  return lat >= 5.8 && lat <= 9.9 && lng >= 79.4 && lng <= 82.1;
}

LatLng sanitizeDriverLocation(LatLng raw) {
  if (isInSriLanka(raw.latitude, raw.longitude)) return raw;
  return kColomboFort;
}

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

  LatLng driverPos = kColomboFort;
  double? driverHeading;
  bool gpsLive = false;
  /// When true, keep map/server on Colombo Fort (ignores emulator US GPS).
  bool forceColomboDemo = true;
  bool followMe = true;
  String? locationStatus;
  List<LatLng> routePoints = [];
  String? routeDistanceText;
  String? routeDurationText;
  String? routeProvider;
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

  /// Navigation target based on trip stage.
  LatLng? get navDestination {
    switch (phase) {
      case _NavPhase.toPickup:
      case _NavPhase.atPickup:
        return pickupLatLng;
      case _NavPhase.toDropoff:
        return dropoffLatLng;
      default:
        return null;
    }
  }

  String get navTitle {
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
    pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOffers());
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

  /// Avoid Geolocator "Fused" client — it starts NMEA and can hard-crash emulators
  /// (JNI NewStringUTF / NmeaClient). Use classic LocationManager on Android.
  LocationSettings _safeLocationSettings({Duration? timeLimit}) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 5,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 3),
        timeLimit: timeLimit,
        useMSLAltitude: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 5,
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
          locationStatus ??= 'No GPS — using demo Colombo pin';
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
    gpsPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollGpsOnce();
    });
  }

  Future<void> _pollGpsOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _safeLocationSettings(
          timeLimit: const Duration(seconds: 8),
        ),
      );
      if (mounted) _applyGpsFix(pos);
    } catch (_) {
      // Keep last good fix; do not crash
      if (mounted && !gpsLive) {
        setState(() {
          locationStatus =
              'Waiting for GPS… Emulator: ⋯ → Location → set pin';
        });
      }
    }
  }

  void _applyGpsFix(Position pos) {
    final raw = LatLng(pos.latitude, pos.longitude);
    final inLk = isInSriLanka(raw.latitude, raw.longitude);

    // Emulator default is often Google HQ (US) — snaps to Colombo for demo rides.
    final next = (forceColomboDemo || !inLk) ? kColomboFort : raw;

    if (!mounted) return;
    setState(() {
      driverPos = next;
      if (inLk &&
          pos.heading.isFinite &&
          pos.heading >= 0 &&
          pos.heading <= 360) {
        driverHeading = pos.heading;
      }
      gpsLive = inLk && !forceColomboDemo;
      if (forceColomboDemo || !inLk) {
        locationStatus =
            'Colombo demo · ${next.latitude.toStringAsFixed(4)}, ${next.longitude.toStringAsFixed(4)}'
            '${inLk ? '' : ' (GPS was outside Sri Lanka)'}';
      } else {
        final acc =
            pos.accuracy.isFinite ? ' · ±${pos.accuracy.round()}m' : '';
        locationStatus =
            'Live · ${next.latitude.toStringAsFixed(5)}, ${next.longitude.toStringAsFixed(5)}$acc';
      }
    });

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
    if (forceColomboDemo) return kColomboFort;
    try {
      if (!await _ensureLocationPermission()) return kColomboFort;
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return sanitizeDriverLocation(
            LatLng(last.latitude, last.longitude),
          );
        }
      } catch (_) {}
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _safeLocationSettings(
          timeLimit: const Duration(seconds: 8),
        ),
      );
      return sanitizeDriverLocation(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      return kColomboFort;
    }
  }

  Future<void> _useColomboDemo() async {
    setState(() {
      forceColomboDemo = true;
      driverPos = kColomboFort;
      gpsLive = false;
      followMe = true;
      locationStatus =
          'Colombo demo · ${kColomboFort.latitude}, ${kColomboFort.longitude}';
    });
    await _pushLocation(force: kColomboFort);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location set to Colombo Fort — turn ONLINE to receive Sri Lanka rides',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        // Do not overwrite a live GPS fix with stale server coords
        if (!gpsLive) {
          final loc = me?['location'];
          if (loc is Map) {
            final p = latLngFrom(loc['latitude'], loc['longitude']);
            if (p != null) driverPos = p;
          }
        }
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

    final key =
        '${phase.name}|${driverPos.latitude.toStringAsFixed(4)},${driverPos.longitude.toStringAsFixed(4)}|'
        '${dest.latitude.toStringAsFixed(4)},${dest.longitude.toStringAsFixed(4)}';
    // Throttle identical route lookups slightly
    if (key == lastRouteKey && routePoints.isNotEmpty) return;

    setState(() => routeLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/maps/directions'
        '?originLat=${driverPos.latitude}&originLng=${driverPos.longitude}'
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
          ..add(driverPos)
          ..add(dest);
      }
      if (!mounted) return;
      setState(() {
        routePoints = pts;
        routeDistanceText = data['distanceText']?.toString();
        routeDurationText = data['durationText']?.toString();
        routeProvider = data['provider']?.toString();
        lastRouteKey = key;
        routeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        routePoints = [driverPos, dest];
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
      // Always report Colombo-sanitized location for dispatch
      final pos = forceColomboDemo
          ? kColomboFort
          : sanitizeDriverLocation(
              (await _readGps()) ?? driverPos,
            );
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
                'Online near ${pos.latitude.toStringAsFixed(3)}, '
                '${pos.longitude.toStringAsFixed(3)} — ready for Colombo rides',
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
      final pos = sanitizeDriverLocation(
        force ??
            (forceColomboDemo
                ? kColomboFort
                : ((await _readGps()) ?? driverPos)),
      );
      if (mounted) {
        setState(() => driverPos = pos);
      }
      final api = ref.read(apiClientProvider);
      await api.post('/drivers/me/location', {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        if (driverHeading != null) 'heading': driverHeading,
      });
      if (phase == _NavPhase.toPickup || phase == _NavPhase.toDropoff) {
        if ((DateTime.now().second % 20) < 5) {
          lastRouteKey = null;
          await _refreshRoute();
        }
      }
    } catch (_) {}
  }

  Future<void> _recenterOnMe() async {
    setState(() => followMe = true);
    if (forceColomboDemo) {
      setState(() => driverPos = kColomboFort);
      return;
    }
    if (!gpsLive) {
      await _startLiveLocation();
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/offers/$offerId/accept');
      setState(() {
        activeRide = Map<String, dynamic>.from(res['data'] as Map);
        offers = [];
        message = 'Accepted — navigate to passenger';
        lastRouteKey = null;
      });
      await _pushLocation();
      await _refreshRoute();
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
        message = 'Arrived at pickup';
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
        message = 'Trip started — navigate to drop-off';
        lastRouteKey = null;
      });
      await _refreshRoute();
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
      });

      try {
        await api.post('/drivers/me/online', {'online': true});
        await api.post('/drivers/me/location', {
          'latitude': driverPos.latitude,
          'longitude': driverPos.longitude,
        });
        setState(() => online = true);
        locationTimer?.cancel();
        locationTimer =
            Timer.periodic(const Duration(seconds: 5), (_) => _pushLocation());
      } catch (_) {}

      readyTimer?.cancel();
      readyTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _readyForNextTrip();
      });
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen live map
          // Full-screen map (deferred mount)
          if (mapMounted)
            RideMap(
              driver: driverPos,
              pickup: showActive ? pickupLatLng : offerPickup,
              dropoff: showActive
                  ? dropoffLatLng
                  : (phase == _NavPhase.idle ? offerDropoff : null),
              destination: navDestination,
              routePoints: routePoints,
              myLocationEnabled: false,
              followDriver: followMe && routePoints.length < 2,
              driverHeading: driverHeading,
              routeColor: phase == _NavPhase.toDropoff
                  ? const Color(0xFFC62828)
                  : const Color(0xFF1565C0),
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
              color: Color(0xFF1A2332),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: dAmber),
                    SizedBox(height: 12),
                    Text(
                      'Loading map…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          // Live GPS chip
          Positioned(
            left: 12,
            right: 12,
            top: topPad + 72,
            child: Row(
              children: [
                Flexible(
                  child: Material(
                    color: gpsLive
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF5D4037),
                    borderRadius: BorderRadius.circular(20),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            gpsLive ? Icons.gps_fixed : Icons.gps_not_fixed,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              locationStatus ??
                                  (gpsLive ? 'Live location' : 'No GPS yet'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: 'Recenter on me',
                    onPressed: _recenterOnMe,
                    icon: Icon(
                      Icons.my_location,
                      color: followMe ? dNavy : Colors.black45,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: forceColomboDemo ? dAmber : Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: 'Colombo demo location',
                    onPressed: _useColomboDemo,
                    icon: Icon(
                      Icons.flag,
                      color: forceColomboDemo ? dInk : dNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Top bar
          Positioned(
            left: 12,
            right: 12,
            top: topPad + 8,
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: dNavy,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MaX Driver',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            navTitle,
                            style: TextStyle(
                              color: online ? dAmber : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (routeDistanceText != null ||
                              routeDurationText != null)
                            Text(
                              [
                                if (routeDurationText != null)
                                  routeDurationText!,
                                if (routeDistanceText != null)
                                  routeDistanceText!,
                                if (routeProvider == 'GOOGLE_DIRECTIONS')
                                  'Google',
                              ].join(' · '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          if (routeLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _chipIcon(Icons.badge_outlined, () => context.push('/onboarding')),
                const SizedBox(width: 6),
                _chipIcon(Icons.account_balance_wallet_outlined,
                    () => context.push('/earnings')),
              ],
            ),
          ),

          // Bottom panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.white,
              elevation: 16,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Online toggle
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: dNavy,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      online ? 'ONLINE' : 'OFFLINE',
                                      style: TextStyle(
                                        color: online ? dAmber : Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Approval: $status',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: online,
                                activeThumbColor: dAmber,
                                onChanged: loading ? null : _toggleOnline,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!showActive) ...[
                          const Text(
                            'Incoming requests',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            forceColomboDemo
                                ? 'Demo location: Colombo Fort (needed for Sri Lanka rides).'
                                : 'GPS must be inside Sri Lanka to receive offers.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _useColomboDemo,
                            icon: const Icon(Icons.place, size: 18),
                            label: const Text('Use Colombo demo location'),
                          ),
                          const SizedBox(height: 4),
                          if (offers.isEmpty)
                            Text(
                              online
                                  ? 'No pending offers — stay online near Colombo'
                                  : 'Go online to receive passenger requests',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ...offers.map((o) {
                            final m = o as Map;
                            final ride = m['ride'] as Map?;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.trip_origin,
                                          color: Color(0xFF2E7D32), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ride?['pickupAddress']?.toString() ??
                                              'Pickup',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.flag,
                                          color: Color(0xFFC62828), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ride?['dropoffAddress']?.toString() ??
                                              'Drop-off',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'LKR ${ride?['estimatedFare']} · '
                                    '${m['pickupDistanceMeters']} m away',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          _acceptOffer(m['id'].toString()),
                                      child: const Text(
                                        'Accept & navigate to pickup',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          TextButton(
                            onPressed: _pollOffers,
                            child: const Text('Refresh offers'),
                          ),
                        ] else ...[
                          _phaseBanner(rideStatus),
                          const SizedBox(height: 8),
                          Text(
                            '${activeRide!['pickupAddress']}\n→ ${activeRide!['dropoffAddress']}',
                            style: const TextStyle(height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          if (rideStatus == 'DRIVER_ASSIGNED') ...[
                            ElevatedButton.icon(
                              onPressed: _arrived,
                              icon: const Icon(Icons.place),
                              label: const Text("I've arrived at pickup"),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                lastRouteKey = null;
                                _refreshRoute();
                              },
                              child: const Text('Refresh directions'),
                            ),
                          ],
                          if (rideStatus == 'DRIVER_ARRIVED') ...[
                            TextField(
                              controller: pinCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Passenger start PIN',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _start,
                              icon: const Icon(Icons.navigation),
                              label: const Text('Start trip → drop-off map'),
                            ),
                          ],
                          if (rideStatus == 'TRIP_STARTED') ...[
                            ElevatedButton.icon(
                              onPressed: _complete,
                              icon: const Icon(Icons.flag),
                              label: const Text('Complete trip at drop-off'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                lastRouteKey = null;
                                _refreshRoute();
                              },
                              child: const Text('Refresh drop-off directions'),
                            ),
                          ],
                          if (rideStatus == 'TRIP_COMPLETED') ...[
                            Text(
                              'Fare · LKR ${activeRide!['finalFare']}\n'
                              'Returning to requests…',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _readyForNextTrip,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: dAmber,
                                foregroundColor: dInk,
                              ),
                              child: const Text('Ready for next request'),
                            ),
                          ],
                        ],
                        if (message != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            message!,
                            style: const TextStyle(color: Colors.black87),
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
    Color bg;
    String label;
    switch (rideStatus) {
      case 'DRIVER_ASSIGNED':
        bg = const Color(0xFF1565C0);
        label = 'GO TO PICKUP';
        break;
      case 'DRIVER_ARRIVED':
        bg = const Color(0xFF2E7D32);
        label = 'WAIT FOR PIN';
        break;
      case 'TRIP_STARTED':
        bg = const Color(0xFFC62828);
        label = 'GO TO DROP-OFF';
        break;
      case 'TRIP_COMPLETED':
        bg = Colors.green.shade700;
        label = 'COMPLETED';
        break;
      default:
        bg = dNavy;
        label = rideStatus ?? '';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _chipIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: dInk),
        ),
      ),
    );
  }
}
