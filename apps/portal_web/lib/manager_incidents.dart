import 'package:flutter/material.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

class ManagerIncidentsScreen extends StatelessWidget {
  const ManagerIncidentsScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Incidents',
    controller: controller,
    isEmpty: (data) => data.incidents.isEmpty,
    emptyMessage: 'No incident records are available in this facility.',
    builder: (_, data) => ManagerIncidentList(
      incidents: data.incidents,
      controller: controller,
      data: data,
    ),
  );
}
