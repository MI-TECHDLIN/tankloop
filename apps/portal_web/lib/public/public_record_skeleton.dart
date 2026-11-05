import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'public_surface.dart';

class PublicRecordSkeleton extends StatelessWidget {
  const PublicRecordSkeleton({super.key, this.textFirst = false});
  final bool textFirst;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label:
        'Loading the point record. Retrieving dated evidence and open concerns.',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Loading the point record'),
          const SizedBox(height: 20),
          if (!textFirst) ...[
            const FractionallySizedBox(
              widthFactor: .65,
              alignment: Alignment.centerLeft,
              child: FrostedSkeleton(height: 36),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < 3; i++) ...[
              PublicSurface(
                textFirst: false,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FractionallySizedBox(
                      widthFactor: .4,
                      alignment: Alignment.centerLeft,
                      child: FrostedSkeleton(height: 20),
                    ),
                    SizedBox(height: 20),
                    FrostedSkeleton(),
                    SizedBox(height: 12),
                    FractionallySizedBox(
                      widthFactor: .75,
                      alignment: Alignment.centerLeft,
                      child: FrostedSkeleton(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    ),
  );
}
