import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'manager_controller.dart';

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
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Padding(
      padding: EdgeInsets.zero,
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
    required this.controller,
    required this.data,
  });
  final List<ManagerIncident> incidents;
  final ManagerController controller;
  final ManagerWorkspace data;
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
            key: ValueKey('incident-${incident.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${humanState(wireName(incident.source))} · ${incident.id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      humanState(wireName(incident.state)),
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
                ManagerDetail('Owner', incident.ownerId ?? 'Unassigned'),
                if (incident.requiredResponse != null)
                  ManagerDetail(
                    'Required response',
                    incident.requiredResponse!,
                  ),
                ManagerDetail(
                  'Deadline',
                  incident.dueAt == null
                      ? 'Not assigned'
                      : recordTime(
                          incident.dueAt!,
                          timezone: data.facility.timezone,
                        ),
                ),
                ManagerIncidentActions(
                  incident: incident,
                  controller: controller,
                  data: data,
                ),
                if (incident.requirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Recorded verification requirements',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final requirement in incident.requirements)
                    ManagerDetail(
                      requirement.kind == 'sample'
                          ? data.point(requirement.pointId!)?.label ??
                                requirement.pointId!
                          : data.template(requirement.templateId!)?.title ??
                                requirement.templateId!,
                      '${requirement.method ?? 'Follow-up checklist'}${requirement.indicator == null ? '' : ' · ${requirement.indicator!.label}'}\nAfter ${recordTime(requirement.notBefore, timezone: data.facility.timezone)} · Freshness: ${requirement.freshFor}',
                    ),
                ],
                ManagerAuditTrail(
                  events: data.auditFor(incident.id),
                  timezone: data.facility.timezone,
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
    required this.controller,
    required this.data,
  });
  final List<ManagerWorkOrder> orders;
  final ManagerController controller;
  final ManagerWorkspace data;
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
            key: ValueKey('work-order-${order.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.task,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      humanState(wireName(order.state)),
                      caution: order.state == WorkOrderState.completed,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Incident ${order.incidentId.substring(0, 8)}'),
                const SizedBox(height: 12),
                if (order.state == WorkOrderState.approvalPending)
                  OutlinedButton(
                    onPressed: !controller.canWrite
                        ? null
                        : () async {
                            final payload =
                                await showDialog<Map<String, Object?>>(
                                  context: context,
                                  builder: (_) => _ManagerAssignmentDialog(
                                    data: data,
                                    fieldOnly: true,
                                  ),
                                );
                            if (payload == null) return;
                            await controller.act(
                              () => controller.repository.transitionWorkOrder(
                                id: order.id,
                                target: WorkOrderState.assigned,
                                expectedVersion: order.version,
                                payload: payload,
                                reason: payload['reason']! as String,
                              ),
                              'Work order approved and assigned.',
                              basedOn: data,
                            );
                          },
                    child: const Text('Approve and assign'),
                  ),
                if (order.state == WorkOrderState.completed)
                  OutlinedButton(
                    onPressed: !controller.canWrite
                        ? null
                        : () async {
                            final reason = await managerReason(
                              context,
                              title: 'Accept work evidence',
                              message:
                                  order.completionEvidence ??
                                  'No completion evidence recorded.',
                            );
                            if (reason == null) return;
                            await controller.act(
                              () => controller.repository.transitionWorkOrder(
                                id: order.id,
                                target: WorkOrderState.accepted,
                                expectedVersion: order.version,
                                reason: reason,
                              ),
                              'Work evidence accepted. Incident verification remains separate.',
                              basedOn: data,
                            );
                          },
                    child: const Text('Accept evidence'),
                  ),
                ManagerDetail('Assignee', order.assigneeId ?? 'Unassigned'),
                ManagerDetail(
                  'Completion evidence',
                  order.completionEvidence ?? 'Not yet recorded',
                ),
                ManagerAuditTrail(
                  events: data.auditFor(order.id),
                  timezone: data.facility.timezone,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class ManagerDetail extends StatelessWidget {
  const ManagerDetail(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: TankColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );
}

class ManagerRecordTile extends StatelessWidget {
  const ManagerRecordTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.badges = const [],
    this.selected = false,
  });
  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final List<Widget> badges;
  final bool selected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassCard(
      color: selected ? TankColors.mint : null,
      padding: const EdgeInsets.all(4),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: badges),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ManagerRecordLayout extends StatelessWidget {
  const ManagerRecordLayout({
    super.key,
    required this.list,
    required this.detail,
    required this.onClose,
  });
  final Widget list;
  final Widget? detail;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (detail == null) return list;
      final selected = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to list'),
            ),
          ),
          detail!,
        ],
      );
      if (constraints.maxWidth < 900) return selected;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: list),
          const SizedBox(width: 24),
          Expanded(flex: 6, child: selected),
        ],
      );
    },
  );
}

