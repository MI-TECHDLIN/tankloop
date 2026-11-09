import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'runtime.dart';

import 'field_content.dart';
import 'plain_language.dart';
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
        header: const PageHeader(
          eyebrow: 'Activity',
          eyebrowIcon: TankMeta.device,
          lead: 'Sync & ',
          emphasis: 'history.',
        ),
        empty: () =>
            runtime.outbox.entries.isEmpty &&
            !runtime.dashboard.inspections.any((t) => t.isSubmitted),
        emptyState: const EmptyStateCard(
          art: LayeredRecordArt(
            accent: TankAccents.receipt,
            label: 'NO ACTIVITY YET',
            height: 150,
          ),
          title: 'No device activity yet',
          message:
              'Save an inspection to see its draft, queue and receipt here. Nothing leaves this phone until you send it.',
          child: FlowSteps(steps: inspectionSteps),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _content(context, runtime),
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
    final textTheme = Theme.of(context).textTheme;
    final recorded = runtime.dashboard.inspections
        .where((t) => t.isSubmitted)
        .toList()
        .reversed
        .take(8)
        .toList();
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TankColors.navy,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: TankColors.navy.withValues(alpha: .18),
              offset: const Offset(0, 12),
              blurRadius: 28,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLargeText(context)) ...[
              _Stat(value: runtime.pendingCount, label: 'Queued inspections'),
              const SizedBox(height: 12),
              _Stat(value: runtime.outbox.blockedCount, label: 'Need review'),
            ] else
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: runtime.pendingCount,
                      label: 'Queued inspections',
                    ),
                  ),
                  Container(width: 1, height: 44, color: Colors.white24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Stat(
                      value: runtime.outbox.blockedCount,
                      label: 'Need review',
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: !runtime.online || runtime.outbox.syncing
                  ? null
                  : () => _perform(context, runtime.sync),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: TankColors.navy,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
              ),
              icon: const Icon(Symbols.sync_rounded),
              label: Text(
                runtime.outbox.syncing ? 'Syncing…' : 'Sync queued inspections',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              runtime.online
                  ? 'Queued work stays on this phone until the server sends a receipt.'
                  : 'Sync is paused. Queued work stays on this phone.',
              style: textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      // With no history at all, the empty state above already says this.
      if (runtime.outbox.entries.isEmpty && recorded.isNotEmpty) ...[
        const SectionHeading('This device'),
        const NoticeCard(
          title: 'No device activity yet',
          message:
              'Save an inspection to see its draft, queue and receipt here.',
          icon: Symbols.history_rounded,
        ),
      ] else if (runtime.outbox.entries.isNotEmpty) ...[
        const SectionHeading('This device'),
        ListGroupCard(
          children: [
            for (final entry in runtime.outbox.entries.reversed)
              TankListRow(
                leading: AccentTile(
                  switch (entry.state) {
                    DraftState.synced => TankAccents.receipt,
                    DraftState.blocked => TankAccents.concern,
                    DraftState.pending => TankAccents.upload,
                    DraftState.draft => TankAccents.inspection,
                  },
                  background: entry.state == DraftState.blocked
                      ? TankColors.caution
                      : TankColors.mint,
                  foreground: entry.state == DraftState.blocked
                      ? TankColors.amber
                      : TankColors.tealDeep,
                ),
                title: entryLabel(entry),
                meta: [
                  MetaLine(
                    TankMeta.clock,
                    'Observed ${recordTime(entry.command.observedAt)}',
                  ),
                  if (entry.receipt != null)
                    MetaLine(
                      TankMeta.fileCheck,
                      'Server received ${recordTime(entry.receipt!.receivedAt)}',
                    ),
                  if (entry.command.evidence.isNotEmpty)
                    MetaLine(
                      TankMeta.paperclip,
                      '${entry.command.evidence.length} photos',
                    ),
                  if (entry.error != null)
                    MetaLine(
                      TankMeta.source,
                      entry.error!,
                      color: TankColors.amber,
                    ),
                ],
                trailing: Tooltip(
                  message: 'View saved inspection',
                  child: IconButton(
                    onPressed: () =>
                        context.push('/inspection/${entry.command.taskId}'),
                    icon: const Icon(Symbols.chevron_right_rounded),
                  ),
                ),
                onTap: () =>
                    context.push('/inspection/${entry.command.taskId}'),
              ),
          ],
        ),
      ],
      if (runtime.workOutbox.entries.isNotEmpty) ...[
        const SectionHeading('Work-order steps'),
        ListGroupCard(
          children: [
            for (final entry in runtime.workOutbox.entries.reversed)
              TankListRow(
                leading: const AccentTile(TankAccents.repair),
                title: entry.error == null
                    ? draftLabel(entry.state)
                    : 'Sync failed',
                subtitle: entry.error ?? entry.command.notes,
                onTap: () => context.push('/work/${entry.command.orderId}'),
              ),
          ],
        ),
      ],
      if (recorded.isNotEmpty) ...[
        const SectionHeading('Recorded checks'),
        RecordCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, task) in recorded.indexed) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                TankListRow(
                  leading: AssetBadge(
                    runtime.dashboard.assetFor(task).type,
                    size: 40,
                  ),
                  title: runtime.dashboard.assetFor(task).label,
                  meta: [
                    MetaLine(
                      TankMeta.fileCheck,
                      'Received ${recordTime(task.submittedAt!)}',
                    ),
                    MetaLine(
                      TankMeta.hash,
                      'Checklist v${runtime.dashboard.templateFor(task).version}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: Theme.of(
          context,
        ).textTheme.displaySmall?.copyWith(color: Colors.white),
      ),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: Colors.white70),
      ),
    ],
  );
}
