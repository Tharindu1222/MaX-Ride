import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../widgets/max_ui.dart';
import '../../widgets/ride_map.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key, required this.rideId});
  final String rideId;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  Map<String, dynamic>? ride;
  String? error;
  Timer? timer;
  List<LatLng> routePoints = [];
  String? etaText;
  String? lastRouteKey;

  LatLng? get pickupLatLng {
    final r = ride;
    if (r == null) return null;
    return latLngFrom(r['pickupLat'], r['pickupLng']);
  }

  LatLng? get dropoffLatLng {
    final r = ride;
    if (r == null) return null;
    return latLngFrom(r['dropoffLat'], r['dropoffLng']);
  }

  LatLng? get driverLatLng {
    final loc = ride?['driver']?['location'];
    if (loc is! Map) return null;
    return latLngFrom(loc['latitude'], loc['longitude']);
  }

  double? get driverHeading {
    final loc = ride?['driver']?['location'];
    if (loc is! Map) return null;
    return parseCoord(loc['heading'])?.toDouble();
  }

  String get driverEmoji {
    final code = ride?['category']?['code']?.toString().toUpperCase() ??
        ride?['vehicle']?['category']?['code']?.toString().toUpperCase();
    switch (code) {
      case 'TUKTUK':
        return '🛺';
      case 'VAN':
        return '🚐';
      default:
        return '🚗';
    }
  }

  bool get driverComingToPickup {
    final s = ride?['status']?.toString();
    return s == 'DRIVER_ASSIGNED' || s == 'DRIVER_ARRIVED';
  }

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/rides/${widget.rideId}');
      if (!mounted) return;
      setState(() {
        ride = Map<String, dynamic>.from(res['data'] as Map);
        error = null;
      });
      await _updatePassengerTrackRoute();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() => error = msg);
      if (msg.contains('401') || msg.toLowerCase().contains('session')) {
        timer?.cancel();
      }
    }
  }

  /// Show driver on map with route → pickup (approaching) or → drop-off (on trip).
  Future<void> _updatePassengerTrackRoute() async {
    final status = ride?['status']?.toString();
    final driver = driverLatLng;
    LatLng? dest;
    if (status == 'DRIVER_ASSIGNED' || status == 'DRIVER_ARRIVED') {
      dest = pickupLatLng;
    } else if (status == 'TRIP_STARTED') {
      dest = dropoffLatLng;
    } else {
      if (routePoints.isNotEmpty && mounted) {
        setState(() {
          routePoints = [];
          etaText = null;
          lastRouteKey = null;
        });
      }
      return;
    }
    if (driver == null || dest == null) return;

    final key =
        '$status|${driver.latitude.toStringAsFixed(5)}|${driver.longitude.toStringAsFixed(5)}|'
        '${dest.latitude.toStringAsFixed(5)}';
    if (key == lastRouteKey && routePoints.isNotEmpty) return;

    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        '/maps/directions'
        '?originLat=${driver.latitude}&originLng=${driver.longitude}'
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
      if (!mounted) return;
      setState(() {
        routePoints = pts.length >= 2 ? pts : [driver, dest!];
        etaText = [
          if (data['durationText'] != null) data['durationText'].toString(),
          if (data['distanceText'] != null) data['distanceText'].toString(),
        ].join(' · ');
        lastRouteKey = key;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        routePoints = [driver, dest!];
        lastRouteKey = key;
      });
    }
  }

  Future<void> _cancel() async {
    timer?.cancel();
    final status = ride?['status']?.toString();
    const terminal = {
      'NO_DRIVERS_AVAILABLE',
      'CANCELLED_BY_PASSENGER',
      'CANCELLED_BY_DRIVER',
      'CANCELLED_BY_SYSTEM',
      'TRIP_COMPLETED',
    };
    if (status == null || !terminal.contains(status)) {
      try {
        final api = ref.read(apiClientProvider);
        await api.post('/rides/${widget.rideId}/cancel', {
          'reason': 'Passenger cancelled',
        });
      } catch (_) {}
    }
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _searchAgain() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/${widget.rideId}/search-again');
      if (!mounted) return;
      setState(() {
        ride = Map<String, dynamic>.from(res['data'] as Map);
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  Future<void> _sos() async {
    final api = ref.read(apiClientProvider);
    await api.post('/safety/sos', {
      'rideId': widget.rideId,
      'notes': 'Passenger SOS from app',
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS sent to operations')),
    );
  }

  Future<void> _rate() async {
    final api = ref.read(apiClientProvider);
    await api.post('/rides/${widget.rideId}/rate', {
      'score': 5,
      'comment': 'Great ride',
    });
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final status = ride?['status']?.toString() ?? 'Loading…';
    final completed = status == 'TRIP_COMPLETED';
    final noDrivers = status == 'NO_DRIVERS_AVAILABLE';
    final searching =
        status == 'SEARCHING' || status == 'DRIVER_OFFERED' || status == 'REQUESTED';
    final coming = status == 'DRIVER_ASSIGNED';
    final arrived = status == 'DRIVER_ARRIVED';
    final onTrip = status == 'TRIP_STARTED';
    final statusLabel = noDrivers
        ? 'No drivers nearby'
        : searching
            ? 'Finding a driver…'
            : coming
                ? 'Driver coming to you $driverEmoji'
                : arrived
                    ? 'Your driver has arrived'
                    : onTrip
                        ? 'On the way $driverEmoji'
                        : status.replaceAll('_', ' ');
    final cancelLabel =
        noDrivers || status.startsWith('CANCELLED') ? 'Back to home' : 'Cancel ride';
    final driverName =
        ride?['driver']?['user']?['fullName']?.toString() ?? 'Your driver';
    final driverPhone =
        ride?['driver']?['user']?['phoneNumber']?.toString() ?? '';
    final rating = ride?['driver']?['averageRating'];
    final fare = ride?['finalFare'] ?? ride?['estimatedFare'];

    return Scaffold(
      backgroundColor: maxSand,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RideMap(
            pickup: pickupLatLng,
            dropoff: driverComingToPickup ? null : dropoffLatLng,
            driver: driverLatLng,
            driverEmoji: driverLatLng != null ? driverEmoji : null,
            driverHeading: driverHeading,
            passengerEmoji: pickupLatLng != null ? '🧍' : null,
            followLiveDriver: driverLatLng != null &&
                (driverComingToPickup || status == 'TRIP_STARTED'),
            routePoints: routePoints,
            myLocationEnabled: true,
            showRoute: routePoints.isEmpty && !driverComingToPickup,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                MaxCircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back to home',
                  onTap: () {
                    timer?.cancel();
                    context.go('/');
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MaxGlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text(
                      ride?['rideNumber']?.toString() ?? 'Your ride',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MaxSheetHandle(),
                      const SizedBox(height: 14),
                      Text(
                        statusLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (etaText != null && etaText!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          driverComingToPickup
                              ? 'Arriving in $etaText'
                              : etaText!,
                          style: const TextStyle(
                            color: maxMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        ride?['pickupAddress']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ride?['dropoffAddress']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: maxMuted),
                      ),
                      if (ride?['driver'] != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: maxSand,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: maxForest,
                                child: Text(
                                  driverEmoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driverName,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      driverPhone,
                                      style: const TextStyle(color: maxMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (rating != null)
                                Text(
                                  '★ $rating',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (fare != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Fare · LKR $fare',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: maxForest,
                          ),
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (noDrivers) ...[
                        const Text(
                          'No one accepted yet. Keep a driver nearby online, then search again.',
                          style: TextStyle(color: maxMuted, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _searchAgain,
                          child: const Text('Search again'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _cancel,
                          child: Text(cancelLabel),
                        ),
                      ] else if (!completed)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancel,
                                child: Text(cancelLabel),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB42318),
                                ),
                                onPressed: _sos,
                                child: const Text('SOS'),
                              ),
                            ),
                          ],
                        )
                      else
                        ElevatedButton(
                          onPressed: _rate,
                          child: const Text('Rate 5★ & done'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
