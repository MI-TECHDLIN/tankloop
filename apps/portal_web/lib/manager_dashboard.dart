import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'manager_shell.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key, required this.repository});
  final SimulationRepository repository;
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  late Future<DashboardSnapshot> snapshot = widget.repository.today();
  int selected = 0;
  String? actionMessage;

  void refresh() => setState(() {
    snapshot = widget.repository.today();
    actionMessage = null;
  });

  Future<void> advanceIncident(
    IncidentRecord incident,
    IncidentState target,
  ) async {
    try {
      await widget.repository.transitionIncident(
        id: incident.id,
        target: target,
        expectedVersion: incident.version,
        reason: 'Manager workspace action',
      );
      setState(() {
        actionMessage =
            'Incident updated through the guarded domain transition.';
        snapshot = widget.repository.today();
      });
    } on Object catch (error) {
      setState(() => actionMessage = error.toString());
    }
  }

  Future<void> advanceWorkOrder(WorkOrder order, WorkOrderState target) async {
    try {
      await widget.repository.transitionWorkOrder(
        id: order.id,
        target: target,
        expectedVersion: order.version,
        reason: 'Manager workspace action',
      );
      setState(() {
        actionMessage = 'Work order updated through the guarded approval flow.';
        snapshot = widget.repository.today();
      });
    } on Object catch (error) {
      setState(() => actionMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: FutureBuilder<DashboardSnapshot>(
        future: snapshot,
        builder: (context, state) {
          if (state.connectionState == ConnectionState.waiting) {
            return ManagerLoadingSkeleton(selected: selected);
          }
          if (state.hasError) {
            return Center(
              child: NoticeCard(
                title: 'Manager view unavailable',
                message: '${state.error}',
                action: TextButton(
                  onPressed: refresh,
                  child: const Text('Retry'),
                ),
              ),
            );
          }
          return ManagerShell(
            snapshot: state.data!,
            engine: widget.repository.engine,
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
            actionMessage: actionMessage,
            onRefresh: refresh,
            onIncident: advanceIncident,
            onWorkOrder: advanceWorkOrder,
          );
        },
      ),
    ),
  );
}

class ManagerLoadingSkeleton extends StatelessWidget {
  const ManagerLoadingSkeleton({super.key, required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Row(
      children: [
        NavigationRail(
          selectedIndex: null,
          labelType: NavigationRailLabelType.selected,
          leading: const Padding(
            padding: EdgeInsets.all(16),
            child: TankBrand(surface: 'MANAGER'),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: Text('Overview'),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const FrostedSkeleton(height: 32, width: 280),
                const SizedBox(height: 16),
                const FrostedSkeleton(height: 42, width: double.infinity),
                const SizedBox(height: 20),
                ...List.generate(
                  selected == 0 ? 4 : 5,
                  (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: FrostedSkeletonCard(lines: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
