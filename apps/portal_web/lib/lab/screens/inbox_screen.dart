import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import '../lab_controller.dart';
import '../lab_navigation.dart';
import '../widgets/lab_record_widgets.dart';
import '../widgets/lab_screen_frame.dart';

class LabInboxScreen extends StatelessWidget {
  const LabInboxScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
  });
  final LabController controller;
  final LabNavigate onNavigate;

  @override
  Widget build(BuildContext context) => LabScreenFrame(
    controller: controller,
    title: 'Inbox',
    description:
        'Every sample has a next step. Keep the evidence moving, with its provenance intact.',
    isEmpty: (data) => !data.activeRecords.any((r) => r.needsAttention),
    emptyTitle: 'No samples waiting',
    emptyMessage:
        'There are no pending lab actions in this facility. Reviewed records and their custody remain in Results.',
    builder: (data) {
      final active = data.activeRecords;
      final pending = active.where((r) => r.needsAttention).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final item in [
                  (
                    'Awaiting intake',
                    active.where((r) => r.needsIntake).length,
                    LabSection.intake,
                    Icons.inventory_2_outlined,
                  ),
                  (
                    'Ready for result',
                    active.where((r) => r.state == ResultState.valid).length,
                    LabSection.results,
                    Icons.biotech_outlined,
                  ),
                  (
                    'Awaiting review',
                    active.where((r) => r.state == ResultState.tested).length,
                    LabSection.results,
                    Icons.fact_check_outlined,
                  ),
                ])
                  SizedBox(
                    width: constraints.maxWidth < 680
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 32) / 3,
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$4, color: TankColors.teal),
                          const SizedBox(height: 16),
                          Text(
                            '${item.$2}',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(item.$1),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => onNavigate(item.$3, null),
                            child: const Text('Open queue'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Counts describe workflow activity, not water quality.',
            style: TextStyle(fontSize: 12, color: TankColors.muted),
          ),
          SectionHeading(
            'Needs attention',
            trailing: StatusPill(
              '${pending.length} samples',
              icon: Icons.pending_actions_outlined,
            ),
          ),
          for (final record in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LabRecordTile(
                record: record,
                timezone: data.facility.timezone,
                onOpen: () => onNavigate(
                  record.needsIntake ? LabSection.intake : LabSection.results,
                  record.id,
                ),
              ),
            ),
        ],
      );
    },
  );
}
