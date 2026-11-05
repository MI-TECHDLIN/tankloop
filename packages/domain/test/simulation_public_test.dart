import 'dart:convert';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';
import 'fixtures.dart';

void main() {
  test('fixed seed and elapsed time reproduce the entire event log', () {
    final a = SimulationEngine()..advance(const Duration(days: 21));
    final b = SimulationEngine();
    for (var i = 0; i < 42; i++) {
      b.advance(const Duration(hours: 12));
    }
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(
      a.results.values.any((r) => r.state == ResultState.rejected),
      isTrue,
    );
    expect(
      a.incidents.values.any((i) => i.history.any((e) => e.to == 'resolved')),
      isTrue,
    );
    expect(
      a.incidents.values.any((i) => i.history.any((e) => e.to == 'reopened')),
      isTrue,
    );
    expect(
      a.workOrders.values.any((w) => w.state == WorkOrderState.accepted),
      isTrue,
    );
    expect(a.custody, isNotEmpty);
    expect(a.auditEvents.every((e) => e.isSimulated), isTrue);
    expect(a.samples.values.every((s) => s.isSimulated), isTrue);
    expect(a.results.values.every((r) => r.isSimulated), isTrue);
  });
  test('seed changes workload and simulation never uses wall time', () {
    final a = SimulationEngine(seed: 1)..advance(const Duration(days: 10));
    final b = SimulationEngine(seed: 2)..advance(const Duration(days: 10));
    expect(jsonEncode(a.toJson()), isNot(jsonEncode(b.toJson())));
    expect(a.now, DateTime.utc(2026, 11, 11, 6));
    expect(
      () => a.advance(const Duration(days: -1)),
      throwsA(isA<RuleViolation>()),
    );
    for (final result in a.results.values.where((r) => r.isReviewed)) {
      expect(result.reviewedAt!.isAfter(result.testedAt!), isTrue);
      expect(result.testedAt!.isAfter(result.sample.collectedAt), isTrue);
    }
  });
  test('offline inspection submission is idempotent and preserves version', () {
    final engine = SimulationEngine()..advance(const Duration(days: 10));
    final task = engine.inspections.values.firstWhere((t) => !t.isSubmitted);
    final template = engine.templates.singleWhere(
      (t) => t.id == task.templateId,
    );
    final command = InspectionSubmission(
      clientEventId: 'device-event',
      taskId: task.id,
      scope: task.scope,
      templateId: template.id,
      expectedVersion: 0,
      observedAt: engine.now,
      answers: {
        for (final q in template.questions)
          q.id: const InspectionAnswer(AnswerChoice.yes),
      },
      isSimulated: true,
    );
    final before = engine.incidents.length;
    expect(engine.submitInspection(command), 1);
    expect(engine.submitInspection(command), 1);
    expect(engine.incidents.length, before + 1);
    expect(engine.submissions[task.id]!.observedAt, command.observedAt);
  });

  group('public language and identity', () {
    const point = SamplingPoint(
      id: 'point',
      scope: scope,
      assetId: 'asset',
      label: 'Courtyard tap',
      isSimulated: true,
    );
    const facility = Facility(
      id: 'facility-a',
      organizationId: 'org-a',
      label: 'Cedar Court',
      isSimulated: true,
    );
    PublicQr qr() => PublicQr.issue(
      // Synthetic public QR fixture, never an authentication credential.
      token: '0123456789abcdef0123456789abcdef', // gitleaks:allow
      pointId: point.id,
      scope: scope,
      at: day,
      isSimulated: true,
    );
    PublicWaterRecord? projection({
      List<ResultRecord> results = const [],
      List<IncidentRecord> incidents = const [],
      DateTime? now,
      PublicQr? token,
    }) => projectPublicRecord(
      qr: token ?? qr(),
      point: point,
      facility: facility,
      results: results,
      incidents: incidents,
      workOrders: [],
      now: now ?? day.add(const Duration(days: 5)),
    );

    test('missing, unreviewed and stale records are never current', () {
      expect(
        projection()!.wording,
        'We do not have a current verified test record for this point.',
      );
      expect(projection(results: [collected()])!.isCurrent, isFalse);
      final stale = projection(
        results: [reviewed()],
        now: day.add(const Duration(days: 40)),
      )!;
      expect(stale.state, PublicState.noValidCurrentData);
      expect(stale.tests, hasLength(1));
      expect(stale.isCurrent, isFalse);
    });
    test('an older normal test cannot hide an open confirmed finding', () {
      final positive = reviewed(value: 8);
      final normal = reviewed(
        id: 'older-normal',
        at: day.add(const Duration(days: 1)),
      );
      final record = projection(
        results: [positive, normal],
        incidents: [pending()],
      )!;
      expect(record.state, PublicState.confirmedFinding);
      expect(record.concerns, hasLength(1));
      expect(record.wording, contains('verified E. coli finding'));
    });
    test('inspection observations never imply a laboratory result', () {
      final incident = IncidentRecord.report(
        id: 'observation',
        scope: scope,
        systemId: 'system',
        pointIds: ['point'],
        source: EvidenceSource.inspection,
        sourceId: 'inspection',
        at: day,
        isSimulated: true,
      );
      final record = projection(incidents: [incident])!;
      expect(record.state, PublicState.riskObserved);
      expect(record.wording, contains('Testing may be needed'));
    });
    test('negative wording is dated, indicator-specific and scope-limited', () {
      final record = projection(results: [reviewed()])!;
      expect(
        record.latestTest!.exactFinding,
        'No E. coli detected in this sample on 2026-11-03; other hazards were not assessed.',
      );
      expect(jsonEncode(record.toJson()), isNot(contains('report-signed')));
      expect(jsonEncode(record.toJson()), isNot(contains('collector_id')));
      expect(
        PublicWaterRecord.fromJson(
          jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
        ).wording,
        record.wording,
      );
    });
    test('revocation retains an audit and permanently disables lookup', () {
      final revoked = qr().revoke(context(role: Role.manager));
      expect(revoked.history.single.to, 'revoked');
      expect(revoked.pointId, 'point');
      expect(projection(token: revoked), isNull);
      expect(
        () => revoked.revoke(context(role: Role.manager)),
        throwsA(isA<RuleViolation>()),
      );
      expect(
        () => qr().revoke(context(role: Role.field)),
        throwsA(isA<RuleViolation>()),
      );
    });
    test(
      'QR lookup rejects another facility identity',
      () => expect(
        () => projectPublicRecord(
          qr: qr(),
          point: const SamplingPoint(
            id: 'other',
            scope: Scope('other', 'other'),
            assetId: 'asset',
            label: 'Other',
            isSimulated: true,
          ),
          facility: facility,
          results: [],
          incidents: [],
          workOrders: [],
          now: day,
        ),
        throwsA(isA<RuleViolation>()),
      ),
    );
  });
}
