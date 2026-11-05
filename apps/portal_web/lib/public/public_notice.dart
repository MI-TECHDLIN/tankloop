import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'public_surface.dart';

class PublicNotice extends StatelessWidget {
  const PublicNotice({
    super.key,
    required this.title,
    required this.message,
    this.textFirst = false,
    this.caution = false,
    this.icon = Icons.info_outline_rounded,
    this.action,
  });
  final String title;
  final String message;
  final bool textFirst;
  final bool caution;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => PublicSurface(
    textFirst: textFirst,
    caution: caution,
    padding: const EdgeInsets.all(20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            color: caution ? TankColors.amber : TankColors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Text(message),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ],
    ),
  );
}
