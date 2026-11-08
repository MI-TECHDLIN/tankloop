import 'dart:convert';
import 'dart:io';
import 'field_work.dart';
import 'dart:typed_data';
import 'package:supabase/supabase.dart';
import 'package:tankloop_domain/domain.dart';

enum FailureKind { transient, permission, conflict, invalid }

class RepositoryFailure implements Exception {
  const RepositoryFailure(this.kind, this.message);
  final FailureKind kind;
  final String message;
  @override
  String toString() => message;
}

class SyncReceipt {
  const SyncReceipt({
    required this.clientEventId,
    required this.inspectionId,
    required this.version,
    required this.receivedAt,
  });
  final String clientEventId;
  final String inspectionId;
  final int version;
  final DateTime receivedAt;
  Map<String, Object?> toJson() => {
    'client_event_id': clientEventId,
    'inspection_id': inspectionId,
    'version': version,
    'received_at': receivedAt.toUtc().toIso8601String(),
  };
  factory SyncReceipt.fromJson(Map<String, dynamic> j) => SyncReceipt(
    clientEventId: j['client_event_id'] as String,
    inspectionId: j['inspection_id'] as String,
    version: j['version'] as int,
    receivedAt: DateTime.parse(j['received_at'] as String),
  );
}

class CaseSummary {
  CaseSummary({
    required this.id,
    required this.source,
    required this.state,
    required this.pointLabel,
    required this.reportedAt,
    required this.isSimulated,
    this.dueAt,
    this.hasOwner = false,
    this.events = const [],
  });
  final String id;
  final EvidenceSource source;
  final IncidentState state;
  final String pointLabel;
  final DateTime reportedAt;
  final DateTime? dueAt;
  final bool hasOwner;
  final bool isSimulated;
  final List<String> events;
  Map<String, Object?> toJson() => {
    'id': id,
    'source': wireName(source),
    'state': wireName(state),
    'point_label': pointLabel,
    'reported_at': reportedAt.toUtc().toIso8601String(),
    'due_at': dueAt?.toUtc().toIso8601String(),
    'has_owner': hasOwner,
    'is_simulated': isSimulated,
    'events': events,
  };
  factory CaseSummary.fromJson(Map<String, dynamic> j) => CaseSummary(
    id: j['id'] as String,
    source: enumFromWire(EvidenceSource.values, j['source'] as String),
    state: enumFromWire(IncidentState.values, j['state'] as String),
    pointLabel: j['point_label'] as String,
    reportedAt: DateTime.parse(j['reported_at'] as String),
    dueAt: j['due_at'] == null ? null : DateTime.parse(j['due_at'] as String),
    hasOwner: j['has_owner'] as bool,
    isSimulated: j['is_simulated'] as bool,
    events: (j['events'] as List).cast<String>(),
  );
}

Scope _scope(Map<String, dynamic> j) =>
    Scope(j['organization_id'] as String, j['facility_id'] as String);

