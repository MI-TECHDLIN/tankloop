import 'package:flutter/material.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_widgets.dart';

class ManagerApprovalsScreen extends StatelessWidget {
  const ManagerApprovalsScreen({
    super.key,
    required this.orders,
    required this.onAdvance,
  });
  final List<WorkOrder> orders;
  final Future<void> Function(WorkOrder, WorkOrderState) onAdvance;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading('Work-order approvals'),
      ManagerWorkOrderList(orders: orders, onAdvance: onAdvance),
    ],
  );
}
