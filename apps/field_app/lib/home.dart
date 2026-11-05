import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'runtime.dart';

class FieldHome extends ConsumerStatefulWidget {
  const FieldHome({super.key});
  @override
  ConsumerState<FieldHome> createState() => _FieldHomeState();
}

class _FieldHomeState extends ConsumerState<FieldHome> {
  int selected = 0;
  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The action could not finish. Your saved records are retained.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) {
        final dashboard = runtime.dashboard;
        return TankBackdrop(
          child: Scaffold(
            extendBody: true,
            body: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 144),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(child: TankBrand()),
                            IconButton.filledTonal(
                              tooltip: 'Refresh assignments',
                              onPressed: runtime.refreshing
                                  ? null
                                  : () => _perform(runtime.refresh),
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              tooltip: 'Profile and exercise controls',
                              onPressed: () => setState(() => selected = 4),
                              icon: const Icon(Icons.person_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (dashboard.facility.isSimulated) ...[
                          const SimulationNotice(compact: true),
                          const SizedBox(height: 20),
                        ],
                        if (!runtime.online || runtime.stale) ...[
                          NoticeCard(
                            title: !runtime.online
                                ? 'Saved here. Ready when you are.'
                                : 'Previously loaded assignments',
                            message: !runtime.online
                                ? 'Sync is paused. Your inspection drafts stay on this device.'
                                : 'Last loaded ${recordTime(dashboard.asOf)}. Connect and refresh for current assignments.',
                            icon: Icons.cloud_off_rounded,
                            caution: true,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (runtime.error != null) ...[
                          NoticeCard(
                            title: runtime.accessRevoked
                                ? 'Access needs renewal'
                                : 'Refresh unavailable',
                            message: runtime.error!,
                            caution: true,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (runtime.accessRevoked)
                          NoticeCard(
                            title: 'Facility access is restricted',
                            message:
                                'Contact your manager or sign in again. Your draft is retained for the same account.',
                            action: TextButton(
                              onPressed: () =>
                                  Supabase.instance.client.auth.signOut(),
                              child: const Text('Sign out'),
                            ),
                          )
                        else
                          ...switch (selected) {
                            0 => _today(context, runtime),
                            1 => _network(context, runtime),
                            2 => _cases(context, runtime),
                            3 => _activity(context, runtime),
                            _ => _profile(context, runtime),
                          },
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: FloatingNav(
              selected: selected,
              onSelected: (value) => setState(() => selected = value),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _today(BuildContext context, FieldRuntime runtime) {
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
                      ? () => setState(() => selected = 3)
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
      const SizedBox(height: 12),
      NoticeCard(
        title: '${runtime.outbox.pendingCount} pending sync',
        message: runtime.outbox.pendingCount == 0
            ? 'Drafts are saved locally. A submitted check gets its own receipt.'
            : 'Your queued inspections stay on this device until acknowledged.',
        icon: Icons.cloud_upload_outlined,
        action: TextButton.icon(
          onPressed: runtime.outbox.syncing || !runtime.online
              ? null
              : () => _perform(runtime.sync),
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
                      : draftLabel(saved.state),
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

  List<Widget> _network(BuildContext context, FieldRuntime runtime) => [
    Text('Follow the water.', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 12),
    Text(
      runtime.dashboard.facility.label,
      style: const TextStyle(color: TankColors.muted),
    ),
    const SizedBox(height: 24),
    const GlassCard(child: SizedBox(height: 200, child: WaterNetworkArtwork())),
    const SectionHeading('Connected assets'),
    GlassCard(
      child: Column(
        children: [
          for (final asset in runtime.dashboard.assets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    asset.type == AssetType.tap
                        ? Icons.water_drop_outlined
                        : asset.type == AssetType.tank
                        ? Icons.water_outlined
                        : Icons.account_tree_outlined,
                    color: TankColors.teal,
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
              Text(point.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'A dated record and open concerns, accessible without signing in.',
                style: TextStyle(color: TankColors.muted),
              ),
              const SizedBox(height: 12),
              if (runtime.dashboard.publicTokens[point.id]
                  case final String token)
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
                )
              else
                const Text('No active public label has been issued.'),
            ],
          ),
        ),
      ),
  ];

  List<Widget> _cases(BuildContext context, FieldRuntime runtime) => [
    Text(
      'Every concern.\nAn accountable next step.',
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 16),
    const NoticeCard(
      title: 'Repair is not resolution',
      message:
          'Cases remain open until the applicable follow-up evidence is reviewed and communication is recorded.',
      icon: Icons.fact_check_outlined,
    ),
    const SectionHeading('Case records'),
    if (runtime.dashboard.cases.isEmpty)
      const NoticeCard(
        title: 'No concerns recorded',
        message:
            'This describes the record, not the quality or safety of the water.',
      ),
    for (final item in runtime.dashboard.cases.reversed)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              item.pointLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${humanState(wireName(item.state))}\n${humanState(wireName(item.source))} · ${recordDate(item.reportedAt)}',
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  item.hasOwner
                      ? 'Accountable owner assigned'
                      : 'Awaiting assignment',
                  icon: Icons.person_outline_rounded,
                  caution: !item.hasOwner,
                ),
              ),
              const SizedBox(height: 12),
              if (item.dueAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Response due ${recordTime(item.dueAt!)}'),
                ),
              for (final event in item.events)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: TankColors.teal),
                      const SizedBox(width: 12),
                      Expanded(child: Text(event)),
                    ],
                  ),
                ),
              if (item.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Privileged transitions and audit are available through the server RPCs.',
                  ),
                ),
            ],
          ),
        ),
      ),
  ];

  List<Widget> _activity(BuildContext context, FieldRuntime runtime) => [
    Text(
      'Nothing lost\nbetween connections.',
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 16),
    Text(
      '${runtime.outbox.pendingCount} queued · ${runtime.outbox.blockedCount} need review',
      style: const TextStyle(color: TankColors.muted),
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: !runtime.online || runtime.outbox.syncing
          ? null
          : () => _perform(runtime.sync),
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
                draftLabel(entry.state),
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
          title: runtime.dashboard.assetFor(task).label,
          message:
              'Received ${recordTime(task.submittedAt!)} · Checklist v${runtime.dashboard.templateFor(task).version}',
          icon: Icons.fact_check_outlined,
        ),
      ),
  ];

  List<Widget> _profile(BuildContext context, FieldRuntime runtime) => [
    Text('Your field space.', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 24),
    GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            runtime.dashboard.facility.label,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('Field inspector · English'),
          const SizedBox(height: 16),
          Text(
            runtime.config.mode == AppMode.simulation
                ? 'Deterministic simulation · Seed ${runtime.config.seed}'
                : 'Supabase · ${Uri.parse(runtime.config.supabaseUrl).host}',
            style: const TextStyle(color: TankColors.muted),
          ),
          Text(
            'Record clock: ${recordTime(runtime.dashboard.asOf)}',
            style: const TextStyle(color: TankColors.muted),
          ),
        ],
      ),
    ),
    const SectionHeading('Offline exercise'),
    GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pause sync, save a check, reload the app, then resume sync. Drafts and queued commands are durable.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: runtime.toggleConnection,
            icon: Icon(
              runtime.online
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_upload_outlined,
            ),
            label: Text(runtime.online ? 'Pause sync' : 'Resume sync'),
          ),
          if (runtime.config.mode == AppMode.simulation) ...[
            const SizedBox(height: 16),
            const Text(
              'Advance the simulated clock to see new inspections, laboratory timelines and guarded case transitions.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: runtime.refreshing
                  ? null
                  : () => _perform(runtime.advanceDay),
              icon: const Icon(Icons.fast_forward_outlined),
              label: const Text('Advance 1 day'),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 20),
    const NoticeCard(
      title: 'Evidence, with its limits',
      message:
          'Inspections record observed risks. They do not detect contamination. Simulated records are never real laboratory or pilot evidence.',
    ),
    if (runtime.config.mode == AppMode.supabase) ...[
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Clear this device and sign out?'),
              content: const Text(
                'Local drafts and queued inspections for this account will be removed. Acknowledged server records are retained.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep working'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Clear and sign out'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await _perform(() async {
              await runtime.clearDeviceData();
              await Supabase.instance.client.auth.signOut();
            });
          }
        },
        child: const Text('Sign out and clear device'),
      ),
    ],
  ];
}

String draftLabel(DraftState state) => switch (state) {
  DraftState.draft => 'Draft saved on device',
  DraftState.pending => 'Pending sync',
  DraftState.synced => 'Receipt received',
  DraftState.blocked => 'Needs review',
};
