import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';

final now = DateTime.utc(2026, 11, 15, 12);
Matcher failure(FailureKind kind) =>
    throwsA(isA<RepositoryFailure>().having((e) => e.kind, 'kind', kind));

SimulationEngine until(bool Function(SimulationEngine) ready) {
  final engine = SimulationEngine();
  for (var hour = 0; hour < 24 * 30; hour++) {
    if (ready(engine)) return engine;
    engine.advance(const Duration(hours: 1));
  }
  throw StateError('Required generated lifecycle state was not reached.');
}

CommandContext context(
  SimulationEngine engine,
  Scope scope,
  Role role,
  String event,
) => CommandContext(
  actor: engine.actorFor(scope, role),
  at: engine.now,
  eventId: event,
  serverConfirmed: true,
  reason: 'Simulated manager test: $event',
);

void main() {
  test(
    'manager projection uses the shared engine and scopes every nested record',
    () async {
      final engine = SimulationEngine()..advance(const Duration(days: 10));
      final repository = SimulationManagerRepository(
        engine: engine,
        clock: () => now,
      );
      expect(repository.serverBacked, false);
      for (final facility in engine.facilities) {
        final data = await repository.load(facilityId: facility.id);
        final scope = facility.scope;
        expect(data.actorId, engine.actorFor(scope, Role.manager).id);
        expect(
          data.facilities.map((f) => f.id),
          engine.facilities.map((f) => f.id),
        );
        expect(data.asOf, engine.now);
        expect(data.fetchedAt, now);
        expect(data.simulationSeed, engine.seed);
        expect(data.modelVersion, 1);
        expect(data.facility.isSimulated, true);
        expect(
          data.assets.map((a) => a.id).toSet(),
          engine.assets
              .where((a) => a.scope.matches(scope))
              .map((a) => a.id)
              .toSet(),
        );
        expect(data.systems.every((s) => s.scope.matches(scope)), true);
        expect(data.templates.every((t) => t.scope.matches(scope)), true);
        expect(
          data.points.every(
            (p) => p.scope.matches(scope) && data.asset(p.assetId) != null,
          ),
          true,
        );
        expect(
          data.inspections.length,
          engine.inspections.values.where((i) => i.scope.matches(scope)).length,
        );
        for (final inspection in data.inspections) {
          final original = engine.inspections[inspection.task.id]!;
          expect(inspection.task.version, original.version);
          expect(inspection.task.submittedAt, original.submittedAt);
          expect(inspection.assignedTo, engine.actorFor(scope, Role.field).id);
          final submission = engine.submissions[inspection.task.id];
          expect(inspection.observedAt, submission?.observedAt);
          expect(
            inspection.answers.map(
              (id, answer) => MapEntry(id, answer.toJson()),
            ),
            submission?.answers.map(
                  (id, answer) => MapEntry(id, answer.toJson()),
                ) ??
                {},
          );
        }
        for (final item in data.samples) {
          final original = engine.samples[item.sample.id]!;
          expect(item.sample.scope.matches(scope), true);
          expect(item.sample.toJson(), original.toJson());
          expect(
            item.custody.map((c) => c.toJson()),
            engine.custody
                .where((c) => c.sampleId == original.id)
                .map((c) => c.toJson()),
          );
        }
        for (final row in data.results) {
          final original = engine.results[row.id]!;
          expect(row.sample.scope.matches(scope), true);
          expect(row.version, original.version);
          expect(row.state, original.state);
          expect(row.measurement?.toJson(), original.measurement?.toJson());
          expect(row.reviewedBy, original.reviewedBy);
          expect(row.reportRef, original.reportRef);
          expect(row.audit.map((a) => a.id), original.history.map((a) => a.id));
        }
        expect(
          data.incidents.map((i) => i.id),
          engine.incidents.values
              .where((i) => i.scope.matches(scope))
              .map((i) => i.id),
        );
        expect(
          data.orders.map((w) => w.id),
          engine.workOrders.values
              .where((w) => w.scope.matches(scope))
              .map((w) => w.id),
        );
        expect(
          data.members.map((m) => m.userId),
          engine.actors.where((a) => a.scope.matches(scope)).map((a) => a.id),
        );
        expect(
          data.audit.map((a) => a.id),
          engine.auditEvents
              .where((a) => a.scope.matches(scope))
              .map((a) => a.id),
        );
      }
    },
  );

  test(
    'manager access and member expiry use actual time, not the exercise clock',
    () async {
      var actual = now;
      final repository = SimulationManagerRepository(clock: () => actual);
      final initial = await repository.load();
      final index = repository.engine.actors.indexWhere(
        (a) => a.id == initial.actorId,
      );
      final manager = repository.engine.actors[index];
      repository.engine.actors[index] = Actor(
        id: manager.id,
        role: manager.role,
        scope: manager.scope,
        expiresAt: actual.add(const Duration(seconds: 1)),
      );
      expect(
        (await repository.load()).members
            .firstWhere((m) => m.userId == manager.id)
            .activeAt(actual),
        true,
      );
      actual = actual.add(const Duration(seconds: 2));
      await expectLater(repository.load(), failure(FailureKind.permission));
      await expectLater(
        repository.revokeQr(
          token: initial.qrs.first.token,
          reason: 'Expired request',
        ),
        failure(FailureKind.permission),
      );
      final other = initial.facilities.firstWhere(
        (f) => f.id != initial.facility.id,
      );
      final otherData = await repository.load(facilityId: other.id);
      expect(
        otherData.facilities.map((f) => f.id),
        isNot(contains(initial.facility.id)),
      );
      await expectLater(
        repository.load(facilityId: 'unknown-facility'),
        failure(FailureKind.permission),
      );
    },
  );

  test('commands require the selected facility and original version', () async {
    final repository = SimulationManagerRepository(clock: () => now);
    final first = await repository.load();
    final other = repository.engine.results.values.firstWhere(
      (r) => !r.sample.scope.matches(first.scope),
    );
    await expectLater(
      repository.publishResult(
        id: other.id,
        expectedVersion: other.version,
        reason: 'Wrong scope',
      ),
      failure(FailureKind.permission),
    );
    await repository.load(facilityId: other.sample.scope.facilityId);
    await expectLater(
      repository.publishResult(
        id: other.id,
        expectedVersion: other.version - 1,
        reason: 'Old view',
      ),
      failure(FailureKind.conflict),
    );
    expect(repository.engine.results[other.id], same(other));
  });

  test(
    'triage, owner and internal escalation preserve guarded incident history',
    () async {
      final engine = until(
        (e) => e.incidents.values.any((i) => i.state == IncidentState.reported),
      );
      final repository = SimulationManagerRepository(
        engine: engine,
        clock: () => now,
      );
      final incident = engine.incidents.values.firstWhere(
        (i) => i.state == IncidentState.reported,
      );
      final data = await repository.load(facilityId: incident.scope.facilityId);
      await expectLater(
        repository.transitionIncident(
          id: incident.id,
          target: IncidentState.triaged,
          expectedVersion: incident.version,
          reason: 'Missing evidence',
        ),
        failure(FailureKind.invalid),
      );
      final version = await repository.transitionIncident(
        id: incident.id,
        target: IncidentState.triaged,
        expectedVersion: incident.version,
        payload: {
          'priority': 'critical',
          'uncertainty': 'Limited to the reported point',
        },
        reason: 'Review concern',
      );
      final other = engine.actors.firstWhere(
        (a) => !a.scope.matches(incident.scope),
      );
      await expectLater(
        repository.transitionIncident(
          id: incident.id,
          target: IncidentState.assigned,
          expectedVersion: version,
          payload: {
            'owner_id': other.id,
            'due_at': engine.now.add(const Duration(days: 1)).toIso8601String(),
            'required_response': 'Inspect',
          },
          reason: 'Wrong owner',
        ),
        failure(FailureKind.invalid),
      );
      final field = engine.actorFor(incident.scope, Role.field);
      await expectLater(
        repository.transitionIncident(
          id: incident.id,
          target: IncidentState.assigned,
          expectedVersion: version,
          payload: {
            'owner_id': field.id,
            'due_at': engine.now.toIso8601String(),
            'required_response': 'Inspect',
          },
          reason: 'Past deadline',
        ),
        failure(FailureKind.invalid),
      );
      final assignedVersion = await repository.transitionIncident(
        id: incident.id,
        target: IncidentState.assigned,
        expectedVersion: version,
        payload: {
          'owner_id': field.id,
          'due_at': engine.now.add(const Duration(days: 1)).toIso8601String(),
          'required_response': 'Inspect',
        },
        reason: 'Assign response',
      );
      final escalatedVersion = await repository.escalateIncident(
        id: incident.id,
        expectedVersion: assignedVersion,
        reason: 'Critical internal escalation',
      );
      final updated = engine.incidents[incident.id]!;
      expect(escalatedVersion, incident.version + 3);
      expect(updated.ownerId, field.id);
      expect(updated.state, IncidentState.assigned);
      expect(updated.escalatedAt, engine.now);
      expect(
        updated.history
            .skip(incident.version)
            .every((a) => a.actorId == data.actorId && a.isSimulated),
        true,
      );
      expect(
        updated.history.map((a) => a.id).toSet().length,
        updated.history.length,
      );
      await expectLater(
        repository.transitionIncident(
          id: incident.id,
          target: IncidentState.resolved,
          expectedVersion: escalatedVersion,
          reason: 'Premature closure',
        ),
        failure(FailureKind.invalid),
      );
    },
  );

  test('work approval accepts only active scoped field assignments', () async {
    final engine = until((e) => e.incidents.isNotEmpty);
    final incident = engine.incidents.values.first;
    final repository = SimulationManagerRepository(
      engine: engine,
      clock: () => now,
    );
    final data = await repository.load(facilityId: incident.scope.facilityId);
    final order =
        WorkOrder.propose(
          id: 'manager-pending-order',
          scope: incident.scope,
          incidentId: incident.id,
          task: 'Inspect approved fittings',
          isSimulated: true,
        ).transition(
          WorkOrderState.approvalPending,
          context(engine, incident.scope, Role.field, 'propose'),
        );
    engine.workOrders[order.id] = order;
    final field = engine.actorFor(incident.scope, Role.field);
    final deadline = engine.now.add(const Duration(days: 2));
    Future<int> approve(String owner, {DateTime? due}) =>
        repository.transitionWorkOrder(
          id: order.id,
          target: WorkOrderState.assigned,
          expectedVersion: order.version,
          payload: {
            'assignee_id': owner,
            'due_at': (due ?? deadline).toIso8601String(),
          },
          reason: 'Authorize work',
        );
    await expectLater(
      approve(engine.actorFor(incident.scope, Role.lab).id),
      failure(FailureKind.invalid),
    );
    await expectLater(
      approve(
        engine.actors
            .firstWhere(
              (a) => a.role == Role.field && !a.scope.matches(incident.scope),
            )
            .id,
      ),
      failure(FailureKind.invalid),
    );
    await expectLater(
      approve(field.id, due: engine.now),
      failure(FailureKind.invalid),
    );
    final fieldIndex = engine.actors.indexOf(field);
    engine.actors[fieldIndex] = Actor(
      id: field.id,
      role: field.role,
      scope: field.scope,
      expiresAt: now,
    );
    await expectLater(approve(field.id), failure(FailureKind.invalid));
    engine.actors[fieldIndex] = field;
    expect(await approve(field.id), order.version + 1);
    final approved = engine.workOrders[order.id]!;
    expect(approved.assigneeId, field.id);
    expect(approved.approvedBy, data.actorId);
    expect(approved.dueAt, deadline);
    expect(engine.incidents[incident.id], same(incident));
    await expectLater(approve(field.id), failure(FailureKind.conflict));
  });

  test(
    'verification needs accepted work, explicit scope, original method and notice review',
    () async {
      final engine = until(
        (e) => e.workOrders.values.any(
          (w) =>
              w.state == WorkOrderState.completed &&
              e.incidents[w.incidentId]!.source == EvidenceSource.laboratory,
        ),
      );
      final order = engine.workOrders.values.firstWhere(
        (w) =>
            w.state == WorkOrderState.completed &&
            engine.incidents[w.incidentId]!.source == EvidenceSource.laboratory,
      );
      final incident = engine.incidents[order.incidentId]!;
      final original = engine.results[incident.sourceId]!.measurement!;
      final repository = SimulationManagerRepository(
        engine: engine,
        clock: () => now,
      );
      await repository.load(facilityId: incident.scope.facilityId);
      final payload = <String, Object?>{
        'requirements': [
          for (final id in incident.pointIds)
            {
              'kind': 'sample',
              'point_id': id,
              'indicator': wireName(original.indicator),
              'method': original.method,
            },
        ],
        'controls_reviewed': true,
        'notice_reviewed': true,
        'notice_ref': 'simulation://notice-reviewed',
      };
      Future<int> verify(Map<String, Object?> values) =>
          repository.transitionIncident(
            id: incident.id,
            target: IncidentState.verificationPending,
            expectedVersion: incident.version,
            payload: values,
            reason: 'Review follow-up requirements',
          );
      await expectLater(verify(payload), failure(FailureKind.invalid));
      await repository.transitionWorkOrder(
        id: order.id,
        target: WorkOrderState.accepted,
        expectedVersion: order.version,
        reason: 'Accept recorded work evidence',
      );
      expect(engine.incidents[incident.id], same(incident));
      await expectLater(
        verify({...payload, 'notice_ref': ' '}),
        failure(FailureKind.invalid),
      );
      await expectLater(
        verify({...payload, 'controls_reviewed': false}),
        failure(FailureKind.invalid),
      );
      await expectLater(
        verify({...payload, 'notice_reviewed': false}),
        failure(FailureKind.invalid),
      );
      await expectLater(
        verify({
          ...payload,
          'requirements': [
            {
              'kind': 'checklist',
              'template_id': engine.templates
                  .firstWhere((t) => t.scope.matches(incident.scope))
                  .id,
            },
          ],
        }),
        failure(FailureKind.invalid),
      );
      await expectLater(
        verify({
          ...payload,
          'requirements': [
            {
              'kind': 'sample',
              'point_id': engine.points
                  .firstWhere((p) => !p.scope.matches(incident.scope))
                  .id,
              'indicator': wireName(original.indicator),
              'method': original.method,
            },
          ],
        }),
        failure(FailureKind.invalid),
      );
      await expectLater(
        verify({
          ...payload,
          'requirements': [
            {
              'kind': 'sample',
              'point_id': incident.pointIds.first,
              'indicator': wireName(original.indicator),
              'method': 'Unrelated method',
            },
          ],
        }),
        failure(FailureKind.invalid),
      );
      expect(engine.incidents[incident.id], same(incident));
      expect(await verify(payload), incident.version + 1);
      final updated = engine.incidents[incident.id]!;
      expect(updated.state, IncidentState.verificationPending);
      expect(updated.actionEvidence, order.id);
      expect(updated.plan!.pointIds, incident.pointIds);
      expect(updated.plan!.method, original.method);
      expect(updated.plan!.notBefore, engine.now);
      final projected = (await repository.load()).incidents.firstWhere(
        (i) => i.id == incident.id,
      );
      expect(projected.requirements.map((r) => r.pointId), incident.pointIds);
      expect(
        projected.requirements.every((r) => r.method == original.method),
        true,
      );
      expect(updated.resolvedAt, isNull);
    },
  );

  test(
    'publication preserves laboratory provenance and refuses unreviewed records',
    () async {
      final engine = until(
        (e) => e.results.values.any((r) => r.state == ResultState.reviewed),
      );
      final original = engine.results.values.firstWhere(
        (r) => r.state == ResultState.reviewed,
      );
      final repository = SimulationManagerRepository(
        engine: engine,
        clock: () => now,
      );
      await repository.load(facilityId: original.sample.scope.facilityId);
      await expectLater(
        repository.publishResult(
          id: original.id,
          expectedVersion: original.version,
          reason: ' ',
        ),
        failure(FailureKind.invalid),
      );
      expect(
        await repository.publishResult(
          id: original.id,
          expectedVersion: original.version,
          reason: 'Publish dated evidence',
        ),
        original.version + 1,
      );
      final published = engine.results[original.id]!;
      expect(published.measurement, same(original.measurement));
      expect(published.reportRef, original.reportRef);
      expect(published.reviewedBy, original.reviewedBy);
      expect(published.reviewedAt, original.reviewedAt);
      expect(published.publishedAt, engine.now);
      expect(published.isSimulated, true);
      final correction = published.correct(
        newId: 'manager-test-corrected',
        reading: original.measurement!,
        linkedReport: 'simulation://corrected',
        context: context(engine, original.sample.scope, Role.lab, 'correct'),
      );
      engine.results[published.id] = correction.original;
      engine.results[correction.replacement.id] = correction.replacement;
      await expectLater(
        repository.publishResult(
          id: published.id,
          expectedVersion: correction.original.version,
          reason: 'Old revision',
        ),
        failure(FailureKind.invalid),
      );
      final data = await repository.load();
      expect(data.resultsFor(original.sample.id).length, 2);
      expect(
        data.currentResult(original.sample.id)!.id,
        correction.replacement.id,
      );
      expect(
        data.results.firstWhere((r) => r.id == published.id).reportRef,
        original.reportRef,
      );
      expect(data.currentResult(original.sample.id)!.revisionOf, original.id);
      final unreviewedEngine = until(
        (e) => e.results.values.any((r) => r.state == ResultState.tested),
      );
      final unreviewed = unreviewedEngine.results.values.firstWhere(
        (r) => r.state == ResultState.tested,
      );
      final otherRepository = SimulationManagerRepository(
        engine: unreviewedEngine,
        clock: () => now,
      );
      await otherRepository.load(
        facilityId: unreviewed.sample.scope.facilityId,
      );
      await expectLater(
        otherRepository.publishResult(
          id: unreviewed.id,
          expectedVersion: unreviewed.version,
          reason: 'No lab review',
        ),
        failure(FailureKind.invalid),
      );
      expect(unreviewedEngine.results[unreviewed.id], same(unreviewed));
    },
  );

  test(
    'QR revocation preserves identity and is idempotent after acknowledgement loss',
    () async {
      final repository = SimulationManagerRepository(clock: () => now);
      final data = await repository.load();
      final qr = data.qrs.first;
      await expectLater(
        repository.revokeQr(token: qr.token, reason: ' '),
        failure(FailureKind.invalid),
      );
      await repository.revokeQr(
        token: qr.token,
        reason: 'Damaged printed code',
      );
      final revoked = repository.engine.qrs.singleWhere(
        (q) => q.token == qr.token,
      );
      expect(revoked.pointId, qr.pointId);
      expect(revoked.revokedAt, repository.engine.now);
      expect(revoked.history.last.actorId, data.actorId);
      await repository.revokeQr(
        token: qr.token,
        reason: 'Retry after lost response',
      );
      expect(
        repository.engine.qrs.singleWhere((q) => q.token == qr.token),
        same(revoked),
      );
      expect(
        (await repository.load()).dashboard.publicTokens.values,
        isNot(contains(qr.token)),
      );
      expect(repository.engine.publicRecord(qr.token), isNull);
    },
  );
}
