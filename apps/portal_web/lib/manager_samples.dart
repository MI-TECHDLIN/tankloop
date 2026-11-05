import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'manager_catalog.dart';

class ManagerSamplesScreen extends StatelessWidget {
  const ManagerSamplesScreen({super.key, required this.snapshot});
  final DashboardSnapshot snapshot;
  @override
  Widget build(BuildContext context) => ManagerCatalogScreen(
    title: 'Samples & Results',
    snapshot: snapshot,
    kind: 'samples',
  );
}
