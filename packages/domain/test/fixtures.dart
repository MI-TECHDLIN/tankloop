import 'package:tankloop_domain/domain.dart';

const scope = Scope('org-a', 'facility-a');
final day = DateTime.utc(2026, 11, 1);
var sequence = 0;
CommandContext context({
  Role role = Role.lab,
  DateTime? at,
  bool online = true,
  Scope inScope = scope,
  bool active = true,
  DateTime? expiresAt,
  String reason = 'Test evidence',
}) => CommandContext(
  actor: Actor(
    id: role.name,
    role: role,
    scope: inScope,
    active: active,
    expiresAt: expiresAt,
  ),
  at: at ?? day.add(const Duration(days: 5)),
  eventId: 'event-${sequence++}',
  serverConfirmed: online,
  reason: reason,
);

ResultRecord collected({
  String id = 'result',
  String point = 'point',
  Scope inScope = scope,
  DateTime? at,
  EvidenceSource source = EvidenceSource.laboratory,
  String method = 'Membrane filtration',
  bool simulated = true,
}) => ResultRecord.collected(
  id: id,
  source: source,
  sample: SampleRecord(
    id: 'sample-$id',
    code: 'SIM-$id',
    scope: inScope,
    pointId: point,
    collectorId: 'field',
    collectedAt: at ?? day.add(const Duration(days: 2)),
    intendedMethod: method,
    isSimulated: simulated,
  ),
);

ResultRecord reviewed({
  String id = 'result',
  double value = 0,
  String point = 'point',
  Scope inScope = scope,
  DateTime? at,
  Indicator indicator = Indicator.eColi,
  String method = 'Membrane filtration',
  bool publish = true,
  bool simulated = true,
}) {
  var result = collected(
    id: id,
    point: point,
    inScope: inScope,
    at: at,
    method: method,
    simulated: simulated,
  );
  final time = result.sample.collectedAt;
  for (final target in [
    ResultState.received,
    ResultState.valid,
    ResultState.tested,
    ResultState.reviewed,
    if (publish) ResultState.published,
  ]) {
    result = result.transition(
      target,
      context(
        inScope: inScope,
        role: target == ResultState.published ? Role.manager : Role.lab,
        at: time.add(Duration(hours: target.index)),
      ),
      reading: target == ResultState.tested
          ? Measurement(
              indicator: indicator,
              method: method,
              value: value,
              unit: ResultUnit.cfuPer100ml,
              detectionLimit: 1,
            )
          : null,
      linkedReport: target == ResultState.reviewed ? 'report-signed' : null,
    );
  }
  return result;
}

IncidentRecord pending({
  EvidenceSource source = EvidenceSource.laboratory,
  VerificationPlan? plan,
}) {
  var incident = IncidentRecord.report(
    id: 'incident',
    scope: scope,
    systemId: 'system',
    pointIds: ['point'],
    source: source,
    sourceId: 'result',
    at: day,
    isSimulated: true,
  );
  incident = incident.transition(
    IncidentState.triaged,
    context(role: Role.manager, at: day),
    const IncidentUpdate(
      priority: Priority.urgent,
      uncertainty: 'Wider scope unknown',
    ),
  );
  incident = incident.transition(
    IncidentState.assigned,
    context(role: Role.manager, at: day),
    IncidentUpdate(
      ownerId: 'field',
      dueAt: day.add(const Duration(days: 4)),
      requiredResponse: 'Inspect and repair',
    ),
  );
  incident = incident.transition(
    IncidentState.mitigation,
    context(role: Role.manager, at: day.add(const Duration(hours: 1))),
    const IncidentUpdate(actionEvidence: 'work'),
  );
  return incident.transition(
    IncidentState.verificationPending,
    context(role: Role.manager, at: day.add(const Duration(days: 1))),
    IncidentUpdate(
      actionEvidence: 'work',
      controlsReviewed: true,
      noticeReviewed: true,
      plan:
          plan ??
          VerificationPlan(
            pointIds: ['point'],
            checklistIds: ['template'],
            indicator: Indicator.eColi,
            method: 'Membrane filtration',
            notBefore: day.add(const Duration(days: 1)),
          ),
    ),
  );
}

ClosureEvidence closure({
  List<ResultRecord>? results,
  List<ChecklistEvidence>? checklists,
  String communication = 'notice',
}) => ClosureEvidence(
  checklists:
      checklists ??
      [
        ChecklistEvidence(
          templateId: 'template',
          scope: scope,
          completedAt: day.add(const Duration(days: 2)),
          hasOutstandingRisk: false,
          isSimulated: true,
        ),
      ],
  results: results ?? [reviewed()],
  communicationRef: communication,
);
