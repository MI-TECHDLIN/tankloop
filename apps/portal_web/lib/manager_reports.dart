import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_design_system/design_system.dart';

class ManagerReportsScreen extends StatelessWidget {
  const ManagerReportsScreen({
    super.key,
    required this.snapshot,
    required this.incidents,
  });
  final DashboardSnapshot snapshot;
  final List<IncidentRecord> incidents;
  @override
  Widget build(BuildContext context) {
    final coverage = snapshot.inspections.isEmpty
        ? 0
        : ((snapshot.inspections.where((i) => i.isSubmitted).length /
                      snapshot.inspections.length) *
                  100)
              .round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('Reports'),
        GlassCard(
          child: Text(
            '$coverage% of scheduled inspections have a recorded submission. ${incidents.where((i) => i.isOpen).length} incident(s) remain open. These simulated indicators describe process completeness, not a population-wide water-quality claim.',
          ),
        ),
        const SizedBox(height: 12),
        const StatusPill(
          'Stale data warning: compare as-of time before acting',
          icon: Icons.schedule,
          caution: true,
        ),
      ],
    );
  }
}
