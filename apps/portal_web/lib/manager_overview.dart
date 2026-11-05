import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

class ManagerOverviewScreen extends StatelessWidget {
  const ManagerOverviewScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Operational overview',
    controller: controller,
    isEmpty: (data) =>
        data.assets.isEmpty &&
        data.inspections.isEmpty &&
        data.incidents.isEmpty &&
        data.samples.isEmpty,
    emptyMessage: 'No operational records are available in this facility.',
    builder: (context, data) => _body(context, data),
  );

  Widget _body(BuildContext context, ManagerWorkspace data) {
    final overdue = data.inspections.where((i) => i.overdue(data.asOf)).length;
    final reviewedPoints = data.results
        .where((r) => r.isReviewed)
        .map((r) => r.sample.pointId)
        .toSet();
    final coverage = data.points.isEmpty
        ? 0
        : ((reviewedPoints.length / data.points.length) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ManagerMetric(
              label: 'Open incidents',
              value: '${data.incidents.where((i) => i.isOpen).length}',
              icon: Icons.warning_amber_outlined,
            ),
            ManagerMetric(
              label: 'Overdue inspections',
              value: '$overdue',
              icon: Icons.schedule,
              caution: overdue > 0,
            ),
            ManagerMetric(
              label: 'Reviewed-point coverage',
              value: '$coverage%',
              icon: Icons.water_drop_outlined,
            ),
          ],
        ),
        SectionHeading('Evidence completeness'),
        const GlassCard(
          child: Text(
            'Counts describe workload and recorded evidence coverage. Confirm collection dates, scope, method and independent review before communicating a conclusion.',
          ),
        ),
        ManagerIncidentList(
          incidents: data.incidents,
          controller: controller,
          data: data,
        ),
      ],
    );
  }
}
