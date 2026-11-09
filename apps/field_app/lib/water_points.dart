import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'runtime.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'field_content.dart';
import 'point_record_card.dart';

class WaterPointsScreen extends ConsumerWidget {
  const WaterPointsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) => FieldContent(
        runtime: runtime,
        header: PageHeader(
          eyebrow: 'Water · ${runtime.dashboard.facility.label}',
          eyebrowIcon: TankMeta.mapPin,
          lead: 'Your water ',
          emphasis: 'network.',
        ),
        empty: () => runtime.dashboard.points.isEmpty,
        emptyState: EmptyStateCard(
          art: const LayeredRecordArt(
            type: AssetType.tap,
            label: 'NO POINTS YET',
            height: 150,
          ),
          title: 'No water points assigned yet',
          message:
              'Assets and public points appear here once your facility shares them. An empty list says nothing about water quality.',
          actions: [
            OutlinedButton.icon(
              onPressed: runtime.refresh,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Refresh assignments'),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _content(context, runtime),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, FieldRuntime runtime) {
    final assets = runtime.dashboard.assets;
    final byId = {for (final asset in assets) asset.id: asset};
    return [
      if (assets.isNotEmpty) ...[
        _NetworkCard(assets: assets),
        const SectionHeading('Connected assets'),
        ListGroupCard(
          children: [
            for (final asset in assets)
              TankListRow(
                leading: AssetBadge(asset.type, size: 44),
                title: asset.label,
                subtitle: asset.capacityLitres == null
                    ? assetTypeName(asset.type)
                    : '${assetTypeName(asset.type)} · ${asset.capacityLitres} L capacity',
                meta: [
                  if (byId[asset.parentId] case final Asset parent)
                    MetaLine(TankMeta.connected, 'Fed by ${parent.label}'),
                ],
              ),
          ],
        ),
      ],
      if (runtime.dashboard.points.isNotEmpty)
        const SectionHeading('Public water points'),
      for (final point in runtime.dashboard.points)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PointRecordCard(
            point: point,
            dashboard: runtime.dashboard,
            onOpen: () => context.push('/point/${point.id}'),
            actions: [
              if (runtime.dashboard.publicTokens[point.id]
                  case final String token) ...[
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(point.label),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                  icon: const Icon(Symbols.qr_code_2_rounded),
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
                  icon: const Icon(Symbols.link_rounded),
                  label: const Text('Copy public QR link'),
                ),
              ] else
                const MetaLine(
                  TankMeta.link,
                  'No active public label has been issued.',
                ),
            ],
          ),
        ),
    ];
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.assets});
  final List<Asset> assets;

  @override
  Widget build(BuildContext context) {
    final counts = <AssetType, int>{};
    for (final asset in assets) {
      counts[asset.type] = (counts[asset.type] ?? 0) + 1;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDF1EC), Color(0xFFE6EDF8), Color(0xFFFBF1E4)],
        ),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Eyebrow('From source to tap'),
          const SizedBox(height: 4),
          Text(
            'How water reaches people here',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          NetworkFlowDiagram(counts: counts),
          const SizedBox(height: 16),
          Text(
            'Drawn from ${assets.length} assigned asset records. It shows how assets connect, not water levels or quality.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
