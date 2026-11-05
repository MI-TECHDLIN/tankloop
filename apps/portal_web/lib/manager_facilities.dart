import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'manager_catalog.dart';

class ManagerFacilitiesScreen extends StatelessWidget {
  const ManagerFacilitiesScreen({super.key, required this.snapshot});
  final DashboardSnapshot snapshot;
  @override
  Widget build(BuildContext context) => ManagerCatalogScreen(
    title: 'Facilities',
    snapshot: snapshot,
    kind: 'facilities',
  );
}