class ManagerAuditTrail extends StatelessWidget {
  const ManagerAuditTrail({
    super.key,
    required this.events,
    required this.timezone,
  });
  final List<ManagerAudit> events;
  final String timezone;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Audit history'),
    children: [
      if (events.isEmpty) const Text('No audit events recorded for this item.'),
      for (final event in events)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${humanState(event.from)} → ${humanState(event.to)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(recordTime(event.at, timezone: timezone)),
              Text(event.reason),
              ManagerDetail('Actor', event.actorId ?? 'System'),
              ManagerDetail('Audit ID', event.id),
            ],
          ),
        ),
    ],
  );
}

class ManagerNoMatches extends StatelessWidget {
  const ManagerNoMatches({super.key, required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => NoticeCard(
    title: 'No matching records',
    message: 'Try another search or clear the filters.',
    action: TextButton(onPressed: onClear, child: const Text('Clear filters')),
  );
}

Future<String?> managerReason(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Confirm',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _ManagerReasonDialog(title: title, message: message, action: action),
);

class _ManagerReasonDialog extends StatefulWidget {
  const _ManagerReasonDialog({
    required this.title,
    required this.message,
    required this.action,
  });
  final String title;
  final String message;
  final String action;
  @override
  State<_ManagerReasonDialog> createState() => _ManagerReasonDialogState();
}

class _ManagerReasonDialogState extends State<_ManagerReasonDialog> {
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              maxLines: 3,
              maxLength: 1000,
              validator: managerRequired,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, reason.text.trim());
          }
        },
        child: Text(widget.action),
      ),
    ],
  );
}

String? managerRequired(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

class ManagerIncidentActions extends StatelessWidget {
  const ManagerIncidentActions({
    super.key,
    required this.incident,
    required this.controller,
    required this.data,
  });
  final ManagerIncident incident;
  final ManagerController controller;
  final ManagerWorkspace data;
  bool get hasApprovedWork => data.orders.any(
    (w) =>
        w.incidentId == incident.id &&
        w.approvedBy != null &&
        {
          WorkOrderState.assigned,
          WorkOrderState.inProgress,
          WorkOrderState.completed,
          WorkOrderState.accepted,
          WorkOrderState.rework,
        }.contains(w.state),
  );
  bool get hasAcceptedWork => data.orders.any(
    (w) => w.incidentId == incident.id && w.state == WorkOrderState.accepted,
  );
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (incident.state == IncidentState.reported ||
          incident.state == IncidentState.reopened)
        OutlinedButton(
          onPressed: !controller.canWrite
              ? null
              : () async {
                  final values = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => const _ManagerTriageDialog(),
                  );
                  if (values == null) return;
                  await controller.act(
                    () => controller.repository.transitionIncident(
                      id: incident.id,
                      target: IncidentState.triaged,
                      expectedVersion: incident.version,
                      payload: values,
                      reason: values['reason']! as String,
                    ),
                    'Concern triaged.',
                    basedOn: data,
                  );
                },
          child: const Text('Triage'),
        ),
      if (incident.state == IncidentState.triaged)
        OutlinedButton(
          onPressed: !controller.canWrite
              ? null
              : () async {
                  final values = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => _ManagerAssignmentDialog(data: data),
                  );
                  if (values == null) return;
                  await controller.act(
                    () => controller.repository.transitionIncident(
                      id: incident.id,
                      target: IncidentState.assigned,
                      expectedVersion: incident.version,
                      payload: values,
                      reason: values['reason']! as String,
                    ),
                    'Accountable owner assigned.',
                    basedOn: data,
                  );
                },
          child: const Text('Assign owner'),
        ),
      if (incident.state == IncidentState.assigned)
        OutlinedButton(
          onPressed: !controller.canWrite || !hasApprovedWork
              ? null
              : () async {
                  final reason = await managerReason(
                    context,
                    title: 'Record interim measure',
                    message:
                        'Link the approved work to this concern and record why the interim measure was taken. Verification remains outstanding.',
                  );
                  if (reason == null) return;
                  await controller.act(
                    () => controller.repository.transitionIncident(
                      id: incident.id,
                      target: IncidentState.mitigation,
                      expectedVersion: incident.version,
                      reason: reason,
                    ),
                    'Interim measure recorded against approved work.',
                    basedOn: data,
                  );
                },
          child: const Text('Record interim measure'),
        ),
      if ({
        IncidentState.assigned,
        IncidentState.mitigation,
      }.contains(incident.state)) ...[
        OutlinedButton(
          onPressed: !controller.canWrite || !hasAcceptedWork
              ? null
              : () async {
                  final values = await showDialog<Map<String, Object?>>(
                    context: context,
                    builder: (_) => _ManagerVerificationDialog(
                      data: data,
                      incident: incident,
                    ),
                  );
                  if (values == null) return;
                  await controller.act(
                    () => controller.repository.transitionIncident(
                      id: incident.id,
                      target: IncidentState.verificationPending,
                      expectedVersion: incident.version,
                      payload: values,
                      reason: values['reason']! as String,
                    ),
                    'Verification requested. Closure still requires reviewed follow-up evidence.',
                    basedOn: data,
                  );
                },
          child: const Text('Request verification'),
        ),
        if (!hasApprovedWork)
          const Text(
            'An approved work order is required before recording an interim measure.',
          ),
        if (!hasAcceptedWork)
          const Text('Verification requires accepted work evidence.'),
      ],
      if (incident.canEscalate(data.asOf))
        OutlinedButton(
          onPressed: !controller.canWrite
              ? null
              : () async {
                  final reason = await managerReason(
                    context,
                    title: 'Escalate internally',
                    message:
                        'Record an internal escalation for this critical or overdue concern. This does not contact an external authority.',
                  );
                  if (reason == null) return;
                  await controller.act(
                    () => controller.repository.escalateIncident(
                      id: incident.id,
                      expectedVersion: incident.version,
                      reason: reason,
                    ),
                    'Internal escalation recorded.',
                    basedOn: data,
                  );
                },
          child: const Text('Escalate internally'),
        ),
    ],
  );
}

