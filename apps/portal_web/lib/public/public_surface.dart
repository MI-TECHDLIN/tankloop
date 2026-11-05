import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';

/// Text-first mode omits blur, shadows, artwork and animated decoration.
class PublicSurface extends StatelessWidget {
  const PublicSurface({
    super.key,
    required this.child,
    required this.textFirst,
    this.caution = false,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final bool textFirst;
  final bool caution;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => textFirst
      ? Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFB3C9C7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        )
      : GlassCard(
          padding: padding,
          color: caution ? TankColors.caution.withValues(alpha: .9) : null,
          child: child,
        );
}
