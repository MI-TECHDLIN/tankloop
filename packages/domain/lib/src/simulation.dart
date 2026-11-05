import 'entities.dart';
import 'incidents.dart';
import 'public_record.dart';
import 'results.dart';
import 'work_orders.dart';

/// A portable LCG: unlike platform Random implementations, this stream is part
/// of the simulation contract and is identical in Dart VM and JavaScript.
class SeededRandom {
  SeededRandom(int seed) : _state = seed % 4294967296;
  int _state;
  double nextDouble() {
    _state = (1664525 * _state + 1013904223) % 4294967296;
    return _state / 4294967296;
  }

  int nextInt(int max) => (nextDouble() * max).floor();
  String uuid() {
    final bytes = List.generate(16, (_) => nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  String token() => List.generate(
    24,
    (_) => nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class _Scheduled {
  const _Scheduled(this.at, this.sequence, this.run);
  final DateTime at;
  final int sequence;
  final void Function() run;
}

/// Discrete-event simulation. All observations are explicitly synthetic.
/// Probability parameters describe a demo workload, never local prevalence.
class SimulationEngine {
  SimulationEngine({
    this.seed = 20261101,
    DateTime? startsAt,
    int organizationCount = 2,
    int facilitiesPerOrganization = 2,
  }) : startsAt = (startsAt ?? DateTime.utc(2026, 11, 1, 6)).toUtc(),
       _random = SeededRandom(seed) {
    requireRule(
      organizationCount > 0 &&
          facilitiesPerOrganization > 0 &&
          organizationCount * facilitiesPerOrganization <= 100,
      'simulation_size',
      'Choose between 1 and 100 facilities.',
    );
    now = this.startsAt;
    for (var o = 0; o < organizationCount; o++) {
      final organization = Organization(
        id: _random.uuid(),
        name:
            '${['Aster', 'Canopy', 'Harbour', 'Willow'][o % 4]} ${o.isEven ? 'Learning Cooperative' : 'Housing Collective'} ${o + 1}',
        isSimulated: true,
      );
      organizations.add(organization);
      for (var f = 0; f < facilitiesPerOrganization; f++) {
        _buildFacility(organization, f);
      }
    }
  }
  final int seed;
  final DateTime startsAt;
  final SeededRandom _random;
  late DateTime now;
  int _sequence = 0;
  final _schedule = <_Scheduled>[];
  final organizations = <Organization>[];
  final facilities = <Facility>[];
  final systems = <WaterSystem>[];
  final assets = <Asset>[];
  final points = <SamplingPoint>[];
  final templates = <ChecklistTemplate>[];
  final actors = <Actor>[];
  final qrs = <PublicQr>[];
  final inspections = <String, InspectionTask>{};
  final submissions = <String, InspectionSubmission>{};
  final samples = <String, SampleRecord>{};
  final results = <String, ResultRecord>{};
  final incidents = <String, IncidentRecord>{};
  final workOrders = <String, WorkOrder>{};
  final custody = <CustodyEvent>[];
  final observationEvents = <DomainEvent>[];
  final _receipts = <String, String>{};

  void managerAdvanceIncident(String incidentId, IncidentState target) {
    final incident = incidents[incidentId];
    requireRule(
      incident != null,
      'incident_not_found',
      'Incident was not found.',
    );
    final current = incident!;
    final context = _context(
      current.scope,
      Role.manager,
      'Manager workspace action: ${wireName(target)}.',
    );
    final update = switch (target) {
      IncidentState.triaged => IncidentUpdate(
        priority: current.priority ?? Priority.urgent,
        uncertainty:
            current.uncertainty ??
            'Scope is being confirmed from available evidence.',
      ),
      IncidentState.assigned => IncidentUpdate(
        ownerId: actorFor(current.scope, Role.field).id,
        dueAt: now.add(const Duration(days: 3)),
        requiredResponse: 'Inspect the affected asset and record evidence.',
      ),
      IncidentState.mitigation => IncidentUpdate(
        actionEvidence: 'simulation://incident/$incidentId/interim-measure',
      ),
      IncidentState.verificationPending => IncidentUpdate(
        actionEvidence:
            current.actionEvidence ??
            'simulation://incident/$incidentId/interim-measure',
        controlsReviewed: true,
        noticeReviewed: true,
        plan: VerificationPlan(
          pointIds: current.pointIds,
          checklistIds: const [],
          indicator: Indicator.eColi,
          method: 'Membrane filtration (simulation)',
          notBefore: now,
        ),
      ),
      _ => const IncidentUpdate(),
    };
    incidents[incidentId] = current.transition(target, context, update);
  }

  void managerAdvanceWorkOrder(String workOrderId, WorkOrderState target) {
    final order = workOrders[workOrderId];
    requireRule(
      order != null,
      'work_order_not_found',
      'Work order was not found.',
    );
    final current = order!;
    final context = _context(
      current.scope,
      Role.manager,
      'Manager workspace action: ${wireName(target)}.',
    );
    workOrders[workOrderId] = current.transition(
      target,
      context,
      assignee: target == WorkOrderState.assigned
          ? actorFor(current.scope, Role.field).id
          : null,
      deadline: target == WorkOrderState.assigned
          ? now.add(const Duration(days: 3))
          : null,
    );
  }

  List<DomainEvent> get auditEvents =>
      [
        ...observationEvents,
        ...results.values.expand((r) => r.history),
        ...incidents.values.expand((i) => i.history),
        ...workOrders.values.expand((w) => w.history),
        ...qrs.expand((q) => q.history),
      ]..sort((a, b) {
        final order = a.at.compareTo(b.at);
        return order != 0 ? order : a.id.compareTo(b.id);
      });

  Actor actorFor(Scope scope, Role role) =>
      actors.singleWhere((a) => a.scope.matches(scope) && a.role == role);
  CommandContext _context(Scope scope, Role role, String reason) =>
      CommandContext(
        actor: actorFor(scope, role),
        at: now,
        eventId: _random.uuid(),
        serverConfirmed: true,
        reason: 'Simulated: $reason',
      );
  void _at(DateTime at, void Function() action) =>
      _schedule.add(_Scheduled(at, _sequence++, action));
  void advance(Duration by) => advanceTo(now.add(by));
  void advanceTo(DateTime target) {
    target = target.toUtc();
    requireRule(
      !target.isBefore(now),
      'clock_rewind',
      'Reset with the same seed to replay; the clock only moves forward.',
    );
    while (_schedule.isNotEmpty) {
      _schedule.sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        return byTime != 0 ? byTime : a.sequence.compareTo(b.sequence);
      });
      if (_schedule.first.at.isAfter(target)) break;
      final event = _schedule.removeAt(0);
      now = event.at;
      event.run();
    }
    now = target;
  }

  void _buildFacility(Organization organization, int index) {
    final facility = Facility(
      id: _random.uuid(),
      organizationId: organization.id,
      label:
          '${['Cedar', 'Juniper', 'Palm', 'Acacia'][_random.nextInt(4)]} ${index.isEven ? 'Court' : 'Residence'} ${index + 1}',
      isSimulated: true,
    );
    facilities.add(facility);
    for (final role in [Role.field, Role.manager, Role.lab]) {
      actors.add(Actor(id: _random.uuid(), role: role, scope: facility.scope));
    }
    final system = WaterSystem(
      id: _random.uuid(),
      scope: facility.scope,
      label: 'Borehole to courtyard tap',
      isSimulated: true,
    );
    systems.add(system);
    String? parent;
    for (final type in AssetType.values) {
      final asset = Asset(
        id: _random.uuid(),
        scope: facility.scope,
        systemId: system.id,
        type: type,
        label: switch (type) {
          AssetType.borehole => 'Borehole source',
          AssetType.pump => 'Transfer pump',
          AssetType.tank => 'Overhead tank',
          AssetType.line => 'Distribution line',
          AssetType.tap => 'Courtyard tap',
        },
        parentId: parent,
        capacityLitres: type == AssetType.tank
            ? [5000, 7500, 10000][_random.nextInt(3)]
            : null,
        isSimulated: true,
      );
      assets.add(asset);
      parent = asset.id;
      if ({AssetType.borehole, AssetType.tank, AssetType.tap}.contains(type)) {
        final point = SamplingPoint(
          id: _random.uuid(),
          scope: facility.scope,
          assetId: asset.id,
          label: type == AssetType.tank ? 'Tank outlet' : asset.label,
          isSimulated: true,
        );
        points.add(point);
        qrs.add(
          PublicQr.issue(
            token: _random.token(),
            pointId: point.id,
            scope: point.scope,
            at: now,
            isSimulated: true,
          ),
        );
        _scheduleRoutineSample(
          point,
          startsAt.add(Duration(hours: 12 + _random.nextInt(72))),
        );
      }
      if (type == AssetType.tank) {
        final template = ChecklistTemplate(
          id: _random.uuid(),
          scope: facility.scope,
          version: 1,
          title: 'Storage tank walk-through',
          source:
              'TankLoop simulation template v1. Design example informed by the WHO sanitary-inspection approach; not an approved WHO form.',
          assetType: type,
          isSimulated: true,
          questions: const [
            ChecklistQuestion(
              id: 'lid',
              label: 'Is the tank cover missing or unsecured?',
              rationale:
                  'Record the visible condition of the cover. An observation is not a test result.',
              sourceId: 'TL-SIM-TANK-01',
            ),
            ChecklistQuestion(
              id: 'leaks',
              label: 'Are leaks or damaged fittings visible?',
              rationale:
                  'Note where the observed damage is located for manager review.',
              sourceId: 'TL-SIM-TANK-02',
            ),
            ChecklistQuestion(
              id: 'access',
              label: 'Is the access area exposed to an observed risk?',
              rationale:
                  'Describe only what you observe. Use Unknown if you cannot inspect it.',
              sourceId: 'TL-SIM-TANK-03',
            ),
          ],
        );
        templates.add(template);
        _scheduleInspection(
          asset,
          template,
          startsAt.add(Duration(days: 1, hours: _random.nextInt(3))),
        );
      }
    }
  }

  void _scheduleInspection(
    Asset asset,
    ChecklistTemplate template,
    DateTime dueAt,
  ) {
    final task = InspectionTask(
      id: _random.uuid(),
      scope: asset.scope,
      assetId: asset.id,
      templateId: template.id,
      dueAt: dueAt,
      isSimulated: true,
    );
    inspections[task.id] = task;
    _at(dueAt, () {
      _scheduleInspection(asset, template, dueAt.add(const Duration(days: 3)));
      // Keep a realistic backlog for the field member rather than auto-clearing
      // every assignment. About 65% are completed by synthetic colleagues.
      if (_random.nextDouble() < .65) {
        _at(dueAt.add(Duration(hours: 1 + _random.nextInt(6))), () {
          if (inspections[task.id]!.isSubmitted) return;
          submitInspection(
            InspectionSubmission(
              clientEventId: _random.uuid(),
              taskId: task.id,
              scope: task.scope,
              templateId: template.id,
              expectedVersion: 0,
              observedAt: now,
              answers: {
                for (final question in template.questions)
                  question.id: InspectionAnswer(
                    _random.nextDouble() < .05
                        ? AnswerChoice.yes
                        : AnswerChoice.no,
                  ),
              },
              notes: 'Simulated scheduled walk-through.',
              isSimulated: true,
            ),
          );
        });
      }
    });
  }

  void _scheduleRoutineSample(SamplingPoint point, DateTime at) {
    _at(at, () {
      _collect(point);
      _scheduleRoutineSample(
        point,
        now.add(
          Duration(days: 7 + _random.nextInt(4), hours: _random.nextInt(5)),
        ),
      );
    });
  }

  void _collect(SamplingPoint point, {String? verificationFor}) {
    final sample = SampleRecord(
      id: _random.uuid(),
      code: 'SIM-${samples.length.toString().padLeft(5, '0')}',
      scope: point.scope,
      pointId: point.id,
      collectorId: actorFor(point.scope, Role.field).id,
      collectedAt: now,
      intendedMethod: 'Membrane filtration (simulation)',
      isSimulated: true,
    );
    samples[sample.id] = sample;
    final resultId = _random.uuid();
    results[resultId] = ResultRecord.collected(id: resultId, sample: sample);
    final received = now.add(Duration(minutes: 90 + _random.nextInt(150)));
    final tested = received.add(Duration(hours: 18 + _random.nextInt(13)));
    final reviewed = tested.add(Duration(hours: 2 + _random.nextInt(6)));
    final rejected = _random.nextDouble() < .06;
    final assetType = assets.singleWhere((a) => a.id == point.assetId).type;
    final positiveChance = verificationFor != null
        ? .16
        : assetType == AssetType.borehole
        ? .16
        : .30;
    final positive = _random.nextDouble() < positiveChance;
    // Zero-inflated, right-skewed counts. This is a workload model, not measured prevalence.
    var value = 0.0;
    if (positive) {
      value = 1;
      while (_random.nextDouble() < .62 && value < 128) {
        value *= 2;
      }
      value += _random.nextInt(3);
    }
    _at(received, () {
      results[resultId] = results[resultId]!.transition(
        ResultState.received,
        _context(point.scope, Role.lab, 'Sealed sample received.'),
      );
      custody.add(
        CustodyEvent(
          id: _random.uuid(),
          sampleId: sample.id,
          scope: point.scope,
          fromActor: sample.collectorId,
          toActor: actorFor(point.scope, Role.lab).id,
          occurredAt: now,
          note: 'Simulated sealed handoff; transport record retained.',
          isSimulated: true,
        ),
      );
    });
    _at(received.add(const Duration(minutes: 20)), () {
      results[resultId] = results[resultId]!.transition(
        rejected ? ResultState.rejected : ResultState.valid,
        _context(point.scope, Role.lab, 'Sample intake validity review.'),
        rejection: rejected
            ? 'Simulated transport holding-time deviation.'
            : null,
      );
      if (rejected && verificationFor != null) {
        _at(
          now.add(const Duration(days: 1)),
          () => _collect(point, verificationFor: verificationFor),
        );
      }
    });
    if (rejected) return;
    _at(
      tested,
      () => results[resultId] = results[resultId]!.transition(
        ResultState.tested,
        _context(point.scope, Role.lab, 'Synthetic method result entered.'),
        reading: Measurement(
          indicator: Indicator.eColi,
          method: sample.intendedMethod,
          value: value,
          unit: ResultUnit.cfuPer100ml,
          detectionLimit: 1,
        ),
      ),
    );
    _at(reviewed, () {
      results[resultId] = results[resultId]!.transition(
        ResultState.reviewed,
        _context(
          point.scope,
          Role.lab,
          'Synthetic laboratory reviewer attestation.',
        ),
        linkedReport: 'simulation://reports/$resultId',
      );
      if (!positive) return;
      IncidentRecord? prior = verificationFor == null
          ? incidents.values
                .where(
                  (i) =>
                      i.scope.matches(point.scope) &&
                      i.pointIds.contains(point.id) &&
                      !i.isOpen,
                )
                .lastOrNull
          : incidents[verificationFor];
      if (prior != null &&
          {
            IncidentState.resolved,
            IncidentState.verificationPending,
          }.contains(prior.state)) {
        incidents[prior.id] = prior.transition(
          IncidentState.reopened,
          _context(
            point.scope,
            Role.manager,
            'Repeat reviewed finding; retain earlier actions.',
          ),
          IncidentUpdate(
            reopenCause: ReopenCause.repeatVerifiedFinding,
            newEvidenceRef: resultId,
            repeatResult: results[resultId],
          ),
        );
        _respond(prior.id);
      } else {
        _openIncident(point, EvidenceSource.laboratory, resultId);
      }
    });
    _at(reviewed.add(const Duration(hours: 1)), () {
      results[resultId] = results[resultId]!.transition(
        ResultState.published,
        _context(
          point.scope,
          Role.manager,
          'Publish a dated, limited synthetic record.',
        ),
      );
      if (verificationFor == null || positive) return;
      final incident = incidents[verificationFor]!;
      if (incident.state != IncidentState.verificationPending) return;
      final evidence = ClosureEvidence(
        checklists: inspections.values
            .where(
              (task) =>
                  task.scope.matches(incident.scope) &&
                  task.isSubmitted &&
                  !task.submittedAt!.isBefore(incident.plan!.notBefore),
            )
            .map(
              (task) => ChecklistEvidence(
                templateId: task.templateId,
                scope: task.scope,
                completedAt: task.submittedAt!,
                hasOutstandingRisk: submissions[task.id]!.hasRisk,
                isSimulated: true,
              ),
            )
            .toList(),
        results: [results[resultId]!],
        communicationRef:
            'simulation://notices/${incident.id}/${results[resultId]!.id}',
      );
      incidents[incident.id] = incident.transition(
        IncidentState.resolved,
        _context(
          point.scope,
          Role.manager,
          'Follow-up plan met and resident communication recorded.',
        ),
        IncidentUpdate(closure: evidence),
      );
    });
  }

  void _openIncident(
    SamplingPoint point,
    EvidenceSource source,
    String sourceId,
  ) {
    if (incidents.values.any((i) => i.sourceId == sourceId)) return;
    final incident = IncidentRecord.report(
      id: _random.uuid(),
      scope: point.scope,
      systemId: assets.singleWhere((a) => a.id == point.assetId).systemId,
      pointIds: [point.id],
      source: source,
      sourceId: sourceId,
      at: now,
      isSimulated: true,
    );
    incidents[incident.id] = incident;
    observationEvents.add(
      DomainEvent(
        id: _random.uuid(),
        scope: point.scope,
        aggregateId: incident.id,
        actorId: actorFor(
          point.scope,
          source == EvidenceSource.laboratory ? Role.lab : Role.field,
        ).id,
        at: now,
        from: 'none',
        to: 'reported',
        reason: 'Simulated ${wireName(source)} trigger.',
        isSimulated: true,
        evidenceIds: [sourceId],
      ),
    );
    _respond(incident.id);
  }

  void _respond(String incidentId) {
    final incident = incidents[incidentId]!;
    final scope = incident.scope;
    final worker = actorFor(scope, Role.field).id;
    final base = now;
    final completeAt = base.add(Duration(hours: 36 + _random.nextInt(25)));
    final acceptedAt = completeAt.add(const Duration(hours: 2));
    String? workId;
    _at(
      base.add(const Duration(hours: 2)),
      () => incidents[incidentId] = incidents[incidentId]!.transition(
        IncidentState.triaged,
        _context(scope, Role.manager, 'Classify trigger and affected point.'),
        IncidentUpdate(
          priority: incident.source == EvidenceSource.laboratory
              ? Priority.urgent
              : Priority.routine,
          uncertainty:
              'Simulated single-point evidence; wider-system scope is not established.',
        ),
      ),
    );
    _at(base.add(const Duration(hours: 4)), () {
      incidents[incidentId] = incidents[incidentId]!.transition(
        IncidentState.assigned,
        _context(scope, Role.manager, 'Assign an accountable response.'),
        IncidentUpdate(
          ownerId: worker,
          dueAt: base.add(const Duration(days: 4)),
          requiredResponse:
              'Inspect the affected asset and document the authorized repair.',
        ),
      );
      var order = WorkOrder.propose(
        id: _random.uuid(),
        scope: scope,
        incidentId: incidentId,
        task: 'Inspect cover and fittings; record authorized maintenance',
        isSimulated: true,
      );
      order = order.transition(
        WorkOrderState.approvalPending,
        _context(scope, Role.field, 'Request manager authorization.'),
      );
      order = order.transition(
        WorkOrderState.assigned,
        _context(
          scope,
          Role.manager,
          'Approve the simulated maintenance request.',
        ),
        assignee: worker,
        deadline: base.add(const Duration(days: 3)),
      );
      workId = order.id;
      workOrders[order.id] = order;
    });
    _at(base.add(const Duration(hours: 6)), () {
      workOrders[workId!] = workOrders[workId!]!.transition(
        WorkOrderState.inProgress,
        _context(scope, Role.field, 'Start the assigned work.'),
      );
      incidents[incidentId] = incidents[incidentId]!.transition(
        IncidentState.mitigation,
        _context(
          scope,
          Role.manager,
          'Authorized work underway; concern remains visible.',
        ),
        IncidentUpdate(actionEvidence: workId),
      );
    });
    _at(
      completeAt,
      () => workOrders[workId!] = workOrders[workId!]!.transition(
        WorkOrderState.completed,
        _context(
          scope,
          Role.field,
          'Repair recorded; verification still pending.',
        ),
        evidence: 'simulation://work/$workId/completion',
      ),
    );
    _at(
      acceptedAt,
      () => workOrders[workId!] = workOrders[workId!]!.transition(
        WorkOrderState.accepted,
        _context(
          scope,
          Role.manager,
          'Review repair evidence, without closing the incident.',
        ),
      ),
    );
    _at(acceptedAt.add(const Duration(hours: 1)), () {
      final template = templates.singleWhere((t) => t.scope.matches(scope));
      final plan = VerificationPlan(
        pointIds: incidents[incidentId]!.pointIds,
        checklistIds: [template.id],
        indicator: Indicator.eColi,
        method: 'Membrane filtration (simulation)',
        notBefore: completeAt,
      );
      incidents[incidentId] = incidents[incidentId]!.transition(
        IncidentState.verificationPending,
        _context(
          scope,
          Role.manager,
          'Review interim controls and notices; request follow-up.',
        ),
        IncidentUpdate(
          actionEvidence: workId,
          controlsReviewed: true,
          noticeReviewed: true,
          plan: plan,
        ),
      );
      final tank = assets.singleWhere(
        (a) => a.scope.matches(scope) && a.type == AssetType.tank,
      );
      final task = InspectionTask(
        id: _random.uuid(),
        scope: scope,
        assetId: tank.id,
        templateId: template.id,
        dueAt: now,
        isSimulated: true,
      );
      inspections[task.id] = task;
      submitInspection(
        InspectionSubmission(
          clientEventId: _random.uuid(),
          taskId: task.id,
          scope: scope,
          templateId: template.id,
          expectedVersion: 0,
          observedAt: now,
          answers: {
            for (final q in template.questions)
              q.id: const InspectionAnswer(AnswerChoice.no),
          },
          notes: 'Simulated follow-up checklist; no laboratory claim.',
          isSimulated: true,
        ),
      );
      _at(
        now.add(const Duration(hours: 6)),
        () => _collect(
          points.singleWhere((p) => p.id == incident.pointIds.first),
          verificationFor: incidentId,
        ),
      );
    });
  }

  /// The local simulation adapter implements the same idempotency/version
  /// contract as the server RPC. Every retry returns the original receipt.
  int submitInspection(InspectionSubmission command) {
    final task = inspections[command.taskId];
    requireRule(
      task != null && task.scope.matches(command.scope) && command.isSimulated,
      'permission_denied',
      'This simulated assignment is outside the selected facility.',
    );
    final prior = _receipts[command.clientEventId];
    if (prior != null) {
      requireRule(
        prior == command.taskId &&
            submissions[prior]!.toJson().toString() ==
                command.toJson().toString(),
        'idempotency_conflict',
        'This event identifier belongs to different content.',
      );
      return inspections[prior]!.version;
    }
    requireRule(
      task!.version == command.expectedVersion && !task.isSubmitted,
      'version_conflict',
      'This assignment has already changed; review it before submitting.',
    );
    command.validate(templates.singleWhere((t) => t.id == task.templateId));
    requireRule(
      command.templateId == task.templateId,
      'template_mismatch',
      'Use the issued checklist version.',
    );
    inspections[task.id] = InspectionTask(
      id: task.id,
      scope: task.scope,
      assetId: task.assetId,
      templateId: task.templateId,
      dueAt: task.dueAt,
      isSimulated: true,
      version: task.version + 1,
      submittedAt: now,
    );
    submissions[task.id] = command;
    _receipts[command.clientEventId] = task.id;
    observationEvents.add(
      DomainEvent(
        id: command.clientEventId,
        scope: task.scope,
        aggregateId: task.id,
        actorId: actorFor(task.scope, Role.field).id,
        at: now,
        from: 'scheduled',
        to: 'submitted',
        reason:
            'Simulated inspection acknowledged; device-observed time preserved separately.',
        isSimulated: true,
      ),
    );
    if (command.hasRisk) {
      _openIncident(
        points.singleWhere((p) => p.assetId == task.assetId),
        EvidenceSource.inspection,
        task.id,
      );
    }
    return task.version + 1;
  }

  PublicWaterRecord? publicRecord(String token) {
    final qr = qrs.where((q) => q.token == token).firstOrNull;
    if (qr == null) return null;
    return projectPublicRecord(
      qr: qr,
      point: points.singleWhere((p) => p.id == qr.pointId),
      facility: facilities.singleWhere((f) => f.id == qr.scope.facilityId),
      results: results.values,
      incidents: incidents.values,
      workOrders: workOrders.values,
      now: now,
    );
  }

  String get featuredToken {
    final confirmed = qrs
        .where(
          (q) =>
              q.scope.matches(facilities.first.scope) &&
              publicRecord(q.token)?.state == PublicState.confirmedFinding,
        )
        .firstOrNull;
    return (confirmed ?? qrs.first).token;
  }

  Map<String, Object?> toJson() => {
    'simulation': {
      'seed': seed,
      'starts_at': startsAt.toIso8601String(),
      'now': now.toIso8601String(),
      'is_simulated': true,
      'model_version': 1,
    },
    'organizations': organizations.map((v) => v.toJson()).toList(),
    'facilities': facilities.map((v) => v.toJson()).toList(),
    'water_systems': systems.map((v) => v.toJson()).toList(),
    'assets': assets.map((v) => v.toJson()).toList(),
    'sampling_points': points.map((v) => v.toJson()).toList(),
    'checklist_templates': templates.map((v) => v.toJson()).toList(),
    'inspections': inspections.values
        .map((v) => {...v.toJson(), 'submission': submissions[v.id]?.toJson()})
        .toList(),
    'samples': samples.values.map((v) => v.toJson()).toList(),
    'custody_events': custody.map((v) => v.toJson()).toList(),
    'test_results': results.values.map((v) => v.toJson()).toList(),
    'incidents': incidents.values.map((v) => v.toJson()).toList(),
    'work_orders': workOrders.values.map((v) => v.toJson()).toList(),
    'public_records': qrs.map((v) => v.toJson()).toList(),
    'audit_events': auditEvents.map((v) => v.toJson()).toList(),
  };
}
