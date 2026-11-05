import 'package:flutter/material.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'manager_controller.dart';
import 'manager_screen_states.dart';
import 'manager_widgets.dart';

enum _InspectionFilter { all, overdue, scheduled, submitted, risk }

class ManagerInspectionsScreen extends StatefulWidget {
  const ManagerInspectionsScreen({super.key, required this.controller});
  final ManagerController controller;
  @override
  State<ManagerInspectionsScreen> createState() =>
      _ManagerInspectionsScreenState();
}

class _ManagerInspectionsScreenState extends State<ManagerInspectionsScreen> {
  final search = TextEditingController();
  _InspectionFilter filter = _InspectionFilter.all;
  String? selectedId;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clear() => setState(() {
    search.clear();
    filter = _InspectionFilter.all;
    selectedId = null;
  });
  String status(ManagerInspection item, ManagerWorkspace data) =>
      item.task.isSubmitted
      ? 'Submitted'
      : item.overdue(data.asOf)
      ? 'Overdue'
      : 'Scheduled';

  @override
  Widget build(BuildContext context) => ManagerScreenFrame(
    title: 'Inspections',
    controller: widget.controller,
    isEmpty: (data) => data.inspections.isEmpty,
    emptyMessage: 'No inspections are scheduled for this facility.',
    builder: (context, data) {
      final query = search.text.trim().toLowerCase();
      final items = data.inspections
          .where(
            (i) =>
                '${i.task.id} ${data.asset(i.task.assetId)?.label ?? ''}'
                    .toLowerCase()
                    .contains(query) &&
                switch (filter) {
                  _InspectionFilter.all => true,
                  _InspectionFilter.overdue => i.overdue(data.asOf),
                  _InspectionFilter.scheduled => !i.task.isSubmitted,
                  _InspectionFilter.submitted => i.task.isSubmitted,
                  _InspectionFilter.risk => i.hasRisk,
                },
          )
          .toList();
      final selected = items.where((i) => i.task.id == selectedId).firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'An inspection is a risk-control record, not a laboratory result.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Search inspections or assets',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _InspectionFilter.values)
                FilterChip(
                  label: Text(
                    value == _InspectionFilter.risk
                        ? 'Risk observed'
                        : humanState(value.name),
                  ),
                  selected: filter == value,
                  onSelected: (_) => setState(() => filter = value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            ManagerNoMatches(onClear: clear)
          else
            ManagerRecordLayout(
              onClose: () => setState(() => selectedId = null),
              list: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    ManagerRecordTile(
                      key: ValueKey('inspection-${item.task.id}'),
                      title:
                          '${data.asset(item.task.assetId)?.label ?? 'Unknown asset'} · ${item.task.id.substring(0, 8)}',
                      subtitle:
                          'Due ${recordTime(item.task.dueAt, timezone: data.facility.timezone)}',
                      selected: selected?.task.id == item.task.id,
                      onOpen: () => setState(() => selectedId = item.task.id),
                      badges: [
                        StatusPill(
                          status(item, data),
                          caution: item.overdue(data.asOf),
                        ),
                        if (item.hasRisk)
                          const StatusPill('Risk observed', caution: true),
                      ],
                    ),
                ],
              ),
              detail: selected == null ? null : _detail(data, selected),
            ),
        ],
      );
    },
  );

  Widget _detail(ManagerWorkspace data, ManagerInspection item) {
    final template = data.template(item.task.templateId);
    final incidents = data.incidents
        .where(
          (i) =>
              i.source == EvidenceSource.inspection &&
              i.sourceId == item.task.id,
        )
        .toList();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inspection detail',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          StatusPill(status(item, data), caution: item.overdue(data.asOf)),
          const SizedBox(height: 16),
          ManagerDetail('Inspection ID', item.task.id),
          ManagerDetail(
            'Asset',
            data.asset(item.task.assetId)?.label ?? item.task.assetId,
          ),
          ManagerDetail('Assigned member', item.assignedTo ?? 'Unassigned'),
          ManagerDetail(
            'Due',
            recordTime(item.task.dueAt, timezone: data.facility.timezone),
          ),
          ManagerDetail(
            'Observed on device',
            item.observedAt == null
                ? 'Not submitted'
                : recordTime(
                    item.observedAt!,
                    timezone: data.facility.timezone,
                  ),
          ),
          ManagerDetail(
            'Received by service',
            item.task.submittedAt == null
                ? 'Not received'
                : recordTime(
                    item.task.submittedAt!,
                    timezone: data.facility.timezone,
                  ),
          ),
          if (item.submittedBy != null)
            ManagerDetail('Submitted by', item.submittedBy!),
          ManagerDetail(
            'Checklist',
            template == null
                ? 'Assigned template unavailable'
                : '${template.title} · version ${template.version}',
          ),
          if (template != null) ...[
            ManagerDetail('Checklist source', template.source),
            for (final question in template.questions) ...[
              const Divider(height: 24),
              Text(
                question.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              StatusPill(
                item.answers[question.id] == null
                    ? 'Not answered'
                    : humanState(wireName(item.answers[question.id]!.choice)),
                caution:
                    item.answers[question.id]?.choice == AnswerChoice.yes ||
                    item.answers[question.id]?.choice == AnswerChoice.unknown,
              ),
              const SizedBox(height: 8),
              Text(question.rationale),
              ManagerDetail('Source identifier', question.sourceId),
              if (item.answers[question.id]?.note.isNotEmpty ?? false)
                ManagerDetail('Answer note', item.answers[question.id]!.note),
            ],
          ],
          ManagerDetail(
            'Visit notes',
            item.notes.isEmpty ? 'No visit notes recorded.' : item.notes,
          ),
          if (incidents.isNotEmpty)
            ManagerIncidentList(
              incidents: incidents,
              controller: widget.controller,
              data: data,
            ),
          ManagerAuditTrail(
            events: data.auditFor(item.task.id),
            timezone: data.facility.timezone,
          ),
        ],
      ),
    );
  }
}
