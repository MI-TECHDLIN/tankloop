import 'entities.dart';
import 'results.dart';

enum IncidentState {
  reported,
  triaged,
  assigned,
  mitigation,
  verificationPending,
  resolved,
  reopened,
}

enum Priority { routine, urgent, critical }

enum ReopenCause { repeatVerifiedFinding, newEvidence, invalidatedVerification }

class VerificationPlan {
  VerificationPlan({
    required List<String> pointIds,
    required List<String> checklistIds,
    required this.indicator,
    required this.method,
    required this.notBefore,
    this.freshFor = const Duration(days: 30),
  }) : pointIds = List.unmodifiable(pointIds),
       checklistIds = List.unmodifiable(checklistIds) {
    requireRule(
      pointIds.isNotEmpty || checklistIds.isNotEmpty,
      'empty_plan',
      'At least one explicit verification requirement is needed.',
    );
    requireRule(
      hasText(method) && freshFor > Duration.zero,
      'invalid_plan',
      'A method and positive freshness window are required.',
    );
  }
  final List<String> pointIds;
  final List<String> checklistIds;
  final Indicator indicator;
  final String method;
  final DateTime notBefore;
  final Duration freshFor;
}

class ChecklistEvidence {
  const ChecklistEvidence({
    required this.templateId,
    required this.scope,
    required this.completedAt,
    required this.hasOutstandingRisk,
    required this.isSimulated,
  });
  final String templateId;
  final Scope scope;
  final DateTime completedAt;
  final bool hasOutstandingRisk;
  final bool isSimulated;
}

class ClosureEvidence {
  ClosureEvidence({
    required List<ChecklistEvidence> checklists,
    required List<ResultRecord> results,
    required this.communicationRef,
  }) : checklists = List.unmodifiable(checklists),
       results = List.unmodifiable(results);
  final List<ChecklistEvidence> checklists;
  final List<ResultRecord> results;
  final String communicationRef;
}

class IncidentUpdate {
  const IncidentUpdate({
    this.priority,
    this.uncertainty,
    this.ownerId,
    this.dueAt,
    this.requiredResponse,
    this.actionEvidence,
    this.controlsReviewed = false,
    this.noticeReviewed = false,
    this.plan,
    this.closure,
    this.reopenCause,
    this.newEvidenceRef,
    this.repeatResult,
  });
  final Priority? priority;
  final String? uncertainty;
  final String? ownerId;
  final DateTime? dueAt;
  final String? requiredResponse;
  final String? actionEvidence;
  final bool controlsReviewed;
  final bool noticeReviewed;
  final VerificationPlan? plan;
  final ClosureEvidence? closure;
  final ReopenCause? reopenCause;
  final String? newEvidenceRef;
  final ResultRecord? repeatResult;
}

class IncidentRecord {
  IncidentRecord._({
    required this.id,
    required this.scope,
    required this.systemId,
    required this.pointIds,
    required this.source,
    required this.sourceId,
    required this.state,
    required this.reportedAt,
    required this.isSimulated,
    required this.history,
    this.priority,
    this.uncertainty,
    this.ownerId,
    this.dueAt,
    this.requiredResponse,
    this.actionEvidence,
    this.plan,
    this.resolvedAt,
    this.communicationRef,
    this.escalatedAt,
  });
  factory IncidentRecord.report({
    required String id,
    required Scope scope,
    required String systemId,
    required List<String> pointIds,
    required EvidenceSource source,
    required String sourceId,
    required DateTime at,
    required bool isSimulated,
  }) {
    requireRule(
      pointIds.isNotEmpty && hasText(sourceId),
      'source_required',
      'Preserve the trigger source and affected water points.',
    );
    return IncidentRecord._(
      id: id,
      scope: scope,
      systemId: systemId,
      pointIds: List.unmodifiable(pointIds),
      source: source,
      sourceId: sourceId,
      state: IncidentState.reported,
      reportedAt: at.toUtc(),
      isSimulated: isSimulated,
      history: const [],
    );
  }
  static const transitions = <IncidentState, Set<IncidentState>>{
    IncidentState.reported: {IncidentState.triaged},
    IncidentState.triaged: {IncidentState.assigned},
    IncidentState.assigned: {
      IncidentState.mitigation,
      IncidentState.verificationPending,
    },
    IncidentState.mitigation: {IncidentState.verificationPending},
    IncidentState.verificationPending: {
      IncidentState.resolved,
      IncidentState.reopened,
    },
    IncidentState.resolved: {IncidentState.reopened},
    IncidentState.reopened: {IncidentState.triaged},
  };
  final String id;
  final Scope scope;
  final String systemId;
  final List<String> pointIds;
  final EvidenceSource source;
  final String sourceId;
  final IncidentState state;
  final DateTime reportedAt;
  final bool isSimulated;
  final List<DomainEvent> history;
  final Priority? priority;
  final String? uncertainty;
  final String? ownerId;
  final DateTime? dueAt;
  final String? requiredResponse;
  final String? actionEvidence;
  final VerificationPlan? plan;
  final DateTime? resolvedAt;
  final String? communicationRef;
  final DateTime? escalatedAt;
  int get version => history.length;
  bool get isOpen => state != IncidentState.resolved;

