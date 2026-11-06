import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'runtime.dart';

import 'field_content.dart';
import 'sync_status.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});
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
        empty: () =>
            runtime.outbox.entries.isEmpty &&
            !runtime.dashboard.inspections.any((t) => t.isSubmitted),
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

  List<Widget> _content(BuildContext context, FieldRuntime runtime) => [
    Text(
      'Nothing lost\nbetween connections.',
      style: Theme.of(context).textTheme.displayMedium,
    ),
    const SizedBox(height: 16),
    // Status summary cards
    Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  runtime.pendingCount.toString(),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: TankColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Queued inspections',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TankColors.muted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  runtime.outbox.blockedCount.toString(),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: TankColors.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Need review',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: TankColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: !runtime.online || runtime.outbox.syncing
          ? null
          : () => _perform(context, runtime.sync),
      icon: const Icon(Icons.sync_rounded),
      label: Text(
        runtime.outbox.syncing ? 'Syncing…' : 'Sync queued inspections',
      ),
    ),
    const SectionHeading('This device'),
    if (runtime.outbox.entries.isEmpty)
      const NoticeCard(
        title: 'No device activity yet',
        message: 'Save an inspection to see its draft, queue and receipt here.',
        icon: Icons.history_rounded,
      ),
    for (final entry in runtime.outbox.entries.reversed)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusPill(
                entryLabel(entry),
                icon: entry.state == DraftState.synced
                    ? Icons.receipt_long_outlined
                    : Icons.save_outlined,
                caution: entry.state == DraftState.blocked,
              ),
              const SizedBox(height: 12),
              Text('Observed ${recordTime(entry.command.observedAt)}'),
              if (entry.receipt != null)
                Text(
                  '${runtime.config.mode == AppMode.simulation ? 'Simulated receipt' : 'Server received'} ${recordTime(entry.receipt!.receivedAt)}',
                  style: const TextStyle(color: TankColors.muted),
                ),
              if (entry.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    entry.error!,
                    style: const TextStyle(color: TankColors.amber),
                  ),
                ),
              TextButton(
                onPressed: () =>
                    context.push('/inspection/${entry.command.taskId}'),
                child: const Text('View saved inspection'),
              ),
            ],
          ),
        ),
      ),
    const SectionHeading('Work-order steps'),
    for (final entry in runtime.workOutbox.entries.reversed)
      DenseCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            entry.error == null ? draftLabel(entry.state) : 'Sync failed',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(entry.error ?? entry.command.notes),
          onTap: () => context.push('/work/${entry.command.orderId}'),
        ),
      ),
    const SectionHeading('Recorded checks'),
    for (final task
        in runtime.dashboard.inspections
            .where((t) => t.isSubmitted)
            .toList()
            .reversed
            .take(8))
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NoticeCard(
          paperSurface: true,
          title: runtime.dashboard.assetFor(task).label,
          message:
              'Received ${recordTime(task.submittedAt!)} · Checklist v${runtime.dashboard.templateFor(task).version}',
          icon: Icons.fact_check_outlined,
        ),
      ),
  ];
}
