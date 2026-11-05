import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'manager_catalog.dart';

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
          final data = state.data!;
          return _ManagerShell(
            snapshot: data,
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
            padding: const EdgeInsets.fromLTRB(20, 20, 28, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FrostedSkeleton(height: 32, width: 280),
                  const SizedBox(height: 16),
                  const FrostedSkeleton(height: 42, width: double.infinity),
                  const SizedBox(height: 20),
                  if (selected == 0) ...[
                    Row(
                      children: List.generate(
                        3,
                        (index) => const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: FrostedSkeletonCard(lines: 1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const FrostedSkeletonCard(lines: 2, showIcon: false),
                    const SizedBox(height: 12),
                    ...List.generate(
                      2,
                      (index) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: FrostedSkeletonCard(lines: 2),
                      ),
                    ),
                  ] else ...[
                    ...List.generate(
                      4,
                      (index) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: FrostedSkeletonCard(lines: 2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ManagerShell extends StatelessWidget {
  const _ManagerShell({
    required this.snapshot,
    required this.selected,
    required this.onSelected,
    required this.actionMessage,
    required this.onRefresh,
    required this.onIncident,
    required this.onWorkOrder,
  });
  final DashboardSnapshot snapshot;
  final int selected;
  final ValueChanged<int> onSelected;
  final String? actionMessage;
  final VoidCallback onRefresh;
  final Future<void> Function(IncidentRecord, IncidentState) onIncident;
  final Future<void> Function(WorkOrder, WorkOrderState) onWorkOrder;

  @override
  Widget build(BuildContext context) {
    final engine = (context.findAncestorStateOfType<_ManagerDashboardState>()!)
        .widget
        .repository
        .engine;
    final incidents =
        engine.incidents.values
            .where((i) => i.scope.matches(snapshot.scope))
            .toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    final workOrders = engine.workOrders.values
        .where((w) => w.scope.matches(snapshot.scope))
        .toList();
    final overdue = snapshot.inspections
        .where((i) => i.dueAt.isBefore(snapshot.asOf) && !i.isSubmitted)
        .length;
    final open = incidents.where((i) => i.isOpen).length;
    final coverage = snapshot.inspections.isEmpty
        ? 0
        : ((snapshot.inspections.where((i) => i.isSubmitted).length /
                      snapshot.inspections.length) *
                  100)
              .round();
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
                    if (selected == 0) ...[
                      SectionHeading('Operational overview'),
                      Row(
                        children: [
                          _MetricCard(
                            label: 'Open incidents',
                            value: '$open',
                            icon: Icons.warning_amber_outlined,
                          ),
                          _MetricCard(
                            label: 'Overdue inspections',
                            value: '$overdue',
                            icon: Icons.schedule,
                            caution: overdue > 0,
                          ),
                          _MetricCard(
                            label: 'Sampling coverage',
                            value: '$coverage%',
                            icon: Icons.water_drop_outlined,
                          ),
                        ],
                      ),
                      SectionHeading('Evidence completeness'),
                      GlassCard(
                        child: Text(
                          'Coverage is a workload signal, not proof of safe water. Confirm scope, freshness, method, and independent review before communicating a conclusion.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      _IncidentList(
                        incidents: incidents,
                        onAdvance: onIncident,
                      ),
                    ] else if (selected == 1) ...[
                      ManagerCatalogScreen(
                        title: 'Facilities',
                        snapshot: snapshot,
                        kind: 'facilities',
                      ),
                    ] else if (selected == 2) ...[
                      SectionHeading('Incident workspace'),
                      _IncidentList(
                        incidents: incidents,
                        onAdvance: onIncident,
                      ),
                    ] else if (selected == 3) ...[
                      ManagerCatalogScreen(
                        title: 'Inspections',
                        snapshot: snapshot,
                        kind: 'inspections',
                      ),
                    ] else if (selected == 4) ...[
                      ManagerCatalogScreen(
                        title: 'Samples & Results',
                        snapshot: snapshot,
                        kind: 'samples',
                      ),
                    ] else if (selected == 5) ...[
                      SectionHeading('Work-order approvals'),
                      _WorkOrderList(
                        orders: workOrders,
                        onAdvance: onWorkOrder,
                      ),
                    ] else if (selected == 6) ...[
                      SectionHeading('Reports'),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Facility interpretation',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$coverage% of scheduled inspections have a recorded submission. $open incident(s) remain open. These simulated indicators describe process completeness, not a population-wide water-quality claim.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const StatusPill(
                        'Stale data warning: compare as-of time before acting',
                        icon: Icons.schedule,
                        caution: true,
                      ),
                    ] else if (selected == 7) ...[
                      ManagerCatalogScreen(
                        title: 'Team',
                        snapshot: snapshot,
                        kind: 'team',
                      ),
                    ] else ...[
                      SectionHeading('Settings'),
                      const NoticeCard(
                        title: 'Scoped access',
                        message:
                            'Manager actions are limited to the selected facility and require an authoritative receipt in production.',
                        icon: Icons.lock_outline,
                      ),
                      const NoticeCard(
                        title: 'Offline and permission states',
                        message:
                            'When the service is offline, stale, or access is denied, drafts remain visible but authoritative transitions stay disabled.',
                        icon: Icons.cloud_off_outlined,
                      ),
                    ],
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.caution = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool caution;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GlassCard(
        color: caution ? TankColors.caution.withValues(alpha: .8) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: caution ? TankColors.amber : TankColors.teal),
            const SizedBox(height: 16),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _IncidentList extends StatelessWidget {
  const _IncidentList({required this.incidents, required this.onAdvance});
  final List<IncidentRecord> incidents;
  final Future<void> Function(IncidentRecord, IncidentState) onAdvance;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeading('Incidents'),
      if (incidents.isEmpty)
        const NoticeCard(
          title: 'No incidents in scope',
          message:
              'New evidence will appear here when the authoritative service records it.',
        ),
      ...incidents.map(
        (incident) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${incident.source.name} · ${incident.id.substring(0, 8)}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusPill(
                      incident.state.name.replaceAll('_', ' '),
                      caution: incident.isOpen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reported ${incident.reportedAt.toIso8601String().substring(0, 10)} · ${incident.pointIds.length} affected point(s)',
                ),
                if (incident.uncertainty != null)
                  Text(
                    incident.uncertainty!,
                    style: const TextStyle(color: TankColors.muted),
                  ),
                const SizedBox(height: 12),
                if (incident.state == IncidentState.reported)
                  OutlinedButton(
                    onPressed: () => onAdvance(incident, IncidentState.triaged),
                    child: const Text('Triage'),
                  ),
                if (incident.state == IncidentState.triaged)
                  OutlinedButton(
                    onPressed: () =>
                        onAdvance(incident, IncidentState.assigned),
                    child: const Text('Assign owner'),
                  ),
                if (incident.state == IncidentState.assigned)
                  OutlinedButton(
                    onPressed: () =>
                        onAdvance(incident, IncidentState.mitigation),
                    child: const Text('Record interim measure'),
                  ),
                if (incident.state == IncidentState.mitigation)
                  OutlinedButton(
                    onPressed: () =>
                        onAdvance(incident, IncidentState.verificationPending),
                    child: const Text('Request verification'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _WorkOrderList extends StatelessWidget {
  const _WorkOrderList({required this.orders, required this.onAdvance});
  final List<WorkOrder> orders;
  final Future<void> Function(WorkOrder, WorkOrderState) onAdvance;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (orders.isEmpty)
        const NoticeCard(
          title: 'No work orders',
          message: 'Approved maintenance requests will appear here.',
        ),
      ...orders.map(
        (order) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.task,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusPill(
                      order.state.name.replaceAll('_', ' '),
                      caution: order.state == WorkOrderState.completed,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Incident ${order.incidentId.substring(0, 8)}'),
                const SizedBox(height: 12),
                if (order.state == WorkOrderState.approvalPending)
                  OutlinedButton(
                    onPressed: () => onAdvance(order, WorkOrderState.assigned),
                    child: const Text('Approve and assign'),
                  ),
                if (order.state == WorkOrderState.completed)
                  OutlinedButton(
                    onPressed: () => onAdvance(order, WorkOrderState.accepted),
                    child: const Text('Accept evidence'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