class DashboardSnapshot {
  DashboardSnapshot({
    required this.facility,
    required this.actorId,
    required this.asOf,
    required this.assets,
    required this.points,
    required this.templates,
    required this.inspections,
    required this.cases,
    required this.publicTokens,
    this.workOrders = const [],
  });
  final Facility facility;
  final String actorId;
  final DateTime asOf;
  final List<Asset> assets;
  final List<SamplingPoint> points;
  final List<ChecklistTemplate> templates;
  final List<InspectionTask> inspections;
  final List<CaseSummary> cases;
  final Map<String, String> publicTokens;
  final List<FieldWorkOrder> workOrders;
  Scope get scope => facility.scope;
  ChecklistTemplate templateFor(InspectionTask task) =>
      templates.singleWhere((t) => t.id == task.templateId);
  Asset assetFor(InspectionTask task) =>
      assets.singleWhere((a) => a.id == task.assetId);
  Map<String, Object?> toJson() => {
    'facility': facility.toJson(),
    'actor_id': actorId,
    'as_of': asOf.toUtc().toIso8601String(),
    'assets': assets.map((a) => a.toJson()).toList(),
    'points': points.map((a) => a.toJson()).toList(),
    'templates': templates.map((a) => a.toJson()).toList(),
    'inspections': inspections.map((a) => a.toJson()).toList(),
    'cases': cases.map((a) => a.toJson()).toList(),
    'public_tokens': publicTokens,
    'work_orders': workOrders.map((w) => w.toJson()).toList(),
  };
  factory DashboardSnapshot.fromJson(Map<String, dynamic> j) {
    final f = j['facility'] as Map<String, dynamic>;
    return DashboardSnapshot(
      facility: Facility(
        id: f['id'] as String,
        organizationId: f['organization_id'] as String,
        label: f['public_label'] as String,
        timezone: f['timezone'] as String,
        isSimulated: f['is_simulated'] as bool,
      ),
      workOrders: (j['work_orders'] as List? ?? [])
          .map((w) => FieldWorkOrder.fromJson(w as Map<String, dynamic>))
          .toList(),
      actorId: j['actor_id'] as String,
      asOf: DateTime.parse(j['as_of'] as String),
      assets: (j['assets'] as List).map((v) {
        final a = v as Map<String, dynamic>;
        return Asset(
          id: a['id'] as String,
          scope: _scope(a),
          systemId: a['system_id'] as String,
          type: AssetType.values.byName(a['type'] as String),
          label: a['label'] as String,
          parentId: a['parent_asset_id'] as String?,
          capacityLitres: a['capacity_litres'] as int?,
          retiredAt: a['retired_at'] == null
              ? null
              : DateTime.parse(a['retired_at'] as String).toUtc(),
          isSimulated: a['is_simulated'] as bool,
        );
      }).toList(),
      points: (j['points'] as List).map((v) {
        final p = v as Map<String, dynamic>;
        return SamplingPoint(
          id: p['id'] as String,
          scope: _scope(p),
          assetId: p['asset_id'] as String,
          label: p['label'] as String,
          isSimulated: p['is_simulated'] as bool,
        );
      }).toList(),
      templates: (j['templates'] as List).map((v) {
        final t = v as Map<String, dynamic>;
        return ChecklistTemplate(
          id: t['id'] as String,
          scope: _scope(t),
          version: t['version'] as int,
          title: t['title'] as String,
          source: t['source'] as String,
          assetType: AssetType.values.byName(t['asset_type'] as String),
          questions: (t['questions'] as List)
              .map((q) => ChecklistQuestion.fromJson(q as Map<String, dynamic>))
              .toList(),
          isSimulated: t['is_simulated'] as bool,
        );
      }).toList(),
      inspections: (j['inspections'] as List).map((v) {
        final t = v as Map<String, dynamic>;
        return InspectionTask(
          id: t['id'] as String,
          scope: _scope(t),
          assetId: t['asset_id'] as String,
          templateId: t['template_id'] as String,
          dueAt: DateTime.parse(t['due_at'] as String),
          version: t['version'] as int,
          submittedAt: t['received_at'] == null
              ? null
              : DateTime.parse(t['received_at'] as String),
          isSimulated: t['is_simulated'] as bool,
        );
      }).toList(),
      cases: (j['cases'] as List)
          .map((c) => CaseSummary.fromJson(c as Map<String, dynamic>))
          .toList(),
      publicTokens: (j['public_tokens'] as Map<String, dynamic>)
          .cast<String, String>(),
    );
  }
}

abstract class TankLoopRepository {
  const TankLoopRepository();
  Future<DashboardSnapshot> today();
  Future<SyncReceipt> submitInspection(InspectionSubmission command);
  Future<PublicWaterRecord?> publicRecord(String token);
}

abstract class ManagerRepository extends TankLoopRepository {
  const ManagerRepository();
  Future<int> transitionIncident({
    required String id,
    required IncidentState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  });
  Future<int> transitionWorkOrder({
    required String id,
    required WorkOrderState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  });
  Future<int> escalateIncident({
    required String id,
    required int expectedVersion,
    required String reason,
  });
}

