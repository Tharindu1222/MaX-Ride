import 'package:flutter/material.dart';
import '../core/theme.dart';

class MaxCircleIconButton extends StatelessWidget {
  const MaxCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: maxSurface,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(
              color: maxSurface,
              shape: BoxShape.circle,
              boxShadow: maxShadowFloat,
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 20, color: maxInk),
            ),
          ),
        ),
      ),
    );
  }
}

class MaxGlassCard extends StatelessWidget {
  const MaxGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: maxSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: maxShadowSoft,
        border: Border.all(color: Colors.white),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class MaxSheetHandle extends StatelessWidget {
  const MaxSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0x330B1F1A),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