  IncidentRecord transition(
    IncidentState target,
    CommandContext context, [
    IncidentUpdate update = const IncidentUpdate(),
  ]) {
    requireRule(
      transitions[state]!.contains(target),
      'invalid_incident_transition',
      'This incident transition is not allowed.',
    );
    context.authorize(scope, {Role.manager, Role.admin});
    requireRule(
      !context.at.isBefore(reportedAt),
      'time_order',
      'An incident event cannot predate the report.',
    );
    switch (target) {
      case IncidentState.triaged:
        requireRule(
          update.priority != null && hasText(update.uncertainty),
          'triage_required',
          'Classify urgency and record uncertainty for the affected scope.',
        );
      case IncidentState.assigned:
        requireRule(
          hasText(update.ownerId) &&
              update.dueAt != null &&
              update.dueAt!.isAfter(context.at) &&
              hasText(update.requiredResponse),
          'owner_required',
          'Record the owner, deadline and required response.',
        );
      case IncidentState.mitigation:
        requireRule(
          hasText(update.actionEvidence),
          'action_required',
          'Record the authorized action reference.',
        );
      case IncidentState.verificationPending:
        final candidate = update.plan;
        requireRule(
          hasText(update.actionEvidence) &&
              update.controlsReviewed &&
              update.noticeReviewed &&
              candidate != null,
          'verification_plan_required',
          'Document actions, review interim controls and public notices, and specify verification requirements.',
        );
        requireRule(
          !candidate!.notBefore.isAfter(context.at) &&
              !candidate.notBefore.isBefore(reportedAt),
          'plan_time',
          'Verification must follow this incident and recorded actions.',
        );
        requireRule(
          source != EvidenceSource.laboratory ||
              candidate.pointIds.toSet().containsAll(pointIds),
          'sample_plan_required',
          'A confirmed finding requires follow-up samples for every affected point.',
        );
      case IncidentState.resolved:
        _validateClosure(context, update.closure);
      case IncidentState.reopened:
        requireRule(
          update.reopenCause != null && hasText(update.newEvidenceRef),
          'reopen_evidence',
          'Record the new evidence or invalidated verification.',
        );
        if (update.reopenCause == ReopenCause.repeatVerifiedFinding) {
          final result = update.repeatResult;
          requireRule(
            result != null &&
                result.isReviewed &&
                result.measurement!.detected &&
                result.sample.scope.matches(scope) &&
                result.isSimulated == isSimulated &&
                pointIds.contains(result.sample.pointId) &&
                !result.reviewedAt!.isBefore(resolvedAt ?? reportedAt),
            'repeat_finding_required',
            'A repeat finding must be a new reviewed result in the affected scope.',
          );
        }
      case IncidentState.reported:
        throw const RuleViolation(
          'invalid_incident_transition',
          'Cannot return to reported.',
        );
    }
    return IncidentRecord._(
      id: id,
      scope: scope,
      systemId: systemId,
      pointIds: pointIds,
      source: source,
      sourceId: sourceId,
      state: target,
      reportedAt: reportedAt,
      isSimulated: isSimulated,
      history: recordTransition(
        history: history,
        context: context,
        scope: scope,
        id: id,
        from: wireName(state),
        to: wireName(target),
        isSimulated: isSimulated,
        evidenceIds: [
          if (update.actionEvidence != null) update.actionEvidence!,
          if (update.newEvidenceRef != null) update.newEvidenceRef!,
          if (update.closure != null) update.closure!.communicationRef,
          ...?update.closure?.results.map((r) => r.id),
        ],
      ),
      priority: update.priority ?? priority,
      uncertainty: update.uncertainty ?? uncertainty,
      ownerId: update.ownerId ?? ownerId,
      dueAt: update.dueAt ?? dueAt,
      requiredResponse: update.requiredResponse ?? requiredResponse,
      actionEvidence: update.actionEvidence ?? actionEvidence,
      plan: update.plan ?? plan,
      resolvedAt: target == IncidentState.resolved ? context.at : resolvedAt,
      communicationRef: update.closure?.communicationRef ?? communicationRef,
      escalatedAt: escalatedAt,
    );
  }

