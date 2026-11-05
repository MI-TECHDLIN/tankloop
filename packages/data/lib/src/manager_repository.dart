import 'package:tankloop_domain/domain.dart';
import 'manager_models.dart';
import 'repository.dart';

abstract interface class ManagerWorkspaceRepository {
  bool get serverBacked;
  Future<ManagerWorkspace> load({String? facilityId});
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
  Future<int> publishResult({
    required String id,
    required int expectedVersion,
    required String reason,
  });
  Future<void> revokeQr({required String token, required String reason});
}

class ManagerConnectionFailure extends RepositoryFailure {
  const ManagerConnectionFailure()
    : super(
        FailureKind.transient,
        'The manager service could not be reached. Reconnect and refresh.',
      );
}

/// A scoped manager exercise over the same event engine used by Field and Lab.
/// Every local action remains simulated and runs the actual domain guards.
class SimulationManagerRepository implements ManagerWorkspaceRepository {
  SimulationManagerRepository({
    SimulationEngine? engine,
    int seed = 20261101,
    int day = 10,
    DateTime Function()? clock,
  }) : engine =
           engine ??
           (SimulationEngine(seed: seed)..advance(Duration(days: day))),
       clock = clock ?? DateTime.now;
  final SimulationEngine engine;
  final DateTime Function() clock;
  String? _facilityId;
  @override
  bool get serverBacked => false;

  bool _active(Actor actor) =>
      actor.active &&
      (actor.expiresAt == null || clock().toUtc().isBefore(actor.expiresAt!));

