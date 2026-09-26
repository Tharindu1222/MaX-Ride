import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

/// Matches the Premier Cabs welcome mock closely.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _accent = Color(0xFFE11D26);

  void _getStarted(BuildContext context) => context.go('/login');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: pcBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — slight overscale so sides stay filled
          Transform.scale(
            scale: 1.22,
            alignment: const Alignment(0.1, -0.45),
            child: Image.asset(
              'assets/images/welcome_bg.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: const Alignment(0.12, -0.5),
              filterQuality: FilterQuality.high,
            ),
          ),
          // Soft top darken for logo contrast
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  pcBlack.withValues(alpha: 0.55),
                  pcBlack.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Bottom scrim for copy + CTA
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  pcBlack.withValues(alpha: 0.0),
                  pcBlack.withValues(alpha: 0.35),
                  pcBlack.withValues(alpha: 0.92),
                  pcBlack,
                ],
                stops: const [0.32, 0.48, 0.68, 1.0],
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: MediaQuery.paddingOf(context).top + 6,
            left: 18,
            right: 18,
            child: const _TopBar(),
          ),

          // Mid overlay: RIDE WITH CLASS
          Positioned(
            left: 18,
            top: size.height * 0.38,
            child: const _RideWithClass(),
          ),

          // Bottom content block
          Positioned(
            left: 18,
            right: 18,
            bottom: bottomPad + 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(flex: 6, child: _HeadlineBlock()),
                    const SizedBox(width: 8),
                    const _FeatureColumn(),
                  ],
                ),
                const SizedBox(height: 20),
                _GetStartedButton(onTap: () => _getStarted(context)),
                const SizedBox(height: 14),
                const _BottomMeta(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/pcablogo.png',
          height: 48,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          filterQuality: FilterQuality.high,
        ),
        const Spacer(),
        const _LuxuryAnytimeAnywhere(),
      ],
    );
  }
}

class _LuxuryAnytimeAnywhere extends StatelessWidget {
  const _LuxuryAnytimeAnywhere();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: pcWhite.withValues(alpha: 0.95),
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 2.6,
      height: 1.45,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('LUXURY', style: style),
        Text('ANYTIME', style: style),
        Text('ANYWHERE', style: style),
        const SizedBox(height: 7),
        Container(
          width: 34,
          height: 2,
          color: WelcomeScreen._accent,
        ),
      ],
    );
  }
}

class _RideWithClass extends StatelessWidget {
  const _RideWithClass();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIDE WITH CLASS',
          style: TextStyle(
            color: pcWhite.withValues(alpha: 0.42),
            fontSize: 12,
            fontWeight: FontWeight.w300,
            letterSpacing: 3.6,
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 40, height: 2, color: WelcomeScreen._accent),
      ],
    );
  }
}

class _HeadlineBlock extends StatelessWidget {
  const _HeadlineBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Small mock label
        Row(
          children: [
            Container(
              width: 18,
              height: 2,
              color: WelcomeScreen._accent,
            ),
            const SizedBox(width: 8),
            Text(
              'PREMIUM RIDES',
              style: TextStyle(
                color: pcWhite.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              color: pcWhite,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.12,
              letterSpacing: -0.7,
            ),
            children: const [
              TextSpan(text: 'Find the nearest car\nand start your '),
              TextSpan(
                text: 'best ride!',
                style: TextStyle(color: WelcomeScreen._accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Luxury cars, professional drivers and\ninstant rides anywhere in the world.',
          style: TextStyle(
            color: pcWhite.withValues(alpha: 0.52),
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _FeatureColumn extends StatelessWidget {
  const _FeatureColumn();

  static const _items = [
    (Icons.workspace_premium_outlined, 'Luxury'),
    (Icons.verified_user_outlined, 'Trusted'),
    (Icons.bolt_rounded, 'Fast'),
    (Icons.place_outlined, 'Anywhere'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, color: WelcomeScreen._accent, size: 15),
                const SizedBox(width: 8),
                Text(
                  item.$2,
                  style: TextStyle(
                    color: pcWhite.withValues(alpha: 0.92),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFE11D26),
                Color(0xFF861619),
                Color(0xFF4A0C0F),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE11D26).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 0, 7, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Get started',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pcWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: 0.15,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF0B0B0D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: pcWhite,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomMeta extends StatelessWidget {
  const _BottomMeta();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: List.generate(3, (i) {
            final active = i == 0;
            return Container(
              width: active ? 20 : 12,
              height: 3,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: active
                    ? WelcomeScreen._accent
                    : pcWhite.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
        const Spacer(),
        Icon(
          Icons.keyboard_arrow_up_rounded,
          color: WelcomeScreen._accent,
          size: 15,
        ),
        const SizedBox(width: 3),
        Text(
          'YOUR JOURNEY BEGINS HERE',
          style: TextStyle(
            color: pcWhite.withValues(alpha: 0.42),
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.05,
          ),
        ),
      ],
    );
  }
}
