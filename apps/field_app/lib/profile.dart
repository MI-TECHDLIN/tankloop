import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_design_system/design_system.dart';
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
        header: const PageHeader(
          eyebrow: 'Profile',
          eyebrowIcon: TankMeta.user,
          lead: 'Your field ',
          emphasis: 'space.',
        ),
        empty: () => runtime.dashboard.actorId.isEmpty,
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
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [TankColors.navy, Color(0xFF16405F)],
          ),
          boxShadow: [
            BoxShadow(
              color: TankColors.navy.withValues(alpha: .18),
              offset: const Offset(0, 12),
              blurRadius: 28,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccentTile(
              TankAccents.badge,
              size: 52,
              background: Color(0x2EFFFFFF),
              foreground: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              runtime.dashboard.facility.label,
              style: textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Field inspector · English',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            MetaLine(
              TankMeta.clock,
              'Last updated: ${recordTime(runtime.dashboard.asOf)}',
              color: Colors.white70,
            ),
            const SizedBox(height: 6),
            MetaLine(
              TankMeta.cloud,
              'Supabase · ${Uri.parse(runtime.config.supabaseUrl).host}',
              color: Colors.white70,
            ),
          ],
        ),
      ),
      const SectionHeading('Sync preferences'),
      ListGroupCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LeadingRow(
                  leading: AccentTile(
                    runtime.online ? TankAccents.synced : TankAccents.offline,
                  ),
                  child: Text(
                    'Pause uploads when needed. Drafts and queued work stay on this device until you resume sync.',
                    style: textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: runtime.toggleConnection,
                  icon: Icon(
                    runtime.online
                        ? Symbols.cloud_off_rounded
                        : Symbols.cloud_upload_rounded,
                  ),
                  label: Text(runtime.online ? 'Pause sync' : 'Resume sync'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SectionHeading('What a record can tell you'),
      RecordCard(
        child: LeadingRow(
          leading: const AccentTile(TankAccents.limits),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Evidence, with its limits', style: textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Inspections record observed risks. They do not detect contamination.',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'TankLoop Field',
          ),
          icon: const Icon(Symbols.license_rounded, size: 20),
          label: const Text('Open-source notices'),
        ),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
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
        icon: const Icon(Symbols.logout_rounded),
        label: const Text('Sign out and clear device'),
      ),
    ];
  }
}
