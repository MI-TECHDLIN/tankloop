import 'package:flutter/material.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

class ManagerApprovalsScreen extends StatelessWidget {
  const ManagerApprovalsScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Work-order approvals',
    controller: controller,
    isEmpty: (data) => data.orders.isEmpty,
    emptyMessage: 'No work orders have been proposed in this facility.',
    builder: (_, data) => ManagerWorkOrderList(
      orders: data.orders,
      controller: controller,
      data: data,
    ),
  );
}
