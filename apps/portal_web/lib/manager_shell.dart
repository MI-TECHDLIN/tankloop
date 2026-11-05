import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'manager_approvals.dart';
import 'manager_facilities.dart';
import 'manager_incidents.dart';
import 'manager_inspections.dart';
import 'manager_overview.dart';
import 'manager_reports.dart';
import 'manager_samples.dart';
import 'manager_settings.dart';
import 'manager_team.dart';

class ManagerShell extends StatelessWidget {
  const ManagerShell({
    super.key,
    required this.snapshot,
    required this.engine,
    required this.selected,
    required this.onSelected,
    required this.actionMessage,
    required this.onRefresh,
    required this.onIncident,
    required this.onWorkOrder,
  });
  final DashboardSnapshot snapshot;
  final SimulationEngine engine;
  final int selected;
  final ValueChanged<int> onSelected;
  final String? actionMessage;
  final VoidCallback onRefresh;
  final Future<void> Function(IncidentRecord, IncidentState) onIncident;
  final Future<void> Function(WorkOrder, WorkOrderState) onWorkOrder;

  @override
  Widget build(BuildContext context) {
    final incidents =
        engine.incidents.values
            .where((item) => item.scope.matches(snapshot.scope))
            .toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    final workOrders = engine.workOrders.values
        .where((item) => item.scope.matches(snapshot.scope))
        .toList();
    final body = switch (selected) {
      0 => ManagerOverviewScreen(
        snapshot: snapshot,
        incidents: incidents,
        onAdvance: onIncident,
      ),
      1 => ManagerFacilitiesScreen(snapshot: snapshot),
      2 => ManagerIncidentsScreen(incidents: incidents, onAdvance: onIncident),
      3 => ManagerInspectionsScreen(snapshot: snapshot),
      4 => ManagerSamplesScreen(snapshot: snapshot),
      5 => ManagerApprovalsScreen(orders: workOrders, onAdvance: onWorkOrder),
      6 => ManagerReportsScreen(snapshot: snapshot, incidents: incidents),
      7 => ManagerTeamScreen(snapshot: snapshot),
      _ => const ManagerSettingsScreen(),
    };
    return SafeArea(
      child: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: onSelected,
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
              NavigationRailDestination(
                icon: Icon(Icons.business_outlined),
                label: Text('Facilities'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.warning_amber_outlined),
                label: Text('Incidents'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                label: Text('Inspections'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.science_outlined),
                label: Text('Samples & Results'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                label: Text('Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assessment_outlined),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group_outlined),
                label: Text('Team'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('Settings'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 28, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            snapshot.facility.label,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: onRefresh,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SimulationNotice(compact: true),
                    if (actionMessage != null) ...[
                      const SizedBox(height: 12),
                      NoticeCard(
                        title: 'Action status',
                        message: actionMessage!,
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                    body,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
