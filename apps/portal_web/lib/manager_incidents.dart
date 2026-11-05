import 'package:flutter/material.dart';
import 'package:tankloop_domain/domain.dart';
import 'manager_widgets.dart';

class ManagerIncidentsScreen extends StatelessWidget {
  const ManagerIncidentsScreen({
    super.key,
    required this.incidents,
    required this.onAdvance,
  });
  final List<IncidentRecord> incidents;
  final Future<void> Function(IncidentRecord, IncidentState) onAdvance;
  @override
  Widget build(BuildContext context) =>
      ManagerIncidentList(incidents: incidents, onAdvance: onAdvance);
}