class _ManagerVerificationDialog extends StatefulWidget {
  const _ManagerVerificationDialog({
    required this.data,
    required this.incident,
  });
  final ManagerWorkspace data;
  final ManagerIncident incident;
  @override
  State<_ManagerVerificationDialog> createState() =>
      _ManagerVerificationDialogState();
}

class _ManagerVerificationDialogState
    extends State<_ManagerVerificationDialog> {
  final form = GlobalKey<FormState>();
  final notice = TextEditingController();
  final reason = TextEditingController();
  String? templateId;
  bool controlsReviewed = false;
  bool noticeReviewed = false;

  @override
  void dispose() {
    notice.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labFinding = widget.incident.source == EvidenceSource.laboratory;
    final measurement = widget.data.results
        .where((r) => r.id == widget.incident.sourceId)
        .firstOrNull
        ?.measurement;
    final available = !labFinding || measurement != null;
    return AlertDialog(
      title: const Text('Request verification'),
      scrollable: true,
      content: SizedBox(
        width: 500,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Accepted work is recorded. Specify the follow-up evidence and record the controls and notice review.',
              ),
              const SizedBox(height: 16),
              if (!available)
                const Text(
                  'The original laboratory method is unavailable. Refresh before configuring follow-up.',
                ),
              if (labFinding && measurement != null) ...[
                ManagerDetail(
                  'Required follow-up sample method',
                  '${measurement.indicator.label} · ${measurement.method}',
                ),
                for (final id in widget.incident.pointIds)
                  ManagerDetail(
                    'Required sampling point',
                    widget.data.point(id)?.label ?? id,
                  ),
              ],
              if (!labFinding)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Follow-up checklist',
                  ),
                  items: [
                    for (final template in widget.data.templates)
                      DropdownMenuItem(
                        value: template.id,
                        child: Text(
                          '${template.title} · v${template.version}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => templateId = value,
                  validator: managerRequired,
                ),
              const SizedBox(height: 16),
              FormField<bool>(
                initialValue: false,
                validator: (value) => value == true
                    ? null
                    : 'Review interim controls before continuing',
                builder: (field) => Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Interim controls reviewed'),
                      value: field.value,
                      onChanged: (value) {
                        controlsReviewed = value == true;
                        field.didChange(value);
                      },
                    ),
                    if (field.hasError)
                      Text(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              FormField<bool>(
                initialValue: false,
                validator: (value) => value == true
                    ? null
                    : 'Review the public notice before continuing',
                builder: (field) => Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Public notice reviewed'),
                      value: field.value,
                      onChanged: (value) {
                        noticeReviewed = value == true;
                        field.didChange(value);
                      },
                    ),
                    if (field.hasError)
                      Text(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notice,
                decoration: const InputDecoration(
                  labelText: 'Reviewed notice reference',
                ),
                maxLength: 1000,
                validator: managerRequired,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLength: 1000,
                validator: managerRequired,
              ),
              const Text(
                'The service saves an audited verification plan before requesting the transition. If interrupted, refresh to review the saved plan.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !available
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(context, <String, Object?>{
                    'requirements': [
                      if (labFinding)
                        for (final id in widget.incident.pointIds)
                          <String, Object?>{
                            'kind': 'sample',
                            'point_id': id,
                            'indicator': wireName(measurement!.indicator),
                            'method': measurement.method,
                          },
                      if (!labFinding)
                        <String, Object?>{
                          'kind': 'checklist',
                          'template_id': templateId,
                        },
                    ],
                    'controls_reviewed': controlsReviewed,
                    'notice_reviewed': noticeReviewed,
                    'notice_ref': notice.text.trim(),
                    'reason': reason.text.trim(),
                  });
                },
          child: const Text('Save plan and request verification'),
        ),
      ],
    );
  }
}

