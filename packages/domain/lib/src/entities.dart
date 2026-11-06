import 'dart:typed_data';

enum Role { field, manager, lab, admin }

enum EvidenceSource { residentReport, inspection, fieldScreen, laboratory }

enum VerificationStage {
  draft,
  submitted,
  received,
  reviewed,
  rejected,
  superseded,
}

enum OperationalConcern {
  noneRecorded,
  observedRisk,
  openIncident,
  underInvestigation,
  verificationPending,
}

enum Provenance {
  userReported,
  fieldScreened,
  labUploaded,
  independentlyReviewed,
}

enum AssetType { borehole, pump, tank, line, tap }

enum AnswerChoice { yes, no, unknown, notApplicable }

enum Indicator {
  eColi('E. coli'),
  totalColiforms('Total coliforms'),
  hydrogenSulfide('H₂S screening indicator');

  const Indicator(this.label);
  final String label;
}

enum ResultUnit {
  cfuPer100ml('CFU/100 mL'),
  mpnPer100ml('MPN/100 mL'),
  presenceAbsence('presence/absence');

  const ResultUnit(this.label);
  final String label;
}

String wireName(Enum value) => value.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);

T enumFromWire<T extends Enum>(List<T> values, String value) =>
    values.singleWhere((item) => wireName(item) == value);

class RuleViolation implements Exception {
  const RuleViolation(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

void requireRule(bool condition, String code, String message) {
  if (!condition) throw RuleViolation(code, message);
}

bool hasText(String? value) => value != null && value.trim().isNotEmpty;

class Scope {
  const Scope(this.organizationId, this.facilityId);
  final String organizationId;
  final String facilityId;
  bool matches(Scope other) =>
      organizationId == other.organizationId && facilityId == other.facilityId;
  Map<String, Object?> toJson() => {
    'organization_id': organizationId,
    'facility_id': facilityId,
  };
}

class Actor {
  const Actor({
    required this.id,
    required this.role,
    required this.scope,
    this.active = true,
    this.expiresAt,
  });
  final String id;
  final Role role;
  final Scope scope;
  final bool active;
  final DateTime? expiresAt;
}

/// Domain validation is also run by the simulator. The database independently
/// checks auth.uid(), memberships and evidence; client flags never grant access.
class CommandContext {
  CommandContext({
    required this.actor,
    required DateTime at,
    required this.eventId,
    required this.serverConfirmed,
    required this.reason,
  }) : at = at.toUtc();
  final Actor actor;
  final DateTime at;
  final String eventId;
  final bool serverConfirmed;
  final String reason;

  void authorize(Scope scope, Set<Role> roles, {bool online = true}) {
    requireRule(
      actor.active &&
          actor.scope.matches(scope) &&
          roles.contains(actor.role) &&
          (actor.expiresAt == null || at.isBefore(actor.expiresAt!)),
      'permission_denied',
      'An active, scoped, authorized member is required.',
    );
    requireRule(
      !online || serverConfirmed,
      'server_required',
      'This action requires an authoritative server receipt.',
    );
    requireRule(hasText(reason), 'reason_required', 'Record why this changed.');
  }
}

class DomainEvent {
  DomainEvent({
    required this.id,
    required this.scope,
    required this.aggregateId,
    required this.actorId,
    required this.at,
    required this.from,
    required this.to,
    required this.reason,
    required this.isSimulated,
    List<String> evidenceIds = const [],
  }) : evidenceIds = List.unmodifiable(evidenceIds);
  final String id;
  final Scope scope;
  final String aggregateId;
  final String actorId;
  final DateTime at;
  final String from;
  final String to;
  final String reason;
  final bool isSimulated;
  final List<String> evidenceIds;

  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'aggregate_id': aggregateId,
    'actor_id': actorId,
    'occurred_at': at.toUtc().toIso8601String(),
    'previous_state': from,
    'new_state': to,
    'reason': reason,
    'evidence_ids': evidenceIds,
    'is_simulated': isSimulated,
  };
}

List<DomainEvent> recordTransition({
  required List<DomainEvent> history,
  required CommandContext context,
  required Scope scope,
  required String id,
  required String from,
  required String to,
  required bool isSimulated,
  List<String> evidenceIds = const [],
}) {
  requireRule(
    history.isEmpty || !context.at.isBefore(history.last.at),
    'time_order',
    'An event cannot precede the previous event.',
  );
  requireRule(
    !history.any((event) => event.id == context.eventId),
    'duplicate_event',
    'This event has already been applied.',
  );
  return List.unmodifiable([
    ...history,
    DomainEvent(
      id: context.eventId,
      scope: scope,
      aggregateId: id,
      actorId: context.actor.id,
      at: context.at,
      from: from,
      to: to,
      reason: context.reason,
      isSimulated: isSimulated,
      evidenceIds: evidenceIds,
    ),
  ]);
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.isSimulated,
  });
  final String id;
  final String name;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'is_simulated': isSimulated,
  };
}

