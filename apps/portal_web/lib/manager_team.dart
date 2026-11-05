import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'manager_catalog.dart';

class ManagerTeamScreen extends StatelessWidget {
  const ManagerTeamScreen({super.key, required this.snapshot});
  final DashboardSnapshot snapshot;
  @override
  Widget build(BuildContext context) =>
      ManagerCatalogScreen(title: 'Team', snapshot: snapshot, kind: 'team');
}
