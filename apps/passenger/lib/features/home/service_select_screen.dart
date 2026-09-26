import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class ServiceSelectScreen extends StatelessWidget {
  const ServiceSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        id: 'RIDE',
        title: 'Ride',
        subtitle: 'City trips · pickup to dropoff',
        icon: Icons.local_taxi_rounded,
        color: maxLime,
      ),
      (
        id: 'INTERCITY',
        title: 'Intercity',
        subtitle: 'Longer trips · intercity fares',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFF2F6FED),
      ),
      (
        id: 'RENTAL',
        title: 'Rental',
        subtitle: 'Hourly, daily & fixed packages',
        icon: Icons.event_available_rounded,
        color: const Color(0xFFB45309),
      ),
    ];

    return Scaffold(
      backgroundColor: maxSand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MaX Ride',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: maxForest,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'What do you need today?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: maxMuted,
                    ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, i) {
                    final o = options[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => context.go('/?mode=${o.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: o.color.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(o.icon, color: maxForest, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      o.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: maxInk,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      o.subtitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: maxMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
