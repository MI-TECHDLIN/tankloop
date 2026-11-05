import 'entities.dart';

enum WorkOrderState {
  proposed,
  approvalPending,
  assigned,
  inProgress,
  completed,
  accepted,
  rework,
}

class WorkOrder {
  WorkOrder._({
    required this.id,
    required this.scope,
    required this.incidentId,
    required this.task,
    required this.state,
    required this.isSimulated,
    required this.history,
    this.assigneeId,
    this.approvedBy,
    this.dueAt,
    this.completionEvidence,
  });
  factory WorkOrder.propose({
    required String id,
    required Scope scope,
    required String incidentId,
    required String task,
    required bool isSimulated,
  }) {
    requireRule(
      hasText(task),
      'task_required',
      'Describe the requested action.',
    );
    return WorkOrder._(
      id: id,
      scope: scope,
      incidentId: incidentId,
      task: task,
      state: WorkOrderState.proposed,
      isSimulated: isSimulated,
      history: const [],
    );
  }
  static const transitions = <WorkOrderState, Set<WorkOrderState>>{
    WorkOrderState.proposed: {WorkOrderState.approvalPending},
    WorkOrderState.approvalPending: {WorkOrderState.assigned},
    WorkOrderState.assigned: {WorkOrderState.inProgress},
    WorkOrderState.inProgress: {WorkOrderState.completed},
    WorkOrderState.completed: {WorkOrderState.accepted, WorkOrderState.rework},
    WorkOrderState.accepted: {},
    WorkOrderState.rework: {WorkOrderState.inProgress},
  };
  final String id;
  final Scope scope;
  final String incidentId;
  final String task;
  final WorkOrderState state;
  final bool isSimulated;
  final List<DomainEvent> history;
  final String? assigneeId;
  final String? approvedBy;
  final DateTime? dueAt;
  final String? completionEvidence;
  int get version => history.length;

  WorkOrder transition(
    WorkOrderState target,
    CommandContext context, {
    String? assignee,
    DateTime? deadline,
    String? evidence,
  }) {
    requireRule(
      transitions[state]!.contains(target),
      'invalid_work_transition',
      'This work-order transition is not allowed.',
    );
    final approval = {
      WorkOrderState.assigned,
      WorkOrderState.accepted,
      WorkOrderState.rework,
    }.contains(target);
    context.authorize(
      scope,
      approval
          ? {Role.manager, Role.admin}
          : {Role.field, Role.manager, Role.admin},
      online: approval,
    );
    if (target == WorkOrderState.assigned) {
      requireRule(
        hasText(assignee) && deadline != null && deadline.isAfter(context.at),
        'assignment_required',
        'An accountable assignee and future deadline are required.',
      );
    }
    if (target == WorkOrderState.inProgress ||
        target == WorkOrderState.completed) {
      requireRule(
        context.actor.id == assigneeId,
        'assignee_required',
        'Only the assigned worker can record this action.',
      );
    }
    if (target == WorkOrderState.completed) {
      requireRule(
        hasText(evidence),
        'completion_evidence',
        'Record completion evidence; this does not resolve the incident.',
      );
    }
    return WorkOrder._(
      id: id,
      scope: scope,
      incidentId: incidentId,
      task: task,
      state: target,
      isSimulated: isSimulated,
      history: recordTransition(
        history: history,
        context: context,
        scope: scope,
        id: id,
        from: wireName(state),
        to: wireName(target),
        isSimulated: isSimulated,
        evidenceIds: [?evidence],
      ),
      assigneeId: assignee ?? assigneeId,
      approvedBy: target == WorkOrderState.assigned
          ? context.actor.id
          : approvedBy,
      dueAt: deadline ?? dueAt,
      completionEvidence:
          target == WorkOrderState.inProgress && state == WorkOrderState.rework
          ? null
          : evidence ?? completionEvidence,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    ...scope.toJson(),
    'incident_id': incidentId,
    'task': task,
    'state': wireName(state),
    'assignee_id': assigneeId,
    'approved_by': approvedBy,
    'due_at': dueAt?.toUtc().toIso8601String(),
    'completion_evidence': completionEvidence,
    'version': version,
    'is_simulated': isSimulated,
  };
}
