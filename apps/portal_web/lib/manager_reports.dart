import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';

class ManagerReportsScreen extends StatelessWidget {
  const ManagerReportsScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Reports',
    controller: controller,
    isEmpty: (data) =>
        data.inspections.isEmpty &&
        data.samples.isEmpty &&
        data.incidents.isEmpty,
    emptyMessage:
        'There are no inspection, sampling or incident records to summarize.',
    builder: (context, data) {
      final coverage = data.inspections.isEmpty
          ? 0
          : ((data.inspections.where((i) => i.task.isSubmitted).length /
                        data.inspections.length) *
                    100)
                .round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            child: Text(
              '$coverage% of scheduled inspections have a recorded submission. ${data.incidents.where((i) => i.isOpen).length} incident(s) remain open. These indicators describe process completeness, not a population-wide water-quality claim.',
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Text(
              '${data.results.where((r) => r.isReviewed).length} current-revision reviewed result(s) across ${data.samples.length} registered sample(s). Collection dates and review scope remain available in Samples & Results.',
            ),
          ),
        ],
      );
    },
  );
}
