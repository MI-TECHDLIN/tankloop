import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'runtime.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'field_content.dart';

class WaterPointsScreen extends ConsumerWidget {
  const WaterPointsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) => FieldContent(
        runtime: runtime,
        empty: () => runtime.dashboard.points.isEmpty,
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _content(context, runtime),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, FieldRuntime runtime) => [
    Text('Follow the water.', style: Theme.of(context).textTheme.displayMedium),
    const SizedBox(height: 8),
    Text(
      runtime.dashboard.facility.label,
      style: const TextStyle(color: TankColors.muted),
    ),
    const SizedBox(height: 24),
    HeroSurface(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Text(
            'Water flows through this network',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const WaterNetworkArtwork(size: 280),
        ],
      ),
    ),
    const SectionHeading('Connected assets'),
    GlassCard(
      child: Column(
        children: [
          for (final asset in runtime.dashboard.assets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TankColors.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      asset.type == AssetType.tap
                          ? Icons.water_drop_outlined
                          : asset.type == AssetType.tank
                          ? Icons.water_outlined
                          : Icons.account_tree_outlined,
                      color: TankColors.teal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          asset.capacityLitres == null
                              ? humanState(asset.type.name)
                              : '${asset.capacityLitres} L storage capacity',
                          style: const TextStyle(
                            color: TankColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (asset.parentId != null)
                    const Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      color: TankColors.muted,
                      size: 18,
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
    const SectionHeading('Public water points'),
    for (final point in runtime.dashboard.points)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      point.label,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (point.isSimulated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TankColors.navy.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TankColors.navy.withValues(alpha: .15),
                        ),
                      ),
                      child: Text(
                        'SIMULATED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: TankColors.teal,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'A dated record and open concerns, accessible without signing in.',
                style: TextStyle(color: TankColors.muted),
              ),
              TextButton(
                onPressed: () => context.push('/point/${point.id}'),
                child: const Text('Tasks and history'),
              ),
              const SizedBox(height: 12),
              if (runtime.dashboard.publicTokens[point.id]
                  case final String token)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(point.label),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (point.isSimulated)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'SIMULATED POINT',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: TankColors.teal,
                                      ),
                                    ),
                                  ),
                                QrImageView(
                                  data: runtime.publicUrl(token),
                                  size: 240,
                                  backgroundColor: Colors.white,
                                  semanticsLabel:
                                      'Public water point QR for ${point.label}',
                                ),
                                const SizedBox(height: 12),
                                SelectableText(
                                  token,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Match this label to the physical point before scanning.',
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Show QR label'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: runtime.publicUrl(token)),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Public point link copied'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.qr_code_2_rounded),
                      label: const Text('Copy public QR link'),
                    ),
                  ],
                )
              else
                const Text('No active public label has been issued.'),
            ],
          ),
        ),
      ),
  ];
}
