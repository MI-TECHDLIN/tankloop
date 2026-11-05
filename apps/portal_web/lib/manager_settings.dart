import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

class ManagerSettingsScreen extends StatelessWidget {
  const ManagerSettingsScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Settings',
    controller: controller,
    isEmpty: (data) => data.members.isEmpty,
    emptyMessage: 'No scoped membership configuration is available.',
    builder: (context, data) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NoticeCard(
          title: 'Scoped access',
          message:
              'Manager actions are limited to the selected facility and require an authoritative receipt in production.',
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ManagerDetail(
                'Data source',
                controller.repository.serverBacked
                    ? 'Connected Supabase service'
                    : 'Seeded simulation engine',
              ),
              ManagerDetail('Current actor', data.actorId),
              ManagerDetail('Facility scope', data.facility.id),
              ManagerDetail(
                'Screen freshness window',
                '5 minutes since the last fetch. This is not a sample validity interval.',
              ),
              if (data.facility.isSimulated) ...[
                ManagerDetail(
                  'Simulation seed',
                  '${data.simulationSeed ?? 'Not provided'}',
                ),
                ManagerDetail(
                  'Model version',
                  '${data.modelVersion ?? 'Not provided'}',
                ),
              ],
              if (!controller.repository.serverBacked)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Offline exercise'),
                  subtitle: const Text(
                    'Retain the fetched records and pause authoritative actions. Reconnect to refresh.',
                  ),
                  value: controller.offlineExercise,
                  onChanged: controller.busy
                      ? null
                      : controller.setOfflineExercise,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
