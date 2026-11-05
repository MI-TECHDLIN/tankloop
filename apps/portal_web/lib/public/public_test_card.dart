import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'public_surface.dart';

class PublicTestCard extends StatelessWidget {
  const PublicTestCard({
    super.key,
    required this.test,
    required this.timezone,
    required this.historical,
    required this.textFirst,
  });
  final PublicTest test;
  final String timezone;
  final bool historical;
  final bool textFirst;

  @override
  Widget build(BuildContext context) => PublicSurface(
    textFirst: textFirst,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              test.isSimulated
                  ? 'Simulated lab review'
                  : 'Independently reviewed',
              icon: Icons.science_outlined,
            ),
            StatusPill(
              historical ? 'Historical record' : 'Published sample',
              icon: Icons.description_outlined,
              caution: historical,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          test.indicator.label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          test.exactFinding,
          style: const TextStyle(fontSize: 17, height: 1.5),
        ),
        const Divider(height: 32),
        const Text(
          'METHOD & SCOPE',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(test.method, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Reported value: ${test.valueText} ${test.units.label}'),
        Text('Detection limit: ${test.detectionLimit} ${test.units.label}'),
        const SizedBox(height: 12),
        const Text(
          'Other hazards and other sampling points were not assessed by this sample.',
          style: TextStyle(color: TankColors.muted),
        ),
        const Divider(height: 32),
        for (final item in [
          ('Collected', test.collectedAt),
          ('Tested', test.testedAt),
          ('Reviewed', test.reviewedAt),
          ('Published', test.publishedAt),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    item.$1,
                    style: const TextStyle(color: TankColors.muted),
                  ),
                ),
                Text(recordTime(item.$2, timezone: timezone)),
              ],
            ),
          ),
      ],
    ),
  );
}
