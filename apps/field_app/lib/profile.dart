import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart'
    hide SimulationNotice;
import 'package:tankloop_localization/localization.dart';
import 'runtime.dart';

import 'field_content.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([runtime, runtime.outbox]),
      builder: (context, _) => FieldContent(
        runtime: runtime,
        empty: () => runtime.dashboard.actorId.isEmpty,
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
    Text('Your field space.', style: Theme.of(context).textTheme.displayMedium),
    const SizedBox(height: 24),
    HeroSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            runtime.dashboard.facility.label,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text('Field inspector · English', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Text(
            runtime.config.mode == AppMode.simulation
                ? 'Deterministic simulation · Seed ${runtime.config.seed}'
                : 'Supabase · ${Uri.parse(runtime.config.supabaseUrl).host}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Record clock: ${recordTime(runtime.dashboard.asOf)}',
            style: const TextStyle(color: Colors.white70),
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
                  : () => _perform(context, runtime.advanceDay),
              icon: const Icon(Icons.fast_forward_outlined),
              label: const Text('Advance 1 day'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: TankColors.tealDeep,
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 20),
    NoticeCard(
      prominent: true,
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
          if (confirmed == true && context.mounted) {
            await _perform(context, () async {
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