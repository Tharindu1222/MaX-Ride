import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List categories = [];
  List places = [];
  Map<String, dynamic>? pickup;
  Map<String, dynamic>? dropoff;
  String? selectedCategoryId;
  String paymentMethod = 'CASH';
  String promo = '';
  Map<String, dynamic>? estimate;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final cats = await api.get('/vehicle-categories');
      final placesRes = await api.get('/maps/places/popular');
      setState(() {
        categories = (cats['data'] as List?) ?? [];
        places = ((placesRes['data'] as Map?)?['results'] as List?) ?? [];
        if (categories.isNotEmpty) {
          selectedCategoryId = categories.first['id'] as String?;
        }
        if (places.length >= 2) {
          pickup = Map<String, dynamic>.from(places[0] as Map);
          dropoff = Map<String, dynamic>.from(places[1] as Map);
        }
      });
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  Future<void> _estimate() async {
    if (pickup == null || dropoff == null || selectedCategoryId == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/fares/estimate', {
        'vehicleCategoryId': selectedCategoryId,
        'pickupLat': pickup!['lat'],
        'pickupLng': pickup!['lng'],
        'dropoffLat': dropoff!['lat'],
        'dropoffLng': dropoff!['lng'],
        if (promo.isNotEmpty) 'promoCode': promo,
      });
      setState(() => estimate = Map<String, dynamic>.from(res['data'] as Map));
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _requestRide() async {
    if (pickup == null || dropoff == null || selectedCategoryId == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post('/rides', {
        'vehicleCategoryId': selectedCategoryId,
        'pickupAddress': pickup!['address'] ?? pickup!['name'],
        'pickupLat': pickup!['lat'],
        'pickupLng': pickup!['lng'],
        'dropoffAddress': dropoff!['address'] ?? dropoff!['name'],
        'dropoffLat': dropoff!['lat'],
        'dropoffLng': dropoff!['lng'],
        'paymentMethod': paymentMethod,
        if (promo.isNotEmpty) 'promoCode': promo,
      });
      final ride = res['data'] as Map<String, dynamic>;
      if (!mounted) return;
      final pin = ride['startPin'];
      if (pin != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Your start PIN'),
            content: Text('Share this PIN with the driver: $pin'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
      if (!mounted) return;
      context.go('/ride/${ride['id']}');
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaX Ride', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [maxForest, maxTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: const Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Where to next?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _placeTile('Pickup', pickup, (p) => setState(() => pickup = p)),
          const SizedBox(height: 10),
          _placeTile('Drop-off', dropoff, (p) => setState(() => dropoff = p)),
          const SizedBox(height: 16),
          Text('Vehicle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = categories[i] as Map;
                final selected = c['id'] == selectedCategoryId;
                return GestureDetector(
                  onTap: () => setState(() => selectedCategoryId = c['id'] as String),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? maxForest : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['name']?.toString() ?? '',
                          style: TextStyle(
                            color: selected ? Colors.white : maxInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${c['capacity']} seats',
                          style: TextStyle(
                            color: selected ? maxLime : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Cash (LKR)'),
                selected: paymentMethod == 'CASH',
                onSelected: (_) => setState(() => paymentMethod = 'CASH'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Card'),
                selected: paymentMethod == 'CARD',
                onSelected: (_) => setState(() => paymentMethod = 'CARD'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(hintText: 'Promo code (e.g. MAX10)'),
            onChanged: (v) => promo = v,
          ),
          if (estimate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Estimate: LKR ${estimate!['estimatedFare']}\n'
                '${estimate!['estimatedDistanceMeters']} m · '
                '${((estimate!['estimatedDurationSeconds'] as num) / 60).round()} min',
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : _estimate,
                  child: const Text('Estimate fare'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: loading ? null : _requestRide,
                  child: Text(loading ? '…' : 'Request ride'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeTile(
    String label,
    Map<String, dynamic>? selected,
    void Function(Map<String, dynamic>) onSelect,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            selected?['name']?.toString() ?? 'Select place',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: places.take(6).map((p) {
              final m = Map<String, dynamic>.from(p as Map);
              return ActionChip(
                label: Text(m['name']?.toString() ?? ''),
                onPressed: () => onSelect(m),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
