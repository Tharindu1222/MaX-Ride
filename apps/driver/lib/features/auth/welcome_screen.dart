import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _start(BuildContext context) => context.go('/login');

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(
      color: dWhite,
      height: 1.02,
      letterSpacing: -1.1,
    );

    return Scaffold(
      backgroundColor: dBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/driver_hero_car_tight.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, 0.42),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE60A0A0A),
                  Color(0x660A0A0A),
                  Color(0x220A0A0A),
                  Color(0xF20A0A0A),
                ],
                stops: [0.0, 0.22, 0.48, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: dBlack,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: dWhite.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: dGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MaX Ride  ·  Driver',
                          style: GoogleFonts.inter(
                            color: dWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Drive with',
                    style: titleStyle.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'MaX Ride',
                    style: titleStyle.copyWith(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: dGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Go online, accept nearby rides, and get paid in LKR.',
                    style: GoogleFonts.inter(
                      color: dWhite.withValues(alpha: 0.82),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _VehicleTags(),
                  const Spacer(),
                  const _StatsStrip(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: dBlack,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: dWhite.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Get started',
                                style: GoogleFonts.inter(
                                  color: dWhite,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Continue with your mobile number',
                                style: GoogleFonts.inter(
                                  color: dWhite.withValues(alpha: 0.7),
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Get started',
                          child: Material(
                            color: dGreen,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _start(context),
                              child: const SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Icons.arrow_forward, color: dBlack),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleTags extends StatelessWidget {
  const _VehicleTags();

  static const tags = [];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tags.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: i == 1 ? dGreen : dBlack,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: i == 1 ? dGreen : dWhite.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                tags[i],
                style: GoogleFonts.inter(
                  color: i == 1 ? dBlack : dWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.inter(
      color: dWhite.withValues(alpha: 0.62),
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    final valueStyle = GoogleFonts.inter(
      color: dWhite,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: dBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dWhite.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _Stat(
            value: '4.9',
            label: 'Rating',
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
          _divider(),
          _Stat(
            value: 'Fast',
            label: 'Payouts',
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
          _divider(),
          _Stat(
            value: '24/7',
            label: 'Support',
            valueStyle: valueStyle,
            labelStyle: labelStyle,
          ),
        ],
      ),
    );
  }

  static Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: dWhite.withValues(alpha: 0.18),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.valueStyle,
    required this.labelStyle,
  });

  final String value;
  final String label;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: valueStyle),
          const SizedBox(height: 2),
          Text(label, style: labelStyle),
        ],
      ),
    );
  }
}
