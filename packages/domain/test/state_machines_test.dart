import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';
import 'fixtures.dart';

Matcher violates(String code) =>
    isA<RuleViolation>().having((e) => e.code, 'code', code);

void main() {
  group('result authority and provenance', () {
    test(
      'chronological lifecycle retains four distinct dates and a report',
      () {
        final result = reviewed();
        expect(result.state, ResultState.published);
        expect(result.isReviewed, isTrue);
        expect(result.provenance, Provenance.independentlyReviewed);
        expect(
          {
            result.sample.collectedAt,
            result.testedAt,
            result.reviewedAt,
            result.publishedAt,
          }.length,
          4,
        );
        expect(result.history.map((e) => e.to), [
          'received',
          'valid',
          'tested',
          'reviewed',
          'published',
        ]);
      },
    );

    for (final role in [Role.field, Role.manager, Role.admin]) {
      test(
        '${role.name} cannot act as an independent lab reviewer',
        () => expect(
          () =>
              collected().transition(ResultState.received, context(role: role)),
          throwsA(violates('permission_denied')),
        ),
      );
    }
    test('revoked, expired and cross-facility reviewers are rejected', () {
      for (final actorContext in [
        context(active: false),
        context(expiresAt: day),
        context(inScope: const Scope('org-b', 'facility-b')),
        context(inScope: const Scope('org-a', 'facility-b')),
      ]) {
        expect(
          () => collected().transition(ResultState.received, actorContext),
          throwsA(violates('permission_denied')),
        );
      }
    });
    test(
      'offline attestation is not an authoritative event',
      () => expect(
        () => collected().transition(
          ResultState.received,
          context(online: false),
        ),
        throwsA(violates('server_required')),
      ),
    );
    test('rejected sample is terminal and never a negative result', () {
      var result = collected().transition(ResultState.received, context());
      expect(
        () => result.transition(ResultState.rejected, context()),
        throwsA(violates('rejection_reason')),
      );
      result = result.transition(
        ResultState.rejected,
        context(),
        rejection: 'Seal broken',
      );
      for (final target in ResultState.values) {
        expect(
          () => result.transition(target, context()),
          throwsA(isA<RuleViolation>()),
        );
      }
      expect(result.measurement, isNull);
      expect(result.isReviewed, isFalse);
    });
    test('no shortcut can skip collection, validity or testing', () {
      for (final target in ResultState.values.where(
        (s) => s != ResultState.received,
      )) {
        expect(
          () => collected().transition(target, context()),
          throwsA(violates('invalid_result_transition')),
        );
      }
    });
    test('review requires a linked report and laboratory source', () {
      for (final source in [
        EvidenceSource.laboratory,
        EvidenceSource.fieldScreen,
      ]) {
        var result = collected(
          source: source,
        ).transition(ResultState.received, context());
        result = result.transition(ResultState.valid, context());
        result = result.transition(
          ResultState.tested,
          context(),
          reading: Measurement(
            indicator: Indicator.eColi,
            method: 'Membrane filtration',
            value: 0,
            unit: ResultUnit.cfuPer100ml,
            detectionLimit: 1,
          ),
        );
        expect(
          () => result.transition(
            ResultState.reviewed,
            context(),
            linkedReport: source == EvidenceSource.fieldScreen ? 'report' : '',
          ),
          throwsA(violates('independent_review_required')),
        );
      }
    });
    test('clock skew cannot reorder authoritative lifecycle events', () {
      expect(
        () => collected().transition(ResultState.received, context(at: day)),
        throwsA(violates('time_order')),
      );
      final result = reviewed(publish: false);
      expect(
        () => result.transition(
          ResultState.published,
          context(role: Role.manager, at: result.testedAt),
        ),
        throwsA(violates('time_order')),
      );
    });
    test('correction is an append-only lineage, not an overwritten result', () {
      final original = reviewed(value: 8);
      final correction = original.correct(
        newId: 'revision-2',
        reading: Measurement(
          indicator: Indicator.eColi,
          method: 'Membrane filtration',
          value: 2,
          unit: ResultUnit.cfuPer100ml,
          detectionLimit: 1,
        ),
        linkedReport: 'corrected-report',
        context: context(reason: 'Transcription correction'),
      );
      expect(original.state, ResultState.published);
      expect(correction.original.state, ResultState.superseded);
      expect(correction.original.measurement!.value, 8);
      expect(correction.original.reportRef, 'report-signed');
      expect(correction.replacement.measurement!.value, 2);
      expect(correction.replacement.revisionOf, original.id);
      expect(
        correction.replacement.correctionReason,
        'Transcription correction',
      );
      expect(correction.replacement.correctedBy, 'lab');
      expect(correction.replacement.correctedAt, isNotNull);
      expect(correction.replacement.publishedAt, isNull);
      expect(
        correction.original.history.last.evidenceIds,
        contains('revision-2'),
      );
      expect(() => original.history.clear(), throwsUnsupportedError);
    });
    test(
      'corrections require an authorized actor, reason and unchanged scope',
      () {
        final original = reviewed();
        final reading = Measurement(
          indicator: Indicator.totalColiforms,
          method: 'Membrane filtration',
          value: 0,
          unit: ResultUnit.cfuPer100ml,
          detectionLimit: 1,
        );
        expect(
          () => original.correct(
            newId: 'new',
            reading: reading,
            linkedReport: 'report',
            context: context(),
          ),
          throwsA(violates('correction_scope')),
        );
        expect(
          () => original.correct(
            newId: 'new',
            reading: original.measurement!,
            linkedReport: 'report',
            context: context(role: Role.field),
          ),
          throwsA(violates('permission_denied')),
        );
        expect(
          () => original.correct(
            newId: 'new',
            reading: original.measurement!,
            linkedReport: 'report',
            context: context(reason: ' '),
          ),
          throwsA(violates('reason_required')),
        );
      },
    );
    test('NaN, infinity, negative values and invalid presence counts fail', () {
      for (final value in [double.nan, double.infinity, -1.0]) {
        expect(
          () => Measurement(
            indicator: Indicator.eColi,
            method: 'method',
            value: value,
            unit: ResultUnit.cfuPer100ml,
            detectionLimit: 1,
          ),
          throwsA(violates('invalid_measurement')),
        );
      }
      expect(
        () => Measurement(
          indicator: Indicator.hydrogenSulfide,
          method: 'screen',
          value: 2,
          unit: ResultUnit.presenceAbsence,
          detectionLimit: 1,
        ),
        throwsA(violates('invalid_presence')),
      );
      expect(
        () => Measurement(
          indicator: Indicator.hydrogenSulfide,
          method: 'screen',
          value: 1,
          unit: ResultUnit.cfuPer100ml,
          detectionLimit: 1,
        ),
        throwsA(violates('screening_units')),
      );
    });
  });

  group('separate work-order lifecycle', () {
    WorkOrder proposed() => WorkOrder.propose(
      id: 'work',
      scope: scope,
      incidentId: 'incident',
      task: 'Repair cover',
      isSimulated: true,
    );
    WorkOrder assigned() => proposed()
        .transition(WorkOrderState.approvalPending, context(role: Role.field))
        .transition(
          WorkOrderState.assigned,
          context(role: Role.manager),
          assignee: 'field',
          deadline: day.add(const Duration(days: 8)),
        );
    test(
      'requires manager approval, assignee, deadline and completion evidence',
      () {
        final request = proposed().transition(
          WorkOrderState.approvalPending,
          context(role: Role.field),
        );
        expect(
          () => request.transition(
            WorkOrderState.assigned,
            context(role: Role.field),
            assignee: 'field',
            deadline: day.add(const Duration(days: 8)),
          ),
          throwsA(violates('permission_denied')),
        );
        expect(
          () => request.transition(
            WorkOrderState.assigned,
            context(role: Role.manager),
          ),
          throwsA(violates('assignment_required')),
        );
        var work = assigned();
        expect(
          () => work.transition(
            WorkOrderState.inProgress,
            context(role: Role.manager),
          ),
          throwsA(violates('assignee_required')),
        );
        work = work.transition(
          WorkOrderState.inProgress,
          context(role: Role.field),
        );
        expect(
          () => work.transition(
            WorkOrderState.completed,
            context(role: Role.field),
          ),
          throwsA(violates('completion_evidence')),
        );
      },
    );
    test('completed and accepted repairs do not change an incident', () {
      final incident = pending();
      var work = assigned()
          .transition(WorkOrderState.inProgress, context(role: Role.field))
          .transition(
            WorkOrderState.completed,
            context(role: Role.field),
            evidence: 'photo-ref',
          );
      expect(incident.state, IncidentState.verificationPending);
      expect(
        () =>
            work.transition(WorkOrderState.accepted, context(role: Role.field)),
        throwsA(violates('permission_denied')),
      );
      work = work.transition(
        WorkOrderState.accepted,
        context(role: Role.manager),
      );
      expect(work.state, WorkOrderState.accepted);
      expect(incident.isOpen, isTrue);
    });
    test('rework clears obsolete completion evidence', () {
      var work = assigned()
          .transition(WorkOrderState.inProgress, context(role: Role.field))
          .transition(
            WorkOrderState.completed,
            context(role: Role.field),
            evidence: 'old-photo',
          );
      work = work.transition(
        WorkOrderState.rework,
        context(role: Role.manager),
      );
      work = work.transition(
        WorkOrderState.inProgress,
        context(role: Role.field),
      );
      expect(work.completionEvidence, isNull);
      expect(
        work.history.any((e) => e.evidenceIds.contains('old-photo')),
        isTrue,
      );
      expect(
        () => work.transition(
          WorkOrderState.accepted,
          context(role: Role.manager),
        ),
        throwsA(violates('invalid_work_transition')),
      );
    });
  });

  group('incident closure and reopening', () {
    test('valid evidence, authorized manager and communication resolve', () {
      final resolved = pending().transition(
        IncidentState.resolved,
        context(role: Role.manager),
        IncidentUpdate(closure: closure()),
      );
      expect(resolved.isOpen, isFalse);
      expect(resolved.resolvedAt, isNotNull);
      expect(resolved.communicationRef, 'notice');
    });
    test('offline/field/lab closure is denied', () {
      for (final c in [
        context(role: Role.field),
        context(role: Role.lab),
        context(role: Role.manager, online: false),
      ]) {
        expect(
          () => pending().transition(
            IncidentState.resolved,
            c,
            IncidentUpdate(closure: closure()),
          ),
          throwsA(isA<RuleViolation>()),
        );
      }
    });
    test('missing communication or checklist keeps the incident open', () {
      expect(
        () => pending().transition(
          IncidentState.resolved,
          context(role: Role.manager),
          IncidentUpdate(closure: closure(communication: '')),
        ),
        throwsA(violates('closure_evidence_required')),
      );
      expect(
        () => pending().transition(
          IncidentState.resolved,
          context(role: Role.manager),
          IncidentUpdate(closure: closure(checklists: [])),
        ),
        throwsA(violates('checklist_incomplete')),
      );
    });
    final invalidResults = <String, ResultRecord Function()>{
      'positive finding': () => reviewed(value: 1),
      'different point': () => reviewed(point: 'other'),
      'different tenant': () =>
          reviewed(inScope: const Scope('org-b', 'facility-b')),
      'different indicator': () =>
          reviewed(indicator: Indicator.totalColiforms),
      'different method': () => reviewed(method: 'Different method'),
      'pre-action sample': () => reviewed(at: day),
      'future review': () => reviewed(at: day.add(const Duration(days: 6))),
      'simulation/live mixture': () => reviewed(simulated: false),
      'unreviewed sample': () => collected(),
      'rejected sample': () => collected()
          .transition(ResultState.received, context())
          .transition(
            ResultState.rejected,
            context(),
            rejection: 'Broken seal',
          ),
    };
    for (final entry in invalidResults.entries) {
      test(
        '${entry.key} cannot fulfil verification',
        () => expect(
          () => pending().transition(
            IncidentState.resolved,
            context(role: Role.manager),
            IncidentUpdate(closure: closure(results: [entry.value()])),
          ),
          throwsA(violates('sample_incomplete')),
        ),
      );
    }
    test(
      'every planned point is required, not only one convenient negative',
      () {
        final plan = VerificationPlan(
          pointIds: ['point', 'second-point'],
          checklistIds: ['template'],
          indicator: Indicator.eColi,
          method: 'Membrane filtration',
          notBefore: day.add(const Duration(days: 1)),
        );
        expect(
          () => pending(plan: plan).transition(
            IncidentState.resolved,
            context(role: Role.manager),
            IncidentUpdate(closure: closure()),
          ),
          throwsA(violates('sample_incomplete')),
        );
      },
    );
    test(
      'stale results do not satisfy a plan',
      () => expect(
        () => pending().transition(
          IncidentState.resolved,
          context(role: Role.manager, at: day.add(const Duration(days: 40))),
          IncidentUpdate(closure: closure()),
        ),
        throwsA(violates('sample_incomplete')),
      ),
    );
    test('reopening requires new evidence and preserves original closure', () {
      final resolved = pending().transition(
        IncidentState.resolved,
        context(role: Role.manager),
        IncidentUpdate(closure: closure()),
      );
      expect(
        () => resolved.transition(
          IncidentState.reopened,
          context(role: Role.manager),
        ),
        throwsA(violates('reopen_evidence')),
      );
      final repeat = reviewed(value: 4, at: day.add(const Duration(days: 6)));
      final reopened = resolved.transition(
        IncidentState.reopened,
        context(role: Role.manager, at: day.add(const Duration(days: 7))),
        IncidentUpdate(
          reopenCause: ReopenCause.repeatVerifiedFinding,
          newEvidenceRef: repeat.id,
          repeatResult: repeat,
        ),
      );
      expect(reopened.resolvedAt, resolved.resolvedAt);
      expect(reopened.history.any((e) => e.to == 'resolved'), isTrue);
      expect(reopened.isOpen, isTrue);
    });
    test('an unverified repeat cannot reopen as a verified finding', () {
      final resolved = pending().transition(
        IncidentState.resolved,
        context(role: Role.manager),
        IncidentUpdate(closure: closure()),
      );
      expect(
        () => resolved.transition(
          IncidentState.reopened,
          context(role: Role.manager),
          IncidentUpdate(
            reopenCause: ReopenCause.repeatVerifiedFinding,
            newEvidenceRef: 'draft',
            repeatResult: collected(),
          ),
        ),
        throwsA(violates('repeat_finding_required')),
      );
    });
    test('escalation keeps lifecycle and records only an internal event', () {
      final incident = pending();
      expect(
        () => incident.escalate(
          context(role: Role.manager, at: day.add(const Duration(days: 2))),
        ),
        throwsA(violates('escalation_not_due')),
      );
      final escalated = incident.escalate(context(role: Role.manager));
      expect(escalated.state, IncidentState.verificationPending);
      expect(escalated.history.last.to, 'escalated');
    });
  });
}
