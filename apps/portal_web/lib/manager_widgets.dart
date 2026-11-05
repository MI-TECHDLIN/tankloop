import 'package:flutter/material.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';

class ManagerMetric extends StatelessWidget {
  const ManagerMetric({
    super.key,
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

class ManagerIncidentList extends StatelessWidget {
  const ManagerIncidentList({
    super.key,
    required this.incidents,
    required this.onAdvance,
  });
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

class ManagerWorkOrderList extends StatelessWidget {
  const ManagerWorkOrderList({
    super.key,
    required this.orders,
    required this.onAdvance,
  });
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
