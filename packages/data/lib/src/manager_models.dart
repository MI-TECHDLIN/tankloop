import 'package:tankloop_domain/domain.dart';
import 'lab_models.dart';
import 'repository.dart';

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

List<Map<String, dynamic>> _rows(Map<String, dynamic> json, String key) =>
    (json[key] as List).cast<Map<String, dynamic>>();

Facility _facility(Map<String, dynamic> row) => Facility(
  id: row['id'] as String,
  organizationId: row['organization_id'] as String,
  label: row['public_label'] as String,
  timezone: row['timezone'] as String,
  isSimulated: row['is_simulated'] as bool,
);

/// Read models keep server state and versions intact. Mutations use the domain
/// commands/RPCs; changing a projection cannot confer authority.
class ManagerWorkspace {
  ManagerWorkspace.fromJson(Map<String, dynamic> json)
    : facilities = List.unmodifiable(_rows(json, 'facilities').map(_facility)),
      fetchedAt = _date(json['fetched_at'])!,
      simulationSeed = (json['simulation'] as Map)['simulation_seed'] as int?,
      modelVersion = (json['simulation'] as Map)['model_version'] as int?,
      incidents = List.unmodifiable(
        _rows(json, 'incidents').map(ManagerIncident.fromJson),
      ),
      orders = List.unmodifiable(
        _rows(json, 'work_orders').map(ManagerWorkOrder.fromJson),
      ),
      members = List.unmodifiable(
        _rows(json, 'memberships').map(ManagerMembership.fromJson),
      ),
      qrs = List.unmodifiable(_rows(json, 'qrs').map(ManagerQr.fromJson)),
      samples = List.unmodifiable(
        _rows(json, 'samples').map(ManagerSample.fromJson),
      ),
      results = List.unmodifiable(
        _rows(json, 'records').map(LabRecord.fromJson),
      ),
      audit = List.unmodifiable(
        _rows(json, 'audit').map(ManagerAudit.fromJson),
      ) {
    dashboard = DashboardSnapshot.fromJson({
      ...json,
      'cases': [
        for (final incident in incidents)
          {
            'id': incident.id,
            'source': wireName(incident.source),
            'state': wireName(incident.state),
            'point_label': _rows(json, 'points')
                .where((p) => incident.pointIds.contains(p['id']))
                .map((p) => p['label'])
                .join(', '),
            'reported_at': incident.reportedAt.toIso8601String(),
            'due_at': incident.dueAt?.toIso8601String(),
            'has_owner': incident.ownerId != null,
            'is_simulated': incident.isSimulated,
            'events': <String>[],
          },
      ],
      'public_tokens': {
        for (final qr in qrs.where((q) => q.revokedAt == null))
          qr.pointId: qr.token,
      },
    });
    inspections = List.unmodifiable([
      for (final row in _rows(json, 'inspections'))
        ManagerInspection.fromJson(
          row,
          dashboard.inspections.singleWhere((task) => task.id == row['id']),
        ),
    ]);
    systems = List.unmodifiable([
      for (final row in _rows(json, 'systems'))
        WaterSystem(
          id: row['id'] as String,
          scope: scope,
          label: row['label'] as String,
          isSimulated: row['is_simulated'] as bool,
        ),
    ]);
  }

  late final DashboardSnapshot dashboard;
  final List<Facility> facilities;
  final DateTime fetchedAt;
  final int? simulationSeed;
  final int? modelVersion;
  late final List<WaterSystem> systems;
  late final List<ManagerInspection> inspections;
  final List<ManagerSample> samples;
  final List<LabRecord> results;
  final List<ManagerIncident> incidents;
  final List<ManagerWorkOrder> orders;
  final List<ManagerMembership> members;
  final List<ManagerQr> qrs;
  final List<ManagerAudit> audit;

  Facility get facility => dashboard.facility;
  Scope get scope => facility.scope;
  String get actorId => dashboard.actorId;
  DateTime get asOf => dashboard.asOf;
  List<Asset> get assets => dashboard.assets;
  List<SamplingPoint> get points => dashboard.points;
  List<ChecklistTemplate> get templates => dashboard.templates;

  Asset? asset(String id) => assets.where((a) => a.id == id).firstOrNull;
  SamplingPoint? point(String id) =>
      points.where((p) => p.id == id).firstOrNull;
  ChecklistTemplate? template(String id) =>
      templates.where((t) => t.id == id).firstOrNull;
  List<ManagerAudit> auditFor(String id) =>
      audit.where((a) => a.aggregateId == id).toList();
  List<LabRecord> resultsFor(String sampleId) =>
      results.where((r) => r.sample.id == sampleId).toList();
  LabRecord? currentResult(String sampleId) => results
      .where((r) => r.sample.id == sampleId && !r.isHistorical)
      .firstOrNull;
}

class ManagerInspection {
  ManagerInspection.fromJson(Map<String, dynamic> row, this.task)
    : assignedTo = row['assigned_to'] as String?,
      submittedBy = row['submitted_by'] as String?,
      observedAt = _date(row['observed_at']),
      notes = row['notes'] as String,
      answers = Map.unmodifiable(
        (row['answers'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            key,
            InspectionAnswer.fromJson(value as Map<String, dynamic>),
          ),
        ),
      );
  final InspectionTask task;
  final String? assignedTo;
  final String? submittedBy;
  final DateTime? observedAt;
  final String notes;
  final Map<String, InspectionAnswer> answers;
  bool get hasRisk => answers.values.any((a) => a.choice == AnswerChoice.yes);
  bool overdue(DateTime at) => !task.isSubmitted && task.dueAt.isBefore(at);
}

