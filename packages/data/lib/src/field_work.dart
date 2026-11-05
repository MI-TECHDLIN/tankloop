import 'package:tankloop_domain/domain.dart';

class FieldWorkOrder {
  FieldWorkOrder.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      scope = Scope(j['organization_id'] as String, j['facility_id'] as String),
      task = j['task'] as String,
      state = enumFromWire(WorkOrderState.values, j['state'] as String),
      version = j['version'] as int,
      assigneeId = j['assignee_id'] as String?,
      incidentId = j['incident_id'] as String,
      isSimulated = j['is_simulated'] as bool;
  final String id, task, incidentId;
  final Scope scope;
  final WorkOrderState state;
  final int version;
  final String? assigneeId;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'task': task,
    'state': wireName(state),
    'version': version,
    'assignee_id': assigneeId,
    'incident_id': incidentId,
    'is_simulated': isSimulated,
  };
}

class WorkStepCommand {
  WorkStepCommand({
    required this.clientEventId,
    required this.orderId,
    required this.scope,
    required this.expectedVersion,
    required this.target,
    required this.notes,
    required this.observedAt,
    required this.isSimulated,
    List<InspectionEvidence> evidence = const [],
  }) : evidence = List.unmodifiable(evidence);
  final String clientEventId, orderId, notes;
  final Scope scope;
  final int expectedVersion;
  final WorkOrderState target;
  final DateTime observedAt;
  final bool isSimulated;
  final List<InspectionEvidence> evidence;
  String get stepKey => '$orderId:$expectedVersion';
  WorkStepCommand withEvidence(List<InspectionEvidence> files) =>
      WorkStepCommand(
        clientEventId: clientEventId,
        orderId: orderId,
        scope: scope,
        expectedVersion: expectedVersion,
        target: target,
        notes: notes,
        observedAt: observedAt,
        isSimulated: isSimulated,
        evidence: files,
      );
  Map<String, Object?> toJson() => {
    'client_event_id': clientEventId,
    'work_order_id': orderId,
    ...scope.toJson(),
    'expected_version': expectedVersion,
    'target': wireName(target),
    'notes': notes,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
    'evidence': evidence.map((e) => e.toJson()).toList(),
  };
  factory WorkStepCommand.fromJson(Map<String, dynamic> j) => WorkStepCommand(
    clientEventId: j['client_event_id'] as String,
    orderId: j['work_order_id'] as String,
    scope: Scope(j['organization_id'] as String, j['facility_id'] as String),
    expectedVersion: j['expected_version'] as int,
    target: enumFromWire(WorkOrderState.values, j['target'] as String),
    notes: j['notes'] as String,
    observedAt: DateTime.parse(j['observed_at'] as String),
    isSimulated: j['is_simulated'] as bool,
    evidence: (j['evidence'] as List)
        .map((e) => InspectionEvidence.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class WorkStepReceipt {
  const WorkStepReceipt({
    required this.clientEventId,
    required this.orderId,
    required this.version,
    required this.receivedAt,
  });
  final String clientEventId, orderId;
  final int version;
  final DateTime receivedAt;
  Map<String, Object?> toJson() => {
    'client_event_id': clientEventId,
    'work_order_id': orderId,
    'version': version,
    'received_at': receivedAt.toUtc().toIso8601String(),
  };
  factory WorkStepReceipt.fromJson(Map<String, dynamic> j) => WorkStepReceipt(
    clientEventId: j['client_event_id'] as String,
    orderId: j['work_order_id'] as String,
    version: j['version'] as int,
    receivedAt: DateTime.parse(j['received_at'] as String),
  );
}

abstract interface class FieldWorkRepository {
  Future<WorkStepReceipt> submitWorkStep(WorkStepCommand command);
}
