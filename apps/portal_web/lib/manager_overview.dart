import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_widgets.dart';

class ManagerOverviewScreen extends StatelessWidget {
  const ManagerOverviewScreen({
    super.key,
    required this.snapshot,
    required this.incidents,
    required this.onAdvance,
  });
  final DashboardSnapshot snapshot;
  final List<IncidentRecord> incidents;
  final Future<void> Function(IncidentRecord, IncidentState) onAdvance;
  @override
  Widget build(BuildContext context) {
    final overdue = snapshot.inspections
        .where((i) => i.dueAt.isBefore(snapshot.asOf) && !i.isSubmitted)
        .length;
    final coverage = snapshot.inspections.isEmpty
        ? 0
        : ((snapshot.inspections.where((i) => i.isSubmitted).length /
                      snapshot.inspections.length) *
                  100)
              .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('Operational overview'),
        Row(
          children: [
            ManagerMetric(
              label: 'Open incidents',
              value: '${incidents.where((i) => i.isOpen).length}',
              icon: Icons.warning_amber_outlined,
            ),
            ManagerMetric(
              label: 'Overdue inspections',
              value: '$overdue',
              icon: Icons.schedule,
              caution: overdue > 0,
            ),
            ManagerMetric(
              label: 'Sampling coverage',
              value: '$coverage%',
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
        SectionHeading('Evidence completeness'),
        const GlassCard(
          child: Text(
            'Coverage is a workload signal, not proof of safe water. Confirm scope, freshness, method, and independent review before communicating a conclusion.',
          ),
        ),
        ManagerIncidentList(incidents: incidents, onAdvance: onAdvance),
      ],
    );
  }
}
