import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

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

  static const _inProgress = {
    'DRIVER_ASSIGNED',
    'DRIVER_ARRIVED',
    'TRIP_STARTED',
  };

  @override
  void initState() {
    super.initState();
    _load();
    pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOffers());
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    pollTimer?.cancel();
    readyTimer?.cancel();
    super.dispose();
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

      setState(() {
        offers = (o['data'] as List?) ?? [];
        final ad = a['data'];
        if (ad != null && ad is Map) {
          // Server has an in-progress ride — take it
          activeRide = Map<String, dynamic>.from(ad);
        } else {
          // No active ride on server: clear local trip unless we're briefly
          // showing the TRIP_COMPLETED celebration screen.
          final localStatus = activeRide?['status']?.toString();
          if (localStatus != 'TRIP_COMPLETED') {
            activeRide = null;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/drivers/me/online', {'online': value});
      await api.post('/drivers/me/location', {
        'latitude': 6.9344,
        'longitude': 79.8428,
        'heading': 0,
      });
      setState(() => online = value);
      if (value) {
        locationTimer?.cancel();
        locationTimer =
            Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
        await _pollOffers();
      } else {
        locationTimer?.cancel();
      }
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pushLocation() async {
    try {
      double lat = 6.9344;
      double lng = 79.8428;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.low),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}
      final api = ref.read(apiClientProvider);
      await api.post('/drivers/me/location', {
        'latitude': lat,
        'longitude': lng,
      });
    } catch (_) {}
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/offers/$offerId/accept');
      setState(() {
        activeRide = Map<String, dynamic>.from(res['data'] as Map);
        offers = [];
        message = null;
      });
    } catch (e) {
      setState(() => message = e.toString());
    }
  }

  Future<void> _arrived() async {
    if (activeRide == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides/${activeRide!['id']}/arrived');
      setState(() => activeRide = Map<String, dynamic>.from(res['data'] as Map));
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
      setState(() => activeRide = Map<String, dynamic>.from(res['data'] as Map));
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
      });

      // Back ONLINE + GEO so dispatch can match this driver again
      try {
        await api.post('/drivers/me/online', {'online': true});
        await api.post('/drivers/me/location', {
          'latitude': 6.9344,
          'longitude': 79.8428,
        });
        setState(() => online = true);
        locationTimer?.cancel();
        locationTimer =
            Timer.periodic(const Duration(seconds: 8), (_) => _pushLocation());
      } catch (_) {}

      // Show completion briefly, then wait for new offers
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('MaX Driver'),
        actions: [
          IconButton(
            onPressed: () => context.push('/onboarding'),
            icon: const Icon(Icons.badge_outlined),
          ),
          IconButton(
            onPressed: () => context.push('/earnings'),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Online status',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        online ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          color: online ? dAmber : Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Approval: $status',
                        style: const TextStyle(color: Colors.white54),
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
          const SizedBox(height: 16),
          if (!showActive) ...[
            const Text(
              'Incoming offers',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (offers.isEmpty)
              Text(
                online
                    ? 'No pending offers yet — stay online near Colombo'
                    : 'Go online to receive offers',
              ),
            ...offers.map((o) {
              final m = o as Map;
              final ride = m['ride'] as Map?;
              return Card(
                child: ListTile(
                  title: Text(ride?['pickupAddress']?.toString() ?? 'Ride'),
                  subtitle: Text(
                    '→ ${ride?['dropoffAddress']}\n'
                    'LKR ${ride?['estimatedFare']} · ${m['pickupDistanceMeters']} m',
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () => _acceptOffer(m['id'].toString()),
                    child: const Text('Accept'),
                  ),
                ),
              );
            }),
            TextButton(onPressed: _pollOffers, child: const Text('Refresh offers')),
          ] else ...[
            Text(
              rideStatus == 'TRIP_COMPLETED'
                  ? 'Trip completed'
                  : 'Active: $rideStatus',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              '${activeRide!['pickupAddress']}\n→ ${activeRide!['dropoffAddress']}',
            ),
            const SizedBox(height: 12),
            if (rideStatus == 'DRIVER_ASSIGNED')
              ElevatedButton(
                onPressed: _arrived,
                child: const Text('I have arrived'),
              ),
            if (rideStatus == 'DRIVER_ARRIVED') ...[
              TextField(
                controller: pinCtrl,
                decoration:
                    const InputDecoration(hintText: 'Passenger start PIN'),
              ),
              ElevatedButton(onPressed: _start, child: const Text('Start trip')),
            ],
            if (rideStatus == 'TRIP_STARTED')
              ElevatedButton(
                onPressed: _complete,
                child: const Text('Complete trip'),
              ),
            if (rideStatus == 'TRIP_COMPLETED') ...[
              Text(
                'Fare collected · LKR ${activeRide!['finalFare']}\n'
                'Returning to offers in a moment…',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _readyForNextTrip,
                style: ElevatedButton.styleFrom(backgroundColor: dAmber, foregroundColor: dInk),
                child: const Text('Ready for next request'),
              ),
            ],
          ],
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
