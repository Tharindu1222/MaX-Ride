import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/drivers/me/earnings');
    setState(() => data = Map<String, dynamic>.from(res['data'] as Map));
  }

  @override
  Widget build(BuildContext context) {
    final wallet = data?['wallet'] as Map?;
    final txns = (data?['transactions'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Available: LKR ${wallet?['availableBalance'] ?? 0}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('Cash balance: LKR ${wallet?['cashBalance'] ?? 0}'),
          Text('Trips: ${data?['totalCompletedTrips'] ?? 0}'),
          const SizedBox(height: 16),
          ...txns.map((t) {
            final m = t as Map;
            return ListTile(
              title: Text(m['transactionType']?.toString() ?? ''),
              subtitle: Text(m['description']?.toString() ?? ''),
              trailing: Text('${m['direction']} ${m['amount']}'),
            );
          }),
        ],
      ),
    );
  }
}