class SimulationRepository extends ManagerRepository
    implements FieldWorkRepository {
  SimulationRepository({int seed = 20261101, int day = 10})
    : engine = SimulationEngine(seed: seed)..advance(Duration(days: day));
  final SimulationEngine engine;
  final _workReceipts = <String, WorkStepReceipt>{};
  final _workRequests = <String, String>{};
  @override
  Future<WorkStepReceipt> submitWorkStep(WorkStepCommand command) async {
    final prior = _workReceipts[command.clientEventId];
    final content = jsonEncode(command.toJson());
    if (prior != null) {
      requireRule(
        _workRequests[command.clientEventId] == content,
        'event_conflict',
        'Command content changed.',
      );
      return prior;
    }
    final order = engine.workOrders[command.orderId];
    requireRule(
      order != null &&
          order.version == command.expectedVersion &&
          order.scope.matches(command.scope),
      'version_conflict',
      'Refresh this work order before recording another step.',
    );
    final next = order!.transition(
      command.target,
      CommandContext(
        actor: engine.actorFor(order.scope, Role.field),
        at: engine.now,
        eventId: command.clientEventId,
        serverConfirmed: true,
        reason: command.notes.isEmpty
            ? 'Simulated field action'
            : command.notes,
      ),
      evidence: command.notes.isEmpty ? null : command.notes,
      evidenceFiles: command.evidence,
    );
    engine.workOrders[order.id] = next;
    final receipt = WorkStepReceipt(
      clientEventId: command.clientEventId,
      orderId: order.id,
      version: next.version,
      receivedAt: engine.now,
    );
    _workRequests[command.clientEventId] = content;
    _workReceipts[command.clientEventId] = receipt;
    return receipt;
  }

  @override
  Future<DashboardSnapshot> today() async {
    final facility = engine.facilities.first;
    final tasks =
        engine.inspections.values
            .where((t) => t.scope.matches(facility.scope))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return DashboardSnapshot(
      facility: facility,
      actorId: engine.actorFor(facility.scope, Role.field).id,
      asOf: engine.now,
      assets: engine.assets
          .where((a) => a.scope.matches(facility.scope))
          .toList(),
      points: engine.points
          .where((p) => p.scope.matches(facility.scope))
          .toList(),
      templates: engine.templates
          .where((t) => t.scope.matches(facility.scope))
          .toList(),
      inspections: tasks,
      cases: engine.incidents.values
          .where((i) => i.scope.matches(facility.scope))
          .map(
            (i) => CaseSummary(
              id: i.id,
              source: i.source,
              state: i.state,
              pointLabel: engine.points
                  .singleWhere((p) => p.id == i.pointIds.first)
                  .label,
              reportedAt: i.reportedAt,
              dueAt: i.dueAt,
              hasOwner: i.ownerId != null,
              isSimulated: true,
              events: i.history
                  .map((e) => '${isoDate(e.at)} · ${e.to.replaceAll('_', ' ')}')
                  .toList(),
            ),
          )
          .toList(),
      workOrders: engine.workOrders.values
          .where((w) => w.scope.matches(facility.scope))
          .map(
            (w) =>
                FieldWorkOrder.fromJson(Map<String, dynamic>.from(w.toJson())),
          )
          .toList(),
      publicTokens: {
        for (final q in engine.qrs.where(
          (q) => q.scope.matches(facility.scope),
        ))
          q.pointId: q.token,
      },
    );
  }

  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) async {
    try {
      final version = engine.submitInspection(command);
      return SyncReceipt(
        clientEventId: command.clientEventId,
        inspectionId: command.taskId,
        version: version,
        receivedAt: engine.inspections[command.taskId]!.submittedAt!,
      );
    } on RuleViolation catch (error) {
      throw RepositoryFailure(
        error.code.contains('conflict')
            ? FailureKind.conflict
            : error.code == 'permission_denied'
            ? FailureKind.permission
            : FailureKind.invalid,
        error.message,
      );
    }
  }

  @override
  Future<PublicWaterRecord?> publicRecord(String token) async =>
      engine.publicRecord(token);

  @override
  Future<int> transitionIncident({
    required String id,
    required IncidentState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) async {
    final incident = engine.incidents[id];
    if (incident == null || incident.version != expectedVersion) {
      throw const RepositoryFailure(
        FailureKind.conflict,
        'This incident changed on the server. Refresh before acting.',
      );
    }
    engine.managerAdvanceIncident(id, target);
    return engine.incidents[id]!.version;
  }

  @override
  Future<int> transitionWorkOrder({
    required String id,
    required WorkOrderState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) async {
    final order = engine.workOrders[id];
    if (order == null || order.version != expectedVersion) {
      throw const RepositoryFailure(
        FailureKind.conflict,
        'This work order changed on the server. Refresh before acting.',
      );
    }
    engine.managerAdvanceWorkOrder(id, target);
    return engine.workOrders[id]!.version;
  }

  @override
  Future<int> escalateIncident({
    required String id,
    required int expectedVersion,
    required String reason,
  }) async {
    final incident = engine.incidents[id];
    if (incident == null || incident.version != expectedVersion) {
      throw const RepositoryFailure(
        FailureKind.conflict,
        'This incident changed on the server. Refresh before acting.',
      );
    }
    engine.incidents[id] = incident.escalate(
      CommandContext(
        actor: engine.actorFor(incident.scope, Role.manager),
        at: engine.now,
        eventId: 'simulation-escalation-${incident.id}-${incident.version}',
        serverConfirmed: true,
        reason: 'Simulated: $reason',
      ),
    );
    return engine.incidents[id]!.version;
  }
}

class SupabaseTankLoopRepository extends ManagerRepository
    implements EvidenceUploader, FieldWorkRepository {
  const SupabaseTankLoopRepository(this.client);
  final SupabaseClient client;
  @override
  Future<WorkStepReceipt> submitWorkStep(WorkStepCommand command) async {
    try {
      final result = await client.rpc(
        'submit_work_step',
        params: {
          'p_event_id': command.clientEventId,
          'p_work_order_id': command.orderId,
          'p_expected_version': command.expectedVersion,
          'p_target': wireName(command.target),
          'p_notes': command.notes,
          'p_observed_at': command.observedAt.toUtc().toIso8601String(),
          'p_evidence': command.evidence
              .map(
                (e) => {
                  'id': e.id,
                  'path': e.uploadedPath,
                  'captured_at': e.capturedAt.toUtc().toIso8601String(),
                },
              )
              .toList(),
        },
      );
      return WorkStepReceipt.fromJson(result as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<String> uploadEvidence(
    InspectionEvidence evidence, {
    Uint8List? bytes,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Sign in before uploading photo evidence.',
      );
    }
    final path = '$userId/inspections/${evidence.id}.jpg';
    try {
      await client.storage
          .from('inspection-evidence')
          .uploadBinary(
            path,
            bytes ?? await File(evidence.localPath).readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      return path;
    } on StorageException catch (error) {
      if (error.statusCode == '409' || error.error == 'Duplicate') return path;
      throw const RepositoryFailure(
        FailureKind.transient,
        'Photo evidence could not be uploaded. It remains saved on this device.',
      );
    }
  }

  @override
  Future<DashboardSnapshot> today() async {
    if (client.auth.currentUser == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Sign in to load your assigned facility.',
      );
    }
    try {
      final facilities = await client
          .from('facilities')
          .select('*,organizations(settings)')
          .eq('is_simulated', false)
          .order('id')
          .limit(1);
      if (facilities.isEmpty) {
        throw const RepositoryFailure(
          FailureKind.permission,
          'No active facility membership. Ask the organization administrator to assign access.',
        );
      }
      final facility = facilities.single;
      final id = facility['id'] as String;
      final organization = facility['organizations'] as Map<String, dynamic>;
      final settings = organization['settings'] as Map<String, dynamic>;
      final simulatedAt = facility['is_simulated'] == true
          ? settings['simulation_clock'] as String?
          : null;
      final rows = await Future.wait([
        client
            .from('assets')
            .select()
            .eq('facility_id', id)
            .eq('is_simulated', false)
            .isFilter('retired_at', null),
        client
            .from('sampling_points')
            .select()
            .eq('facility_id', id)
            .eq('is_simulated', false),
        client
            .from('checklist_templates')
            .select()
            .eq('facility_id', id)
            .eq('is_simulated', false),
        client
            .from('inspections')
            .select()
            .eq('facility_id', id)
            .eq('is_simulated', false)
            .order('due_at'),
        client
            .from('incidents')
            .select()
            .eq('facility_id', id)
            .eq('is_simulated', false)
            .order('reported_at', ascending: false),
        client
            .from('public_records')
            .select('point_id,token')
            .eq('facility_id', id)
            .eq('is_simulated', false)
            .isFilter('revoked_at', null),
        client
            .from('work_orders')
            .select()
            .eq('facility_id', id)
            .eq('is_simulated', false)
            .eq('assignee_id', client.auth.currentUser!.id),
      ]);
      return DashboardSnapshot.fromJson({
        'facility': facility,
        'actor_id': client.auth.currentUser!.id,
        'as_of': simulatedAt ?? DateTime.now().toUtc().toIso8601String(),
        'assets': rows[0],
        'points': rows[1],
        'templates': rows[2],
        'inspections': rows[3],
        'cases': rows[4]
            .map(
              (i) => {
                ...i,
                'point_label': rows[1]
                    .where((p) => (i['point_ids'] as List).contains(p['id']))
                    .map((p) => p['label'])
                    .join(', '),
                'has_owner': i['owner_id'] != null,
                'events': <String>[],
              },
            )
            .toList(),
        'work_orders': rows[6],
        'public_tokens': {
          for (final row in rows[5])
            row['point_id'] as String: row['token'] as String,
        },
      });
    } on PostgrestException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) async {
    try {
      final value = await client.rpc(
        'submit_inspection_with_evidence',
        params: {
          'p_event_id': command.clientEventId,
          'p_inspection_id': command.taskId,
          'p_expected_version': command.expectedVersion,
          'p_answers': command.answers.map(
            (id, answer) => MapEntry(id, answer.toJson()),
          ),
          'p_notes': command.notes,
          'p_evidence': command.evidence
              .map(
                (e) => {
                  'id': e.id,
                  'path': e.uploadedPath,
                  'captured_at': e.capturedAt.toUtc().toIso8601String(),
                  'question_id': e.questionId,
                },
              )
              .toList(),
          'p_observed_at': command.observedAt.toUtc().toIso8601String(),
        },
      );
      return SyncReceipt.fromJson(value as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<PublicWaterRecord?> publicRecord(String token) async {
    try {
      final value = await client.rpc(
        'lookup_public_record',
        params: {'p_token': token},
      );
      return value == null
          ? null
          : PublicWaterRecord.fromJson(value as Map<String, dynamic>);
    } on PostgrestException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<int> transitionIncident({
    required String id,
    required IncidentState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) => _rpcVersion('transition_incident', {
    'p_id': id,
    'p_target': wireName(target),
    'p_expected_version': expectedVersion,
    'p_payload': payload,
    'p_reason': reason,
  });

  @override
  Future<int> transitionWorkOrder({
    required String id,
    required WorkOrderState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) => _rpcVersion('transition_work_order', {
    'p_id': id,
    'p_target': wireName(target),
    'p_expected_version': expectedVersion,
    'p_payload': payload,
    'p_reason': reason,
  });

  @override
  Future<int> escalateIncident({
    required String id,
    required int expectedVersion,
    required String reason,
  }) => _rpcVersion('escalate_incident', {
    'p_id': id,
    'p_expected_version': expectedVersion,
    'p_reason': reason,
  });

  Future<int> _rpcVersion(String name, Map<String, Object?> params) async {
    try {
      final value = await client.rpc(name, params: params);
      return value as int;
    } on PostgrestException catch (error) {
      throw _mapFailure(error);
    }
  }

  RepositoryFailure _mapFailure(
    PostgrestException error,
  ) => switch (error.code) {
    '42501' ||
    'PGRST301' ||
    'PGRST302' ||
    'PGRST303' => const RepositoryFailure(
      FailureKind.permission,
      'Your access needs to be renewed. The local draft is retained; sign in or contact your manager.',
    ),
    '40001' || '23505' => const RepositoryFailure(
      FailureKind.conflict,
      'This assignment changed on the server. Your draft is retained for explicit review.',
    ),
    '22023' || '23514' => const RepositoryFailure(
      FailureKind.invalid,
      'The server could not accept this checklist. Review its version and required answers.',
    ),
    _ => const RepositoryFailure(
      FailureKind.transient,
      'The service could not be reached. Your draft remains on this device.',
    ),
  };
}
