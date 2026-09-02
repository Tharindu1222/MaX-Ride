import 'package:flutter/material.dart';
import '../core/theme.dart';

class DriverCircleButton extends StatelessWidget {
  const DriverCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.emphasized = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: emphasized ? maxForest : maxSurface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: emphasized ? maxForest : maxSurface,
              shape: BoxShape.circle,
              boxShadow: maxShadowFloat,
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 20,
                color: emphasized ? maxLime : maxInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DriverGlassCard extends StatelessWidget {
  const DriverGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: maxSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: maxShadowSoft,
        border: Border.all(color: Colors.white),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class DriverSheetHandle extends StatelessWidget {
  const DriverSheetHandle({super.key});

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

class DriverStatusPill extends StatelessWidget {
  const DriverStatusPill({
    super.key,
    required this.label,
    this.positive = false,
  });

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? const Color(0x1A0F3D2E) : maxSand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: positive ? maxForest : maxMuted,
        ),
      ),
    );
  }
}
