import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'field_content.dart';
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
              title: const Text('Water point'),
              leading: IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Today',
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () => runtime.refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  FieldContent(
                    runtime: runtime,
                    empty: () => point == null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (point != null) ...[
                          const SizedBox(height: 20),
                          Text(
                            point.label,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SectionHeading('Assigned checks'),
                          if (!tasks.any((t) => !t.isSubmitted))
                            const NoticeCard(
                              title: 'No open checks',
                              message:
                                  'Past records remain below. This does not imply safe water.',
                            ),
                          for (final task in tasks.where((t) => !t.isSubmitted))
                            Card(
                              child: ListTile(
                                title: Text(
                                  'Inspection due ${recordDate(task.dueAt)}',
                                ),
                                subtitle: Text(
                                  runtime.outbox.forTask(task.id) == null
                                      ? 'Scheduled'
                                      : entryLabel(
                                          runtime.outbox.forTask(task.id)!,
                                        ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.push('/inspection/${task.id}'),
                              ),
                            ),
                          const SectionHeading('Inspection history'),
                          for (final task in tasks.where((t) => t.isSubmitted))
                            ListTile(
                              title: Text(
                                'Received ${recordTime(task.submittedAt!)}',
                              ),
                              subtitle: Text(
                                'Checklist v${runtime.dashboard.templateFor(task).version} - observed risks, not a laboratory finding',
                              ),
                            ),
                          if (!tasks.any((t) => t.isSubmitted))
                            const Text('No inspection history recorded.'),
                          const SectionHeading('Concern history'),
                          for (final item in runtime.dashboard.cases.where(
                            (c) => c.pointLabel == point.label,
                          ))
                            ListTile(
                              title: Text(humanState(item.state.name)),
                              subtitle: Text(recordTime(item.reportedAt)),
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