class Facility {
  const Facility({
    required this.id,
    required this.organizationId,
    required this.label,
    this.timezone = 'Africa/Lagos',
    required this.isSimulated,
  });
  final String id;
  final String organizationId;
  final String label;
  final String timezone;
  final bool isSimulated;
  Scope get scope => Scope(organizationId, id);
  Map<String, Object?> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'public_label': label,
    'timezone': timezone,
    'is_simulated': isSimulated,
  };
}

class WaterSystem {
  const WaterSystem({
    required this.id,
    required this.scope,
    required this.label,
    required this.isSimulated,
  });
  final String id;
  final Scope scope;
  final String label;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'label': label,
    'is_simulated': isSimulated,
  };
}

class Asset {
  const Asset({
    required this.id,
    required this.scope,
    required this.systemId,
    required this.type,
    required this.label,
    required this.isSimulated,
    this.parentId,
    this.capacityLitres,
    this.retiredAt,
  });
  final String id;
  final Scope scope;
  final String systemId;
  final AssetType type;
  final String label;
  final String? parentId;
  final int? capacityLitres;
  final DateTime? retiredAt;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'system_id': systemId,
    'type': type.name,
    'label': label,
    'parent_asset_id': parentId,
    'capacity_litres': capacityLitres,
    'retired_at': retiredAt?.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
  };
}

class SamplingPoint {
  const SamplingPoint({
    required this.id,
    required this.scope,
    required this.assetId,
    required this.label,
    required this.isSimulated,
  });
  final String id;
  final Scope scope;
  final String assetId;
  final String label;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'asset_id': assetId,
    'label': label,
    'is_simulated': isSimulated,
  };
}

class ChecklistQuestion {
  const ChecklistQuestion({
    required this.id,
    required this.label,
    required this.rationale,
    required this.sourceId,
    this.required = true,
  });
  final String id;
  final String label;
  final String rationale;
  final String sourceId;
  final bool required;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'rationale': rationale,
    'source_id': sourceId,
    'required': required,
    'risk_answer': 'yes',
  };
  factory ChecklistQuestion.fromJson(Map<String, dynamic> json) =>
      ChecklistQuestion(
        id: json['id'] as String,
        label: json['label'] as String,
        rationale: json['rationale'] as String,
        sourceId: json['source_id'] as String,
        required: json['required'] as bool? ?? true,
      );
}

class ChecklistTemplate {
  ChecklistTemplate({
    required this.id,
    required this.scope,
    required this.version,
    required this.title,
    required this.source,
    required this.assetType,
    required List<ChecklistQuestion> questions,
    required this.isSimulated,
  }) : questions = List.unmodifiable(questions);
  final String id;
  final Scope scope;
  final int version;
  final String title;
  final String source;
  final AssetType assetType;
  final List<ChecklistQuestion> questions;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'version': version,
    'title': title,
    'source': source,
    'asset_type': assetType.name,
    'questions': questions.map((q) => q.toJson()).toList(),
    'is_simulated': isSimulated,
  };
}

class InspectionAnswer {
  const InspectionAnswer(this.choice, {this.note = ''});
  final AnswerChoice choice;
  final String note;
  Map<String, Object?> toJson() => {'choice': wireName(choice), 'note': note};
  factory InspectionAnswer.fromJson(Map<String, dynamic> json) =>
      InspectionAnswer(
        enumFromWire(AnswerChoice.values, json['choice'] as String),
        note: json['note'] as String? ?? '',
      );
}

class InspectionTask {
  const InspectionTask({
    required this.id,
    required this.scope,
    required this.assetId,
    required this.templateId,
    required this.dueAt,
    required this.isSimulated,
    this.version = 0,
    this.submittedAt,
  });
  final String id;
  final Scope scope;
  final String assetId;
  final String templateId;
  final DateTime dueAt;
  final bool isSimulated;
  final int version;
  final DateTime? submittedAt;
  bool get isSubmitted => submittedAt != null;
  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'asset_id': assetId,
    'template_id': templateId,
    'due_at': dueAt.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
    'version': version,
    'received_at': submittedAt?.toUtc().toIso8601String(),
  };
}