  Actor _actor(Scope scope) {
    final actor = engine.actors
        .where(
          (a) =>
              a.scope.matches(scope) &&
              {Role.manager, Role.admin}.contains(a.role) &&
              _active(a),
        )
        .firstOrNull;
    if (actor == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Active manager access is required for this facility.',
      );
    }
    return actor;
  }

  @override
  Future<ManagerWorkspace> load({String? facilityId}) async {
    final requested = facilityId ?? _facilityId ?? engine.facilities.first.id;
    final facility = engine.facilities
        .where((f) => f.id == requested)
        .firstOrNull;
    if (facility == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Facility unavailable.',
      );
    }
    final actor = _actor(facility.scope);
    _facilityId = facility.id;
    final scope = facility.scope;
    const preservation = 'Simulation playback: no physical transport record.';
    final records = [
      for (final result in engine.results.values.where(
        (r) => r.sample.scope.matches(scope),
      ))
        {
          ...result.toJson(),
          'sample': {
            ...result.sample.toJson(),
            'preservation_note': preservation,
          },
          'point_label': engine.points
              .singleWhere((p) => p.id == result.sample.pointId)
              .label,
          'open_incident_count': engine.incidents.values
              .where(
                (i) =>
                    i.scope.matches(scope) &&
                    i.isOpen &&
                    i.pointIds.contains(result.sample.pointId),
              )
              .length,
          'custody': engine.custody
              .where((c) => c.sampleId == result.sample.id)
              .map((c) => c.toJson())
              .toList(),
          'audit': result.history.map((a) => a.toJson()).toList(),
        },
    ];
    return ManagerWorkspace.fromJson({
      'facility': facility.toJson(),
      'facilities': engine.facilities
          .where(
            (f) => engine.actors.any(
              (a) =>
                  a.scope.matches(f.scope) &&
                  {Role.manager, Role.admin}.contains(a.role) &&
                  _active(a),
            ),
          )
          .map((f) => f.toJson())
          .toList(),
      'actor_id': actor.id,
      'as_of': engine.now.toIso8601String(),
      'fetched_at': clock().toUtc().toIso8601String(),
      'simulation': {'simulation_seed': engine.seed, 'model_version': 1},
      'systems': engine.systems
          .where((s) => s.scope.matches(scope))
          .map((s) => s.toJson())
          .toList(),
      'assets': engine.assets
          .where((a) => a.scope.matches(scope))
          .map((a) => a.toJson())
          .toList(),
      'points': engine.points
          .where((p) => p.scope.matches(scope))
          .map((p) => p.toJson())
          .toList(),
      'templates': engine.templates
          .where((t) => t.scope.matches(scope))
          .map((t) => t.toJson())
          .toList(),
      'inspections':
          [
            for (final task in engine.inspections.values.where(
              (t) => t.scope.matches(scope),
            ))
              {
                ...task.toJson(),
                'assigned_to': engine.actorFor(scope, Role.field).id,
                'submitted_by': task.isSubmitted
                    ? engine.actorFor(scope, Role.field).id
                    : null,
                'observed_at': engine.submissions[task.id]?.observedAt
                    .toIso8601String(),
                'answers':
                    engine.submissions[task.id]?.answers.map(
                      (id, answer) => MapEntry(id, answer.toJson()),
                    ) ??
                    <String, Object?>{},
                'notes': engine.submissions[task.id]?.notes ?? '',
              },
          ]..sort(
            (a, b) => (a['due_at'] as String).compareTo(b['due_at'] as String),
          ),
      'samples':
          [
            for (final sample in engine.samples.values.where(
              (s) => s.scope.matches(scope),
            ))
              {
                ...sample.toJson(),
                'preservation_note': preservation,
                'custody': engine.custody
                    .where((c) => c.sampleId == sample.id)
                    .map((c) => c.toJson())
                    .toList(),
              },
          ]..sort(
            (a, b) => (b['collected_at'] as String).compareTo(
              a['collected_at'] as String,
            ),
          ),
      'records': records,
      'incidents': engine.incidents.values
          .where((i) => i.scope.matches(scope))
          .map(
            (i) => {
              ...i.toJson(),
              'requirements': [
                if (i.plan case final plan?) ...[
                  for (final pointId in plan.pointIds)
                    {
                      'kind': 'sample',
                      'point_id': pointId,
                      'indicator': wireName(plan.indicator),
                      'method': plan.method,
                      'not_before': plan.notBefore.toIso8601String(),
                      'fresh_for': '${plan.freshFor.inHours} hours',
                    },
                  for (final templateId in plan.checklistIds)
                    {
                      'kind': 'checklist',
                      'template_id': templateId,
                      'not_before': plan.notBefore.toIso8601String(),
                      'fresh_for': '${plan.freshFor.inHours} hours',
                    },
                ],
              ],
            },
          )
          .toList(),
      'work_orders': engine.workOrders.values
          .where((w) => w.scope.matches(scope))
          .map((w) => w.toJson())
          .toList(),
      'memberships': [
        for (final member in engine.actors.where((a) => a.scope.matches(scope)))
          {
            'id': 'simulation-membership-${member.id}',
            'user_id': member.id,
            ...member.scope.toJson(),
            'role': member.role.name,
            'status': member.active ? 'active' : 'revoked',
            'valid_until': member.expiresAt?.toIso8601String(),
          },
      ],
      'qrs': engine.qrs
          .where((q) => q.scope.matches(scope))
          .map((q) => q.toJson())
          .toList(),
      'audit': engine.auditEvents
          .where((a) => a.scope.matches(scope))
          .map((a) => a.toJson())
          .toList(),
    });
  }

  CommandContext _context(Scope scope, String reason) {
    if (scope.facilityId != (_facilityId ?? engine.facilities.first.id)) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Select this facility before acting.',
      );
    }
    final actor = _actor(scope);
    requireRule(hasText(reason), 'reason_required', 'Record why this changed.');
    return CommandContext(
      // Membership expiry uses the real clock above, not the exercise clock.
      actor: Actor(id: actor.id, role: actor.role, scope: actor.scope),
      at: engine.now,
      eventId: 'simulation-manager-${engine.seed}-${engine.auditEvents.length}',
      serverConfirmed: true,
      reason: 'Simulated: $reason',
    );
  }

  T _guard<T>(T Function() action) {
    try {
      return action();
    } on RuleViolation catch (error) {
      throw RepositoryFailure(
        error.code == 'permission_denied'
            ? FailureKind.permission
            : FailureKind.invalid,
        error.message,
      );
    }
  }

  void _version(int? actual, int expected) {
    if (actual == null || actual != expected) {
      throw const RepositoryFailure(
        FailureKind.conflict,
        'This record changed. Refresh and review before acting.',
      );
    }
  }

  @override
  Future<int> transitionIncident({
    required String id,
    required IncidentState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) async => _guard(() {
    final incident = engine.incidents[id];
    _version(incident?.version, expectedVersion);
    final owner = payload['owner_id'] as String?;
    if (target == IncidentState.assigned) {
      requireRule(
        engine.actors.any(
          (a) =>
              a.id == owner && a.scope.matches(incident!.scope) && _active(a),
        ),
        'owner_required',
        'Choose an active scoped owner.',
      );
    }
    final context = _context(incident!.scope, reason);
    VerificationPlan? plan;
    String? actionEvidence;
    if (target == IncidentState.mitigation ||
        target == IncidentState.verificationPending) {
      final orders =
          engine.workOrders.values
              .where(
                (w) =>
                    w.incidentId == id &&
                    w.scope.matches(incident.scope) &&
                    w.approvedBy != null &&
                    (target == IncidentState.verificationPending
                        ? w.state == WorkOrderState.accepted
                        : {
                            WorkOrderState.assigned,
                            WorkOrderState.inProgress,
                            WorkOrderState.completed,
                            WorkOrderState.accepted,
                            WorkOrderState.rework,
                          }.contains(w.state)),
              )
              .toList()
            ..sort((a, b) => b.dueAt!.compareTo(a.dueAt!));
      requireRule(
        orders.isNotEmpty,
        'authorized_work_required',
        target == IncidentState.verificationPending
            ? 'Accepted work is required before verification.'
            : 'Approved work is required before recording an interim measure.',
      );
      actionEvidence = orders.first.id;
      if (target == IncidentState.verificationPending) {
        requireRule(
          hasText(payload['notice_ref'] as String?),
          'notice_required',
          'Record the reviewed public notice reference.',
        );
        plan = _verificationPlan(incident, payload);
      }
    }
    final updated = incident.transition(
      target,
      context,
      IncidentUpdate(
        priority: payload['priority'] == null
            ? null
            : Priority.values.byName(payload['priority'] as String),
        uncertainty: payload['uncertainty'] as String?,
        ownerId: owner,
        dueAt: payload['due_at'] == null
            ? null
            : DateTime.parse(payload['due_at'] as String),
        requiredResponse: payload['required_response'] as String?,
        actionEvidence: actionEvidence,
        controlsReviewed: payload['controls_reviewed'] == true,
        noticeReviewed: payload['notice_reviewed'] == true,
        plan: plan,
      ),
    );
    engine.incidents[id] = updated;
    return updated.version;
  });

  VerificationPlan _verificationPlan(
    IncidentRecord incident,
    Map<String, Object?> payload,
  ) {
    final requirements =
        (payload['requirements'] as List?)?.cast<Map<String, Object?>>() ?? [];
    requireRule(
      requirements.isNotEmpty,
      'verification_plan_required',
      'Specify follow-up requirements.',
    );
    for (final requirement in requirements) {
      requireRule(
        requirement['kind'] == 'sample'
            ? engine.points.any(
                    (p) =>
                        p.id == requirement['point_id'] &&
                        p.scope.matches(incident.scope),
                  ) &&
                  hasText(requirement['method'] as String?) &&
                  Indicator.values.any(
                    (i) => wireName(i) == requirement['indicator'],
                  )
            : requirement['kind'] == 'checklist' &&
                  engine.templates.any(
                    (t) =>
                        t.id == requirement['template_id'] &&
                        t.scope.matches(incident.scope),
                  ),
        'invalid_plan',
        'Use in-scope points and checklists with a recorded method.',
      );
    }
    final samples = requirements.where((r) => r['kind'] == 'sample').toList();
    final original = engine.results[incident.sourceId]?.measurement;
    if (incident.source == EvidenceSource.laboratory) {
      requireRule(
        original != null &&
            incident.pointIds.every(
              (id) => samples.any(
                (r) =>
                    r['point_id'] == id &&
                    r['indicator'] == wireName(original.indicator) &&
                    r['method'] == original.method,
              ),
            ),
        'sample_plan_required',
        'Follow-up must cover each affected point with the original indicator and method.',
      );
    }
    final indicator = samples.isEmpty
        ? Indicator.eColi
        : enumFromWire(Indicator.values, samples.first['indicator'] as String);
    final method = samples.isEmpty
        ? 'Checklist verification'
        : samples.first['method'] as String;
    requireRule(
      samples.every(
        (r) => r['indicator'] == wireName(indicator) && r['method'] == method,
      ),
      'invalid_plan',
      'Use one indicator and method per simulated verification plan.',
    );
    return VerificationPlan(
      pointIds: samples.map((r) => r['point_id'] as String).toList(),
      checklistIds: requirements
          .where((r) => r['kind'] == 'checklist')
          .map((r) => r['template_id'] as String)
          .toList(),
      indicator: indicator,
      method: method,
      notBefore: engine.now,
    );
  }

  @override
  Future<int> transitionWorkOrder({
    required String id,
    required WorkOrderState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) async => _guard(() {
    final order = engine.workOrders[id];
    _version(order?.version, expectedVersion);
    final assignee = payload['assignee_id'] as String?;
    if (target == WorkOrderState.assigned) {
      requireRule(
        engine.actors.any(
          (a) =>
              a.id == assignee &&
              a.scope.matches(order!.scope) &&
              a.role == Role.field &&
              _active(a),
        ),
        'assignment_required',
        'Choose an active scoped field responder.',
      );
    }
    final updated = order!.transition(
      target,
      _context(order.scope, reason),
      assignee: assignee,
      deadline: payload['due_at'] == null
          ? null
          : DateTime.parse(payload['due_at'] as String),
    );
    engine.workOrders[id] = updated;
    return updated.version;
  });

  @override
  Future<int> escalateIncident({
    required String id,
    required int expectedVersion,
    required String reason,
  }) async => _guard(() {
    final incident = engine.incidents[id];
    _version(incident?.version, expectedVersion);
    final updated = incident!.escalate(_context(incident.scope, reason));
    engine.incidents[id] = updated;
    return updated.version;
  });

  @override
  Future<int> publishResult({
    required String id,
    required int expectedVersion,
    required String reason,
  }) async => _guard(() {
    final result = engine.results[id];
    _version(result?.version, expectedVersion);
    final updated = result!.transition(
      ResultState.published,
      _context(result.sample.scope, reason),
    );
    engine.results[id] = updated;
    return updated.version;
  });

  @override
  Future<void> revokeQr({
    required String token,
    required String reason,
  }) async => _guard(() {
    final index = engine.qrs.indexWhere((q) => q.token == token);
    if (index < 0) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'QR identity unavailable.',
      );
    }
    final qr = engine.qrs[index];
    final context = _context(qr.scope, reason);
    if (qr.revokedAt == null) engine.qrs[index] = qr.revoke(context);
  });
}
