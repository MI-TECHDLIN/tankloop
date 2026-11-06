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
        'Small checks.\nA clearer picture.',
        style: Theme.of(context).textTheme.displaySmall,
      ),
      const SizedBox(height: 12),
      const Text(
        'Every observation helps someone take the next step.',
        style: TextStyle(color: TankColors.muted),
      ),
      const SizedBox(height: 24),
      GlassCard(
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
                    color: TankColors.teal,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.facility.label,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.assets.length} connected assets · ${data.points.length} sampling points',
                  style: const TextStyle(color: TankColors.muted),
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
                ),
              ],
            );
            return constraints.maxWidth > 620
                ? Row(
                    children: [
                      Expanded(flex: 3, child: content),
                      const SizedBox(width: 24),
                      const Expanded(flex: 2, child: WaterNetworkArtwork()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 152, child: WaterNetworkArtwork()),
                      const SizedBox(height: 8),
                      content,
                    ],
                  );
          },
        ),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _metric(
              '$due',
              'Checks due',
              'Due soon or overdue',
              Icons.fact_check_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _metric(
              '$cases',
              'Open concerns',
              'Workload, not a safety score',
              Icons.flag_outlined,
            ),
          ),
        ],
      ),
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
        Card(
          child: ListTile(
            title: Text(order.task),
            subtitle: Text(humanState(wireName(order.state))),
            trailing: const Icon(Icons.chevron_right),
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

  Widget _metric(String value, String title, String subtitle, IconData icon) =>
      GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: TankColors.teal, size: 22),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: TankColors.muted),
            ),
          ],
        ),
      );

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
