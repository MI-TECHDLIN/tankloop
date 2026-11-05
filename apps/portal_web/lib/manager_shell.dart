import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'manager_approvals.dart';
import 'manager_catalog.dart';
import 'manager_controller.dart';
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
    required this.controller,
    required this.selected,
    required this.onSelected,
    this.accountAction,
    this.accessPanel,
  });
  final ManagerController controller;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget? accountAction;
  final Widget? accessPanel;

  @override
  Widget build(BuildContext context) {
    final data = controller.workspace;
    final body = switch (selected) {
      0 => ManagerOverviewScreen(controller: controller),
      1 => ManagerFacilitiesScreen(controller: controller),
      2 => ManagerIncidentsScreen(controller: controller),
      3 => ManagerInspectionsScreen(controller: controller),
      4 => ManagerSamplesScreen(controller: controller),
      5 => ManagerApprovalsScreen(controller: controller),
      6 => ManagerReportsScreen(controller: controller),
      7 => ManagerTeamScreen(controller: controller),
      _ => ManagerSettingsScreen(controller: controller),
    };
    return LayoutBuilder(
      builder: (context, constraints) => SafeArea(
        child: Row(
          children: [
            if (constraints.maxWidth >= 1000)
              SizedBox(
                width: 248,
                child: NavigationDrawer(
                  selectedIndex: selected,
                  onDestinationSelected: onSelected,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: TankBrand(surface: 'MANAGER'),
                    ),
                    for (final destination in managerDestinations)
                      NavigationDrawerDestination(
                        icon: Icon(destination.icon),
                        label: Flexible(
                          child: Text(
                            destination.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(
                  '$selected:${data?.facility.id}:${data?.actorId}',
                ),
                padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (constraints.maxWidth < 1000) ...[
                        const TankBrand(surface: 'MANAGER'),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<int>(
                          key: ValueKey(selected),
                          initialValue: selected,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Manager section',
                          ),
                          items: [
                            for (var i = 0; i < managerDestinations.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(managerDestinations[i].label),
                              ),
                          ],
                          onChanged: (index) {
                            if (index != null) onSelected(index);
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data?.facility.label ?? 'Manager workspace',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          ?accountAction,
                        ],
                      ),
                      if (data != null) ...[
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          key: ValueKey(data.facility.id),
                          initialValue: data.facility.id,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Authorized facility',
                          ),
                          items: [
                            for (final facility in data.facilities)
                              DropdownMenuItem(
                                value: facility.id,
                                child: Text(
                                  facility.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: controller.busy || controller.refreshing
                              ? null
                              : (id) {
                                  if (id != null && id != data.facility.id) {
                                    controller.refresh(facilityId: id);
                                  }
                                },
                        ),
                      ],
                      if (controller.busy)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Recording action…'),
                        ),
                      KeyedSubtree(
                        key: ValueKey(
                          '$selected:${data?.facility.id}:${data?.actorId}',
                        ),
                        child: body,
                      ),
                      if (accessPanel != null) ...[
                        const SizedBox(height: 20),
                        accessPanel!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