  void _validateClosure(CommandContext context, ClosureEvidence? evidence) {
    requireRule(
      plan != null && evidence != null && hasText(evidence.communicationRef),
      'closure_evidence_required',
      'Fulfil the verification plan and record the authorized communication.',
    );
    final requirements = plan!;
    final submitted = evidence!;
    for (final templateId in requirements.checklistIds) {
      requireRule(
        submitted.checklists.any(
          (c) =>
              c.templateId == templateId &&
              c.scope.matches(scope) &&
              c.isSimulated == isSimulated &&
              !c.hasOutstandingRisk &&
              !c.completedAt.isBefore(requirements.notBefore) &&
              !c.completedAt.isAfter(context.at),
        ),
        'checklist_incomplete',
        'The applicable follow-up checklist is not fulfilled.',
      );
    }
    for (final pointId in requirements.pointIds) {
      requireRule(
        submitted.results.any(
          (r) =>
              r.isReviewed &&
              r.sample.scope.matches(scope) &&
              r.isSimulated == isSimulated &&
              r.sample.pointId == pointId &&
              r.measurement!.indicator == requirements.indicator &&
              r.measurement!.method == requirements.method &&
              !r.measurement!.detected &&
              !r.sample.collectedAt.isBefore(requirements.notBefore) &&
              !r.reviewedAt!.isAfter(context.at) &&
              context.at.difference(r.sample.collectedAt) <=
                  requirements.freshFor,
        ),
        'sample_incomplete',
        'A valid, in-scope, current, independently reviewed follow-up is required at every planned point.',
      );
    }
  }

  IncidentRecord escalate(CommandContext context) {
    context.authorize(scope, {Role.manager, Role.admin});
    requireRule(
      isOpen &&
          (priority == Priority.critical ||
              (dueAt != null && !context.at.isBefore(dueAt!))),
      'escalation_not_due',
      'Escalation requires an active critical issue or an elapsed configured deadline.',
    );
    return IncidentRecord._(
      id: id,
      scope: scope,
      systemId: systemId,
      pointIds: pointIds,
      source: source,
      sourceId: sourceId,
      state: state,
      reportedAt: reportedAt,
      isSimulated: isSimulated,
      history: recordTransition(
        history: history,
        context: context,
        scope: scope,
        id: id,
        from: wireName(state),
        to: 'escalated',
        isSimulated: isSimulated,
      ),
      priority: priority,
      uncertainty: uncertainty,
      ownerId: ownerId,
      dueAt: dueAt,
      requiredResponse: requiredResponse,
      actionEvidence: actionEvidence,
      plan: plan,
      resolvedAt: resolvedAt,
      communicationRef: communicationRef,
      escalatedAt: context.at,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'system_id': systemId,
    'point_ids': pointIds,
    'source': wireName(source),
    'source_id': sourceId,
    'state': wireName(state),
    'reported_at': reportedAt.toIso8601String(),
    'priority': priority?.name,
    'uncertainty': uncertainty,
    'owner_id': ownerId,
    'due_at': dueAt?.toUtc().toIso8601String(),
    'required_response': requiredResponse,
    'action_evidence': actionEvidence,
    'resolved_at': resolvedAt?.toUtc().toIso8601String(),
    'communication_ref': communicationRef,
    'escalated_at': escalatedAt?.toUtc().toIso8601String(),
    'version': version,
    'is_simulated': isSimulated,
  };
}
