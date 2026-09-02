import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/drivers/me/earnings');
    if (!mounted) return;
    setState(() {
      data = Map<String, dynamic>.from(res['data'] as Map);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wallet = data?['wallet'] as Map?;
    final txns = (data?['transactions'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: maxForest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: maxShadowSoft,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LKR ${wallet?['availableBalance'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _stat(
                            'Cash on hand',
                            'LKR ${wallet?['cashBalance'] ?? 0}',
                          ),
                          _stat(
                            'Trips',
                            '${data?['totalCompletedTrips'] ?? 0}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Recent activity',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 10),
                if (txns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No payouts yet. Completed trips will show here.',
                      style: TextStyle(color: maxMuted, height: 1.4),
                    ),
                  )
                else
                  ...txns.map((t) {
                    final m = t as Map;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: maxSurface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: maxShadowFloat,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['transactionType']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  m['description']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: maxMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${m['direction']} ${m['amount']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: maxForest,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: maxLime,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
