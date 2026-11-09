import 'package:material_symbols_icons/symbols.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

/// Wording for people who are not water specialists. Every sentence describes
/// a stored record or a required next step; none of it judges water safety.

const inspectionSteps = [
  FlowStep('Check', Symbols.checklist_rounded),
  FlowStep('Save', Symbols.smartphone_rounded),
  FlowStep('Send', Symbols.cloud_upload_rounded),
  FlowStep('Receipt', Symbols.receipt_long_rounded),
];

/// Index of the inspection step in progress for [entry], or past the end once
/// the server has issued a receipt.
int inspectionStep(OutboxEntry? entry) => switch (entry?.state) {
  null => 0,
  DraftState.draft => 1,
  DraftState.pending || DraftState.blocked => 2,
  DraftState.synced => inspectionSteps.length,
};

const caseSteps = [
  FlowStep('Reported', Symbols.campaign_rounded),
  FlowStep('Action', Symbols.handyman_rounded),
  FlowStep('Follow-up', Symbols.fact_check_rounded),
  FlowStep('Closed', Symbols.task_alt_rounded),
];

int caseStep(IncidentState state) => switch (state) {
  IncidentState.reported ||
  IncidentState.reopened ||
  IncidentState.triaged ||
  IncidentState.assigned ||
  IncidentState.mitigation => 1,
  IncidentState.verificationPending => 2,
  IncidentState.resolved => caseSteps.length,
};

String caseNextStep(IncidentState state) => switch (state) {
  IncidentState.reported => 'Waiting for the facility team to review it.',
  IncidentState.reopened =>
    'Reopened. The facility team needs to act on it again.',
  IncidentState.triaged => 'Reviewed. Waiting for someone to be assigned.',
  IncidentState.assigned => 'Someone is assigned to act on it.',
  IncidentState.mitigation =>
    'Work is under way. A follow-up check comes next.',
  IncidentState.verificationPending =>
    'A follow-up check is needed before the case can close.',
  IncidentState.resolved => 'Closed after the follow-up evidence was reviewed.',
};

bool caseNeedsAction(CaseSummary item) =>
    item.state != IncidentState.resolved && !item.hasOwner;

String sourceName(EvidenceSource source) => switch (source) {
  EvidenceSource.residentReport => 'Resident report',
  EvidenceSource.inspection => 'Inspector observation',
  EvidenceSource.fieldScreen => 'Field screening',
  EvidenceSource.laboratory => 'Laboratory record',
};

DuotoneGlyph sourceAccent(EvidenceSource source) => switch (source) {
  EvidenceSource.residentReport => TankAccents.report,
  EvidenceSource.inspection => TankAccents.inspection,
  EvidenceSource.fieldScreen => TankAccents.checklist,
  EvidenceSource.laboratory => TankAccents.records,
};

String caseOrigin(CaseSummary item) {
  final date = recordDate(item.reportedAt);
  return switch (item.source) {
    EvidenceSource.residentReport => 'A resident reported a concern on $date.',
    EvidenceSource.inspection => 'An inspection raised a concern on $date.',
    EvidenceSource.fieldScreen =>
      'A field screening raised a concern on $date.',
    EvidenceSource.laboratory =>
      'A laboratory record raised a concern on $date.',
  };
}

/// Due state for a task relative to the snapshot time [asOf].
(String, ChipTone) dueLabel(DateTime due, DateTime asOf) {
  if (due.isBefore(asOf)) return ('Overdue', ChipTone.caution);
  if (recordDate(due) == recordDate(asOf)) {
    return ('Due today', ChipTone.caution);
  }
  return ('Due ${recordDate(due)}', ChipTone.neutral);
}
