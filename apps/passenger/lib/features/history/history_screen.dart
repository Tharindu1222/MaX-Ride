import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List rides = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/passengers/me/rides');
    setState(() => rides = (res['data'] as List?) ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride history')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rides.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = rides[i] as Map;
          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(r['rideNumber']?.toString() ?? ''),
            subtitle: Text('${r['status']}\n${r['pickupAddress']} → ${r['dropoffAddress']}'),
            isThreeLine: true,
            trailing: Text('LKR ${r['finalFare'] ?? r['estimatedFare'] ?? '-'}'),
          );
        },
      ),
    );
  }
}
