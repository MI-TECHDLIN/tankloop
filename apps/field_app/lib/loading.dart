import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';

class FieldLoadingSkeleton extends StatelessWidget {
  const FieldLoadingSkeleton({
    super.key,
    this.message = 'Loading assigned checks',
  });
  final String message;

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Row(
              children: [
                Expanded(child: FrostedSkeleton(height: 40, width: 150)),
                SizedBox(width: 12),
                FrostedSkeleton(height: 40, width: 40, radius: 14),
              ],
            ),
            const SizedBox(height: 32),
            Text(message, style: const TextStyle(color: TankColors.muted)),
            const SizedBox(height: 12),
            const FrostedSkeleton(height: 38, width: 280),
            const SizedBox(height: 20),
            const FrostedSkeletonCard(lines: 3),
            const SizedBox(height: 16),
            const FrostedSkeletonCard(lines: 2),
          ],
        ),
      ),
    ),
  );
}