class _ManagerTriageDialog extends StatefulWidget {
  const _ManagerTriageDialog();
  @override
  State<_ManagerTriageDialog> createState() => _ManagerTriageDialogState();
}

class _ManagerTriageDialogState extends State<_ManagerTriageDialog> {
  final form = GlobalKey<FormState>();
  final uncertainty = TextEditingController();
  final reason = TextEditingController();
  Priority? priority;
  @override
  void dispose() {
    uncertainty.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Triage concern'),
    scrollable: true,
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Priority>(
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final value in Priority.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(humanState(value.name)),
                  ),
              ],
              onChanged: (value) => priority = value,
              validator: (value) => value == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: uncertainty,
              decoration: const InputDecoration(
                labelText: 'Scope and uncertainty',
              ),
              maxLines: 3,
              maxLength: 1000,
              validator: managerRequired,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              maxLength: 1000,
              validator: managerRequired,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, <String, Object?>{
              'priority': priority!.name,
              'uncertainty': uncertainty.text.trim(),
              'reason': reason.text.trim(),
            });
          }
        },
        child: const Text('Record triage'),
      ),
    ],
  );
}

class _ManagerAssignmentDialog extends StatefulWidget {
  const _ManagerAssignmentDialog({required this.data, this.fieldOnly = false});
  final ManagerWorkspace data;
  final bool fieldOnly;
  @override
  State<_ManagerAssignmentDialog> createState() =>
      _ManagerAssignmentDialogState();
}

class _ManagerAssignmentDialogState extends State<_ManagerAssignmentDialog> {
  final form = GlobalKey<FormState>();
  final due = TextEditingController();
  final response = TextEditingController();
  final reason = TextEditingController();
  String? owner;
  @override
  void dispose() {
    due.dispose();
    response.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.data.members.where(
      (m) =>
          m.facilityId == widget.data.facility.id &&
          m.activeAt(widget.data.fetchedAt) &&
          (!widget.fieldOnly || m.role == Role.field),
    );
    final users = {for (final m in members) m.userId: m};
    return AlertDialog(
      title: Text(
        widget.fieldOnly
            ? 'Approve and assign work'
            : 'Assign accountable owner',
      ),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned member'),
                items: [
                  for (final member in users.values)
                    DropdownMenuItem(
                      value: member.userId,
                      child: Text(
                        '${humanState(member.role.name)} · ${member.userId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => owner = value,
                validator: managerRequired,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: due,
                decoration: const InputDecoration(
                  labelText: 'Deadline (UTC, YYYY-MM-DD)',
                ),
                keyboardType: TextInputType.datetime,
                validator: (value) {
                  final parsed = DateTime.tryParse(
                    '${value?.trim()}T00:00:00Z',
                  );
                  return parsed == null ||
                          isoDate(parsed) != value?.trim() ||
                          !parsed.isAfter(widget.data.asOf)
                      ? 'Enter a future date in YYYY-MM-DD format'
                      : null;
                },
              ),
              if (!widget.fieldOnly) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: response,
                  decoration: const InputDecoration(
                    labelText: 'Required response',
                  ),
                  maxLines: 3,
                  maxLength: 1000,
                  validator: managerRequired,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                maxLength: 1000,
                validator: managerRequired,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, <String, Object?>{
                'owner_id': owner,
                'assignee_id': owner,
                'due_at': '${due.text.trim()}T00:00:00Z',
                'required_response': response.text.trim(),
                'reason': reason.text.trim(),
              });
            }
          },
          child: const Text('Confirm assignment'),
        ),
      ],
    );
  }
}
