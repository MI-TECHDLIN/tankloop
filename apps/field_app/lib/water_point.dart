import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'field_content.dart';
import 'plain_language.dart';
import 'point_record_card.dart';
import 'runtime.dart';
import 'sync_status.dart';

class WaterPointScreen extends ConsumerWidget {
  const WaterPointScreen({super.key, required this.pointId});
  final String pointId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) {
        final point = runtime.dashboard.points
            .where((p) => p.id == pointId)
            .firstOrNull;
        final tasks = runtime.dashboard.inspections
            .where((t) => t.assetId == point?.assetId)
            .toList();
        return TankBackdrop(
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text(
                'Water point',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              leading: IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Symbols.arrow_back_rounded),
                tooltip: 'Back to Today',
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () => runtime.refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  FieldContent(
                    runtime: runtime,
                    empty: () => point == null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (point != null) ...[
                          const SizedBox(height: 4),
                          PointRecordCard(
                            point: point,
                            dashboard: runtime.dashboard,
                          ),
                          const SectionHeading('Assigned checks'),
                          if (!tasks.any((t) => !t.isSubmitted))
                            const NoticeCard(
                              title: 'No open checks',
                              message:
                                  'Past records remain below. This does not imply safe water.',
                              icon: Symbols.event_available_rounded,
                            )
                          else
                            ListGroupCard(
                              children: [
                                for (final task in tasks.where(
                                  (t) => !t.isSubmitted,
                                ))
                                  TankListRow(
                                    leading: AssetBadge(
                                      runtime.dashboard.assetFor(task).type,
                                      size: 44,
                                    ),
                                    title:
                                        'Inspection due ${recordDate(task.dueAt)}',
                                    meta: [
                                      MetaLine(
                                        TankMeta.device,
                                        runtime.outbox.forTask(task.id) == null
                                            ? 'Scheduled'
                                            : entryLabel(
                                                runtime.outbox.forTask(
                                                  task.id,
                                                )!,
                                              ),
                                      ),
                                    ],
                                    onTap: () =>
                                        context.push('/inspection/${task.id}'),
                                  ),
                              ],
                            ),
                          const SectionHeading('Inspection history'),
                          if (!tasks.any((t) => t.isSubmitted))
                            Text(
                              'No inspection history recorded.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: TankColors.muted),
                            )
                          else
                            RecordCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final task in tasks.where(
                                    (t) => t.isSubmitted,
                                  ))
                                    TankListRow(
                                      leading: const AccentTile(
                                        TankAccents.inspection,
                                        size: 40,
                                      ),
                                      title:
                                          'Received ${recordTime(task.submittedAt!)}',
                                      subtitle:
                                          'Checklist v${runtime.dashboard.templateFor(task).version} - observed risks, not a laboratory finding',
                                    ),
                                ],
                              ),
                            ),
                          const SectionHeading('Concern history'),
                          if (!runtime.dashboard.cases.any(
                            (c) => c.pointLabel == point.label,
                          ))
                            Text(
                              'No concerns recorded for this point.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: TankColors.muted),
                            )
                          else
                            ListGroupCard(
                              children: [
                                for (final item
                                    in runtime.dashboard.cases.where(
                                      (c) => c.pointLabel == point.label,
                                    ))
                                  TankListRow(
                                    leading: AccentTile(
                                      sourceAccent(item.source),
                                      size: 40,
                                    ),
                                    title: humanState(wireName(item.state)),
                                    subtitle: caseNextStep(item.state),
                                    meta: [
                                      MetaLine(
                                        TankMeta.calendar,
                                        recordTime(item.reportedAt),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