class ManagerSample {
  ManagerSample.fromJson(Map<String, dynamic> row)
    : sample = SampleRecord(
        id: row['id'] as String,
        code: row['code'] as String,
        scope: Scope(
          row['organization_id'] as String,
          row['facility_id'] as String,
        ),
        pointId: row['point_id'] as String,
        collectorId: row['collector_id'] as String,
        collectedAt: _date(row['collected_at'])!,
        intendedMethod: row['intended_method'] as String,
        isSimulated: row['is_simulated'] as bool,
      ),
      preservationNote = row['preservation_note'] as String,
      custody = List.unmodifiable(
        _rows(row, 'custody').map(
          (c) => CustodyEvent(
            id: c['id'] as String,
            sampleId: c['sample_id'] as String,
            scope: Scope(
              c['organization_id'] as String,
              c['facility_id'] as String,
            ),
            fromActor: c['from_actor'] as String,
            toActor: c['to_actor'] as String,
            occurredAt: _date(c['occurred_at'])!,
            note: c['note'] as String,
            isSimulated: c['is_simulated'] as bool,
          ),
        ),
      );
  final SampleRecord sample;
  final String preservationNote;
  final List<CustodyEvent> custody;
}

class ManagerIncident {
  ManagerIncident.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      source = enumFromWire(EvidenceSource.values, row['source'] as String),
      sourceId = row['source_id'] as String,
      pointIds = List.unmodifiable((row['point_ids'] as List).cast<String>()),
      state = enumFromWire(IncidentState.values, row['state'] as String),
      version = row['version'] as int,
      reportedAt = _date(row['reported_at'])!,
      dueAt = _date(row['due_at']),
      ownerId = row['owner_id'] as String?,
      priority = row['priority'] == null
          ? null
          : Priority.values.byName(row['priority'] as String),
      uncertainty = row['uncertainty'] as String?,
      requiredResponse = row['required_response'] as String?,
      requirements = List.unmodifiable(
        _rows(row, 'requirements').map(ManagerVerificationRequirement.fromJson),
      ),
      escalatedAt = _date(row['escalated_at']),
      isSimulated = row['is_simulated'] as bool;
  final String id;
  final EvidenceSource source;
  final String sourceId;
  final List<String> pointIds;
  final IncidentState state;
  final int version;
  final DateTime reportedAt;
  final DateTime? dueAt;
  final String? ownerId;
  final Priority? priority;
  final String? uncertainty;
  final String? requiredResponse;
  final List<ManagerVerificationRequirement> requirements;
  final DateTime? escalatedAt;
  final bool isSimulated;
  bool get isOpen => state != IncidentState.resolved;
  bool canEscalate(DateTime at) =>
      isOpen &&
      escalatedAt == null &&
      (priority == Priority.critical ||
          (dueAt != null && !at.isBefore(dueAt!)));
}

class ManagerVerificationRequirement {
  ManagerVerificationRequirement.fromJson(Map<String, dynamic> row)
    : kind = row['kind'] as String,
      pointId = row['point_id'] as String?,
      templateId = row['template_id'] as String?,
      indicator = row['indicator'] == null
          ? null
          : enumFromWire(Indicator.values, row['indicator'] as String),
      method = row['method'] as String?,
      notBefore = _date(row['not_before'])!,
      freshFor = row['fresh_for'] as String;
  final String kind;
  final String? pointId;
  final String? templateId;
  final Indicator? indicator;
  final String? method;
  final DateTime notBefore;
  final String freshFor;
}

class ManagerWorkOrder {
  ManagerWorkOrder.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      incidentId = row['incident_id'] as String,
      task = row['task'] as String,
      state = enumFromWire(WorkOrderState.values, row['state'] as String),
      version = row['version'] as int,
      assigneeId = row['assignee_id'] as String?,
      approvedBy = row['approved_by'] as String?,
      dueAt = _date(row['due_at']),
      completionEvidence = row['completion_evidence'] as String?;
  final String id;
  final String incidentId;
  final String task;
  final WorkOrderState state;
  final int version;
  final String? assigneeId;
  final String? approvedBy;
  final DateTime? dueAt;
  final String? completionEvidence;
}

class ManagerMembership {
  ManagerMembership.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      userId = row['user_id'] as String,
      facilityId = row['facility_id'] as String?,
      role = Role.values.byName(row['role'] as String),
      revoked = row['status'] == 'revoked',
      validUntil = _date(row['valid_until']);
  final String id;
  final String userId;
  final String? facilityId;
  final Role role;
  final bool revoked;
  final DateTime? validUntil;
  bool activeAt(DateTime at) =>
      !revoked && (validUntil == null || at.isBefore(validUntil!));
}

class ManagerQr {
  ManagerQr.fromJson(Map<String, dynamic> row)
    : token = row['token'] as String,
      pointId = row['point_id'] as String,
      issuedAt = _date(row['issued_at'])!,
      revokedAt = _date(row['revoked_at']);
  final String token;
  final String pointId;
  final DateTime issuedAt;
  final DateTime? revokedAt;
}

class ManagerAudit {
  ManagerAudit.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      aggregateId = row['aggregate_id'] as String,
      actorId = row['actor_id'] as String?,
      at = _date(row['occurred_at'])!,
      from = row['previous_state'] as String,
      to = row['new_state'] as String,
      reason = row['reason'] as String;
  final String id;
  final String aggregateId;
  final String? actorId;
  final DateTime at;
  final String from;
  final String to;
  final String reason;
}