class InspectionEvidence {
  const InspectionEvidence({
    required this.id,
    required this.localPath,
    required this.capturedAt,
    this.uploadedPath,
    this.questionId,
  });
  final String id;
  final String localPath;
  final DateTime capturedAt;
  final String? uploadedPath;
  final String? questionId;

  InspectionEvidence copyWith({String? uploadedPath}) => InspectionEvidence(
    id: id,
    localPath: localPath,
    capturedAt: capturedAt,
    uploadedPath: uploadedPath ?? this.uploadedPath,
    questionId: questionId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'local_path': localPath,
    'captured_at': capturedAt.toUtc().toIso8601String(),
    'uploaded_path': uploadedPath,
    'question_id': questionId,
  };

  factory InspectionEvidence.fromJson(Map<String, dynamic> json) =>
      InspectionEvidence(
        id: json['id'] as String,
        localPath: json['local_path'] as String,
        capturedAt: DateTime.parse(json['captured_at'] as String),
        uploadedPath: json['uploaded_path'] as String?,
        questionId: json['question_id'] as String?,
      );
}

abstract interface class EvidenceUploader {
  Future<String> uploadEvidence(
    InspectionEvidence evidence, {
    Uint8List? bytes,
  });
}

class InspectionSubmission {
  InspectionSubmission({
    required this.clientEventId,
    required this.taskId,
    required this.scope,
    required this.templateId,
    required this.expectedVersion,
    required this.observedAt,
    required Map<String, InspectionAnswer> answers,
    this.notes = '',
    List<InspectionEvidence> evidence = const [],
    required this.isSimulated,
  }) : answers = Map.unmodifiable(answers),
       evidence = List.unmodifiable(evidence);
  final String clientEventId;
  final String taskId;
  final Scope scope;
  final String templateId;
  final int expectedVersion;
  final DateTime observedAt;
  final Map<String, InspectionAnswer> answers;
  final String notes;
  final List<InspectionEvidence> evidence;
  final bool isSimulated;
  bool get hasRisk => answers.values.any((a) => a.choice == AnswerChoice.yes);

  void validate(ChecklistTemplate template) {
    requireRule(
      template.id == templateId && template.scope.matches(scope),
      'template_mismatch',
      'Use the assigned checklist version.',
    );
    requireRule(
      template.questions
          .where((q) => q.required)
          .every((q) => answers.containsKey(q.id)),
      'answers_required',
      'Answer each required item, including Unknown when needed.',
    );
    requireRule(
      answers.keys.every((id) => template.questions.any((q) => q.id == id)),
      'unknown_question',
      'An answer does not belong to this checklist.',
    );
  }

  Map<String, Object?> toJson() => {
    'client_event_id': clientEventId,
    'task_id': taskId,
    ...scope.toJson(),
    'template_id': templateId,
    'expected_version': expectedVersion,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'answers': answers.map((id, answer) => MapEntry(id, answer.toJson())),
    'notes': notes,
    'evidence': evidence.map((item) => item.toJson()).toList(),
    'is_simulated': isSimulated,
  };
  factory InspectionSubmission.fromJson(Map<String, dynamic> json) =>
      InspectionSubmission(
        clientEventId: json['client_event_id'] as String,
        taskId: json['task_id'] as String,
        scope: Scope(
          json['organization_id'] as String,
          json['facility_id'] as String,
        ),
        templateId: json['template_id'] as String,
        expectedVersion: json['expected_version'] as int,
        observedAt: DateTime.parse(json['observed_at'] as String).toUtc(),
        answers: (json['answers'] as Map<String, dynamic>).map(
          (id, a) => MapEntry(
            id,
            InspectionAnswer.fromJson(a as Map<String, dynamic>),
          ),
        ),
        notes: json['notes'] as String? ?? '',
        evidence: (json['evidence'] as List? ?? const [])
            .map(
              (item) =>
                  InspectionEvidence.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        isSimulated: json['is_simulated'] as bool,
      );
}

class CustodyEvent {
  const CustodyEvent({
    required this.id,
    required this.sampleId,
    required this.scope,
    required this.fromActor,
    required this.toActor,
    required this.occurredAt,
    required this.note,
    required this.isSimulated,
  });
  final String id;
  final String sampleId;
  final Scope scope;
  final String fromActor;
  final String toActor;
  final DateTime occurredAt;
  final String note;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    'sample_id': sampleId,
    ...scope.toJson(),
    'from_actor': fromActor,
    'to_actor': toActor,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'note': note,
    'is_simulated': isSimulated,
  };
}
