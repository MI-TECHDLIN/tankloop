import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'runtime.dart';

import 'field_content.dart';
import 'sync_status.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({this.onActivity = _noop, super.key});
  final VoidCallback onActivity;
  static void _noop() {}
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([
        runtime,
        runtime.outbox,
        runtime.workOutbox,
      ]),
      builder: (context, _) => FieldContent(
        runtime: runtime,
        empty: () => !runtime.dashboard.inspections.any((t) => !t.isSubmitted),
        child: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _content(context, runtime),
          ),
        ),
      ),
    );
  }

  Future<void> _perform(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not finish. Saved records are retained; please retry.',
            ),
          ),
        );
      }
    }
  }

  List<Widget> _content(BuildContext context, FieldRuntime runtime) {
    final data = runtime.dashboard;
    final tasks = data.inspections.where((t) => !t.isSubmitted).toList();
    final due = tasks
        .where(
          (t) => !t.dueAt.isAfter(data.asOf.add(const Duration(hours: 24))),
        )
        .length;
    final cases = data.cases
        .where((c) => c.state != IncidentState.resolved)
        .length;
    return [
      Text(
        dayGreeting(data.asOf),
        style: const TextStyle(
          color: TankColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Every check leaves a record.',
        style: Theme.of(context).textTheme.displayMedium,
      ),
      const SizedBox(height: 8),
      Text(
        'Inspections, lab reviews, and fixes — each dated and accountable.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: TankColors.muted,
        ),
      ),
      const SizedBox(height: 24),
      HeroSurface(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR WATER NETWORK',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.facility.label,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.assets.length} connected assets · ${data.points.length} sampling points',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: tasks.isEmpty
                      ? () => onActivity()
                      : () => context.push('/inspection/${tasks.first.id}'),
                  icon: const Icon(Icons.add_task_rounded, size: 20),
                  label: Text(
                    tasks.isEmpty ? 'View activity' : 'Start inspection',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: TankColors.tealDeep,
                  ),
                ),
              ],
            );
            final artworkSize = constraints.maxWidth > 620 ? 280.0 : 320.0;
            return constraints.maxWidth > 620
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: content),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: WaterNetworkArtwork(size: artworkSize),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: artworkSize, child: WaterNetworkArtwork(size: artworkSize)),
                      const SizedBox(height: 16),
                      content,
                    ],
                  );
          },
        ),
      ),
      const SizedBox(height: 16),
      // Consolidated metrics row
      Row(
        children: [
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              radius: TankSpace.radiusStandard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TankColors.mint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_note_outlined,
                          color: TankColors.teal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tasks.length.toString(),
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: TankColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Checks scheduled',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: TankColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (due > 0) ...[
                    const SizedBox(height: 8),
                    StatusPill(
                      '$due due in 24h',
                      icon: Icons.schedule_rounded,
                      caution: true,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              radius: TankSpace.radiusStandard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TankColors.caution,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fact_check_outlined,
                          color: TankColors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cases.toString(),
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: TankColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Open concerns',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: TankColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (cases > 0) ...[
                    const SizedBox(height: 8),
                    StatusPill(
                      'Awaiting resolution',
                      icon: Icons.hourglass_empty_rounded,
                      caution: true,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SectionHeading(
        'Your next checks',
        trailing: StatusPill(
          '${tasks.length} scheduled',
          compact: true,
          icon: Icons.event_note_outlined,
        ),
      ),
      if (tasks.isEmpty)
        const NoticeCard(
          title: 'All assigned checks are recorded',
          message:
              'New scheduled checks will appear here. Completed inspections stay in Activity.',
          icon: Icons.task_alt_rounded,
        ),
      for (final task in tasks.take(4)) _inspectionTile(context, runtime, task),
      if (runtime.failedCount > 0)
        NoticeCard(
          title: '${runtime.failedCount} sync failed',
          message:
              'Saved records are retained. Open Activity to retry or review.',
          caution: true,
        ),
      const SectionHeading('Assigned work orders'),
      for (final order in runtime.dashboard.workOrders.where(
        (o) => o.assigneeId == runtime.dashboard.actorId,
      ))
        DenseCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(order.task, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(humanState(wireName(order.state)), style: const TextStyle(color: TankColors.muted)),
            trailing: const Icon(Icons.chevron_right, color: TankColors.muted),
            onTap: () => context.push('/work/${order.id}'),
          ),
        ),
      const SizedBox(height: 12),
      NoticeCard(
        title: '${runtime.pendingCount} pending sync',
        message: runtime.pendingCount == 0
            ? 'Drafts are saved locally. A submitted check gets its own receipt.'
            : 'Your queued inspections stay on this device until acknowledged.',
        icon: Icons.cloud_upload_outlined,
        action: TextButton.icon(
          onPressed: runtime.outbox.syncing || !runtime.online
              ? null
              : () => _perform(context, runtime.sync),
          icon: const Icon(Icons.sync_rounded),
          label: Text(runtime.outbox.syncing ? 'Syncing…' : 'Sync now'),
        ),
      ),
    ];
  }

  Widget _inspectionTile(
    BuildContext context,
    FieldRuntime runtime,
    InspectionTask task,
  ) {
    final saved = runtime.outbox.forTask(task.id);
    final asset = runtime.dashboard.assetFor(task);
    final overdue = task.dueAt.isBefore(runtime.dashboard.asOf);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TankColors.mint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.water_outlined,
                    color: TankColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Due ${recordDate(task.dueAt)}',
                        style: const TextStyle(
                          color: TankColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  saved == null
                      ? (overdue ? 'Overdue' : 'Scheduled')
                      : entryLabel(saved),
                  caution:
                      overdue && saved == null ||
                      saved?.state == DraftState.blocked,
                  compact: true,
                  icon: saved == null
                      ? Icons.schedule_rounded
                      : Icons.save_outlined,
                ),
                const StatusPill(
                  'Available offline',
                  compact: true,
                  icon: Icons.offline_pin_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/inspection/${task.id}'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                saved == null
                    ? 'Begin check'
                    : saved.state == DraftState.draft
                    ? 'Continue draft'
                    : 'View inspection',
              ),
            ),
          ],
        ),
      ),
    );
  }
}