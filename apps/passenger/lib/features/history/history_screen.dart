import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List rides = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/passengers/me/rides');
    if (!mounted) return;
    setState(() {
      rides = (res['data'] as List?) ?? [];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your trips')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : rides.isEmpty
              ? const _EmptyTrips()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: rides.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = rides[i] as Map;
                    final status = r['status']?.toString() ?? '';
                    final fare = r['finalFare'] ?? r['estimatedFare'] ?? '-';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: maxSurface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: maxShadowFloat,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r['rideNumber']?.toString() ?? 'Trip',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              _StatusPill(status: status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            r['pickupAddress']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Icon(Icons.arrow_downward_rounded, size: 14, color: maxMuted),
                          ),
                          Text(
                            r['dropoffAddress']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: maxMuted),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'LKR $fare',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: maxForest,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final done = status == 'TRIP_COMPLETED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done ? const Color(0x1A0F3D2E) : maxSand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' ').toLowerCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: done ? maxForest : maxMuted,
        ),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🗺️', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text(
              'No trips yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            SizedBox(height: 6),
            Text(
              'Your completed rides will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: maxMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
