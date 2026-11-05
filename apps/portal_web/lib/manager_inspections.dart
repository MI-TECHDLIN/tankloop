import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'manager_catalog.dart';

class ManagerInspectionsScreen extends StatelessWidget {
  const ManagerInspectionsScreen({super.key, required this.snapshot});
  final DashboardSnapshot snapshot;
  @override
  Widget build(BuildContext context) => ManagerCatalogScreen(
    title: 'Inspections',
    snapshot: snapshot,
    kind: 'inspections',
  );
}
