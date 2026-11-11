import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'runtime.dart';

import 'field_content.dart';
import 'plain_language.dart';
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
      builder: (context, _) {
        final tasks = _openTasks(runtime);
        return FieldContent(
          runtime: runtime,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(
                          'Today · ${dayGreeting(runtime.dashboard.asOf)}',
                          icon: TankMeta.calendar,
                        ),
                        const SizedBox(height: 20),
                        TwoToneHeading(
                          tasks.isEmpty ? 'All caught ' : 'Your next ',
                          tasks.isEmpty ? 'up.' : 'check.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    tooltip: 'Scan water point QR',
                    style: IconButton.styleFrom(
                      backgroundColor: TankColors.navy,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => context.push('/scan'),
                    icon: const Icon(Symbols.qr_code_scanner_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _FacilityLine(
                label: runtime.dashboard.facility.label,
                checks: tasks.length,
              ),
            ],
          ),
          empty: () => tasks.isEmpty,
          emptyState: _emptyState(context, runtime),
          child: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _content(context, runtime, tasks),
            ),
          ),
        );
      },
    );
  }

  List<InspectionTask> _openTasks(FieldRuntime runtime) =>
      runtime.dashboard.inspections.where((t) => !t.isSubmitted).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

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

  Widget _emptyState(
    BuildContext context,
    FieldRuntime runtime,
  ) => EmptyStateCard(
    art: const LayeredRecordArt(
      accent: TankAccents.scheduled,
      label: 'NO CHECKS DUE',
      height: 150,
    ),
    title: 'No checks assigned right now',
    message:
        'New inspections from your manager appear here. An empty list is not a water-quality finding.',
    actions: [
      FilledButton.icon(
        onPressed: runtime.refreshing
            ? null
            : () => _perform(context, runtime.refresh),
        icon: const Icon(Symbols.refresh_rounded),
        label: const Text('Refresh assignments'),
      ),
      OutlinedButton.icon(
        onPressed: () => context.push('/scan'),
        icon: const Icon(Symbols.qr_code_scanner_rounded),
        label: const Text('Scan a water point'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How a check works',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        const FlowSteps(steps: inspectionSteps),
      ],
    ),
  );

  List<Widget> _content(
    BuildContext context,
    FieldRuntime runtime,
    List<InspectionTask> tasks,
  ) {
    final data = runtime.dashboard;
    final orders = data.workOrders
        .where((o) => o.assigneeId == data.actorId)
        .toList();
    return [
      if (tasks.isNotEmpty) _priorityTask(context, runtime, tasks.first),
      if (runtime.failedCount > 0) ...[
        const SizedBox(height: 16),
        ExceptionPanel(
          label: 'Needs attention',
          title: '${runtime.failedCount} sync failed',
          message:
              'Saved records are retained on this device. Open Activity to retry or review them.',
          action: TextButton.icon(
            onPressed: onActivity,
            icon: const Icon(Symbols.arrow_forward_rounded, size: 20),
            label: const Text('Open Activity'),
            style: TextButton.styleFrom(foregroundColor: TankColors.amber),
          ),
        ),
      ],
      if (tasks.length > 1) ...[
        const SectionHeading('Up next'),
        ListGroupCard(
          children: [
            for (final task in tasks.skip(1).take(4))
              _queueRow(context, runtime, task),
          ],
        ),
      ],
      if (orders.isNotEmpty) ...[
        const SectionHeading('Repairs assigned to you'),
        ListGroupCard(
          children: [
            for (final order in orders)
              TankListRow(
                leading: const AccentTile(TankAccents.repair),
                title: order.task,
                subtitle: humanState(wireName(order.state)),
                onTap: () => context.push('/work/${order.id}'),
              ),
          ],
        ),
      ],
      const SectionHeading('On this device'),
      ListGroupCard(
        children: [
          TankListRow(
            leading: AccentTile(
              runtime.pendingCount == 0
                  ? TankAccents.synced
                  : TankAccents.upload,
            ),
            title: '${runtime.pendingCount} pending sync',
            subtitle: runtime.pendingCount == 0
                ? 'Drafts are saved locally. A submitted check gets its own receipt.'
                : 'Your queued inspections stay on this device until acknowledged.',
            trailing: TextButton(
              onPressed: runtime.outbox.syncing || !runtime.online
                  ? null
                  : () => _perform(context, runtime.sync),
              child: Text(runtime.outbox.syncing ? 'Syncing…' : 'Sync now'),
            ),
          ),
        ],
      ),
      if (tasks.isNotEmpty) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: runtime.refreshing
                ? null
                : () => _perform(context, runtime.refresh),
            icon: const Icon(Symbols.refresh_rounded, size: 20),
            label: Text(
              runtime.refreshing ? 'Refreshing…' : 'Refresh assignments',
            ),
          ),
        ),
      ],
    ];
  }

  Widget _priorityTask(
    BuildContext context,
    FieldRuntime runtime,
    InspectionTask task,
  ) {
    final saved = runtime.outbox.forTask(task.id);
    final asset = runtime.dashboard.assetFor(task);
    final template = runtime.dashboard.templateFor(task);
    final (due, tone) = dueLabel(task.dueAt, runtime.dashboard.asOf);
    final blocked = saved?.state == DraftState.blocked;
    return TaskCard(
      kind: 'Inspection',
      title: asset.label,
      leading: AssetBadge(asset.type, size: 52),
      status: StateChip(
        saved == null ? due : entryLabel(saved),
        tone: blocked
            ? ChipTone.caution
            : saved == null
            ? tone
            : ChipTone.positive,
        icon: saved == null ? TankMeta.calendar : TankMeta.device,
      ),
      details: [
        MetaLine(TankMeta.listChecks, '${template.questions.length} items'),
        const MetaLine(TankMeta.user, 'Assigned to you'),
      ],
      action: FilledButton.icon(
        onPressed: () => context.push('/inspection/${task.id}'),
        icon: const Icon(Symbols.arrow_forward_rounded),
        label: Text(
          saved == null
              ? 'Start inspection'
              : saved.state == DraftState.draft
              ? 'Continue inspection'
              : 'View inspection',
        ),
      ),
      child: FlowSteps(steps: inspectionSteps, current: inspectionStep(saved)),
    );
  }

  Widget _queueRow(
    BuildContext context,
    FieldRuntime runtime,
    InspectionTask task,
  ) {
    final saved = runtime.outbox.forTask(task.id);
    final asset = runtime.dashboard.assetFor(task);
    final (due, _) = dueLabel(task.dueAt, runtime.dashboard.asOf);
    return TankListRow(
      leading: AssetBadge(asset.type, size: 44),
      title: asset.label,
      meta: [
        MetaLine(TankMeta.calendar, due),
        if (saved != null) MetaLine(TankMeta.device, entryLabel(saved)),
      ],
      onTap: () => context.push('/inspection/${task.id}'),
    );
  }
}

class _FacilityLine extends StatelessWidget {
  const _FacilityLine({required this.label, required this.checks});
  final String label;
  final int checks;

  @override
  Widget build(BuildContext context) => LeadingRow(
    gap: 12,
    leading: const AccentTile(TankAccents.facility, size: 44),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Text(
          'Assigned facility · $checks ${checks == 1 ? 'check' : 'checks'} open',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
