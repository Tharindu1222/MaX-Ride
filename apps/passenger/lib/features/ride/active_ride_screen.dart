import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
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
        '$status|${driver.latitude.toStringAsFixed(4)}|${dest.latitude.toStringAsFixed(4)}';
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
    final cancelLabel =
        noDrivers || status.startsWith('CANCELLED') ? 'Back to home' : 'Cancel';

    return Scaffold(
      appBar: AppBar(
        title: Text('Ride ${ride?['rideNumber'] ?? ''}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            timer?.cancel();
            context.go('/');
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: RideMap(
              pickup: pickupLatLng,
              dropoff: dropoffLatLng,
              driver: driverLatLng,
              routePoints: routePoints,
              myLocationEnabled: true,
              showRoute: routePoints.isEmpty,
            ),
          ),
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: maxForest,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.replaceAll('_', ' '),
                        style: const TextStyle(
                          color: maxLime,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (etaText != null && etaText!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          driverLatLng != null
                              ? 'Driver en route · $etaText'
                              : etaText!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '${ride?['pickupAddress'] ?? ''}\n→ ${ride?['dropoffAddress'] ?? ''}',
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                    ],
                  ),
                ),
                if (ride?['driver'] != null) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    title: Text(
                      ride!['driver']['user']?['fullName']?.toString() ??
                          'Driver',
                    ),
                    subtitle: Text(
                      ride!['driver']['user']?['phoneNumber']?.toString() ?? '',
                    ),
                    trailing: Text(
                      '★ ${ride!['driver']['averageRating'] ?? '-'}',
                    ),
                  ),
                ],
                if (ride?['estimatedFare'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Fare: LKR ${ride!['finalFare'] ?? ride!['estimatedFare']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                if (!completed)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _cancel,
                          child: Text(cancelLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
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
        ],
      ),
    );
  }
}
