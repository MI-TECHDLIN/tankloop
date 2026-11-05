import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/manager_widgets.dart';
import 'manager_test_support.dart';

void main() {
  testWidgets(
    'facilities filters real assets and follows downstream identity',
    (tester) async {
      final repository = TestManagerRepository(connected: false);
      final controller = await openManagerScreen(tester, repository, 1);
      final data = controller.workspace!;
      final tank = data.assets.firstWhere((a) => a.type == AssetType.tank);
      await managerTap(tester, managerChip('Tank'));
      expect(
        find.byType(ManagerRecordTile),
        findsNWidgets(
          data.assets.where((a) => a.type == AssetType.tank).length,
        ),
      );
      await tester.enterText(
        managerField('Search assets'),
        'no matching asset',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching records'), findsOneWidget);
      await managerTap(tester, find.text('Clear filters'));
      expect(find.byType(ManagerRecordTile), findsNWidgets(data.assets.length));
      await managerTap(tester, find.byKey(ValueKey('asset-${tank.id}')));
      expect(find.text(tank.id), findsOneWidget);
      expect(find.text('${tank.capacityLitres} litres'), findsOneWidget);
      final child = data.assets.firstWhere((a) => a.parentId == tank.id);
      await managerTap(tester, find.widgetWithText(TextButton, child.label));
      expect(find.text(child.id), findsOneWidget);
      expect(find.text(tank.id), findsNothing);
      expect(repository.commands, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inspection filters expose submitted checklist evidence and provenance',
    (tester) async {
      final repository = managerScenario(
        (e) => e.submissions.values.any(
          (s) => s.answers.values.any((a) => a.choice == AnswerChoice.yes),
        ),
      );
      final submission = repository.engine.submissions.values.firstWhere(
        (s) => s.answers.values.any((a) => a.choice == AnswerChoice.yes),
      );
      final controller = await openManagerScreen(
        tester,
        repository,
        3,
        facilityId: submission.scope.facilityId,
      );
      await managerTap(tester, managerChip('Risk observed'));
      expect(
        find.byType(ManagerRecordTile),
        findsNWidgets(
          controller.workspace!.inspections.where((i) => i.hasRisk).length,
        ),
      );
      await managerTap(
        tester,
        find.byKey(ValueKey('inspection-${submission.taskId}')),
      );
      final template = controller.workspace!.template(submission.templateId)!;
      expect(find.text(submission.taskId), findsOneWidget);
      expect(find.text(template.source), findsOneWidget);
      for (final question in template.questions) {
        expect(find.text(question.label), findsOneWidget);
        expect(find.text(question.sourceId), findsWidgets);
      }
      expect(find.text('Observed on device'), findsOneWidget);
      expect(find.text('Received by service'), findsOneWidget);
      expect(
        find.text(
          'An inspection is a risk-control record, not a laboratory result.',
        ),
        findsOneWidget,
      );
      expect(repository.commands, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'samples publish only a reviewed record after a reason and refresh',
    (tester) async {
      final repository = managerScenario(
        (e) => e.results.values.any((r) => r.state == ResultState.reviewed),
      );
      final record = repository.engine.results.values.firstWhere(
        (r) => r.state == ResultState.reviewed,
      );
      final controller = await openManagerScreen(
        tester,
        repository,
        4,
        facilityId: record.sample.scope.facilityId,
      );
      await managerTap(tester, managerChip('Reviewed'));
      await tester.enterText(
        managerField('Search sample codes or points'),
        record.sample.code,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ManagerRecordTile), findsOneWidget);
      await managerTap(
        tester,
        find.byKey(ValueKey('sample-${record.sample.id}')),
      );
      expect(find.text('Simulated lab review'), findsOneWidget);
      expect(find.text(record.measurement!.method), findsWidgets);
      expect(find.text(record.reportRef!), findsOneWidget);
      expect(find.text('Custody'), findsOneWidget);
      await managerTap(tester, find.text('Publish reviewed result'));
      await managerTap(tester, find.text('Publish result'));
      expect(find.text('Required'), findsOneWidget);
      expect(repository.commands, isEmpty);
      await tester.enterText(
        managerField('Reason'),
        'Reviewed scope, date and linked report',
      );
      await managerTap(tester, find.text('Publish result'));
      expect(repository.commands.single.id, record.id);
      expect(repository.commands.single.version, record.version);
      expect(
        repository.engine.results[record.id]!.state,
        ResultState.published,
      );
      expect(
        controller.workspace!.currentResult(record.sample.id)!.publishedAt,
        repository.engine.now,
      );
      expect(
        find.textContaining(
          'Simulated action recorded: Reviewed result published.',
        ),
        findsOneWidget,
      );
      expect(find.text('Publish reviewed result'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final state in [ResultState.rejected, ResultState.superseded]) {
    testWidgets(
      'samples retain ${state.name} evidence without a publication action',
      (tester) async {
        final repository = managerScenario(
          (e) => e.results.values.any(
            (r) =>
                r.state ==
                (state == ResultState.superseded
                    ? ResultState.published
                    : state),
          ),
        );
        if (state == ResultState.superseded) {
          final original = repository.engine.results.values.firstWhere(
            (r) => r.state == ResultState.published,
          );
          final correction = original.correct(
            newId: 'manager-test-result-revision',
            reading: original.measurement!,
            linkedReport: 'simulation://corrected-report',
            context: CommandContext(
              actor: repository.engine.actorFor(
                original.sample.scope,
                Role.lab,
              ),
              at: repository.engine.now,
              eventId: 'manager-test-correction',
              serverConfirmed: true,
              reason: 'Simulated report-reference correction',
            ),
          );
          repository.engine.results[original.id] = correction.original;
          repository.engine.results[correction.replacement.id] =
              correction.replacement;
        }
        final record = repository.engine.results.values.firstWhere(
          (r) => r.state == state,
        );
        await openManagerScreen(
          tester,
          repository,
          4,
          facilityId: record.sample.scope.facilityId,
        );
        await managerTap(
          tester,
          managerChip(state == ResultState.rejected ? 'Rejected' : 'Revisions'),
        );
        await managerTap(
          tester,
          find.byKey(ValueKey('sample-${record.sample.id}')),
        );
        if (state == ResultState.superseded) {
          await managerTap(
            tester,
            find.byType(DropdownButtonFormField<String>),
          );
          await managerTap(
            tester,
            find.text('${record.id.substring(0, 8)} · Superseded').last,
          );
        }
        expect(
          find.text(
            state == ResultState.rejected
                ? 'No valid result from this sample.'
                : 'Superseded result',
          ),
          findsOneWidget,
        );
        expect(find.text(record.id), findsOneWidget);
        expect(find.text('Publish reviewed result'), findsNothing);
        expect(repository.commands, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'QR revocation is confirmed, audited and retains its point identity',
    (tester) async {
      final repository = TestManagerRepository(connected: false);
      final controller = await openManagerScreen(tester, repository, 1);
      final qr = controller.workspace!.qrs.firstWhere(
        (q) => q.revokedAt == null,
      );
      final point = controller.workspace!.point(qr.pointId)!;
      await managerTap(tester, find.byKey(ValueKey('asset-${point.assetId}')));
      await managerTap(tester, find.text('Revoke QR').first);
      await managerTap(tester, find.widgetWithText(FilledButton, 'Revoke QR'));
      expect(find.text('Required'), findsOneWidget);
      expect(repository.commands, isEmpty);
      await tester.enterText(
        managerField('Reason'),
        'Printed code damaged; retain original identity',
      );
      await managerTap(tester, find.widgetWithText(FilledButton, 'Revoke QR'));
      expect(repository.commands.single.id, qr.token);
      final updated = repository.engine.qrs.singleWhere(
        (q) => q.token == qr.token,
      );
      expect(updated.pointId, point.id);
      expect(updated.revokedAt, repository.engine.now);
      expect(
        controller.workspace!.auditFor(qr.token).last.reason,
        contains('Printed code damaged'),
      );
      expect(find.text('Revoked QR identity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'team shows the selected member assignments and filters real access status',
    (tester) async {
      final repository = TestManagerRepository(connected: false);
      final scope = repository.engine.workOrders.values.first.scope;
      final labIndex = repository.engine.actors.indexWhere(
        (a) => a.scope.matches(scope) && a.role == Role.lab,
      );
      final lab = repository.engine.actors[labIndex];
      repository.engine.actors[labIndex] = Actor(
        id: lab.id,
        role: lab.role,
        scope: lab.scope,
        expiresAt: managerNow.subtract(const Duration(seconds: 1)),
      );
      final controller = await openManagerScreen(
        tester,
        repository,
        7,
        facilityId: scope.facilityId,
      );
      expect(find.text('Expired'), findsOneWidget);
      await managerTap(tester, managerChip('Active only'));
      expect(find.text('Expired'), findsNothing);
      await managerTap(tester, managerChip('Field'));
      final member = controller.workspace!.members.singleWhere(
        (m) => m.role == Role.field,
      );
      expect(find.byType(ManagerRecordTile), findsOneWidget);
      await managerTap(tester, find.byKey(ValueKey('member-${member.id}')));
      expect(find.text(member.userId), findsWidgets);
      expect(find.text('Assigned inspections'), findsOneWidget);
      expect(find.text('Assigned work'), findsOneWidget);
      for (final order in controller.workspace!.orders.where(
        (w) =>
            w.assigneeId == member.userId && w.state != WorkOrderState.accepted,
      )) {
        expect(find.byKey(ValueKey('work-order-${order.id}')), findsOneWidget);
      }
      expect(repository.commands, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'triage and owner assignment validate required fields and deadlines',
    (tester) async {
      final repository = managerScenario(
        (e) => e.incidents.values.any((i) => i.state == IncidentState.reported),
      );
      final incident = repository.engine.incidents.values.firstWhere(
        (i) => i.state == IncidentState.reported,
      );
      final controller = await openManagerScreen(
        tester,
        repository,
        2,
        facilityId: incident.scope.facilityId,
      );
      await managerTap(tester, find.text('Triage').first);
      await managerTap(tester, find.text('Record triage'));
      expect(find.text('Required'), findsNWidgets(3));
      expect(repository.commands, isEmpty);
      await managerTap(tester, find.byType(DropdownButtonFormField<Priority>));
      await managerTap(tester, find.text('Critical').last);
      await tester.enterText(
        managerField('Scope and uncertainty'),
        'Single point; scope under investigation',
      );
      await tester.enterText(
        managerField('Reason'),
        'Review the recorded concern',
      );
      await managerTap(tester, find.text('Record triage'));
      expect(
        repository.engine.incidents[incident.id]!.priority,
        Priority.critical,
      );
      expect(
        controller.workspace!.incidents
            .firstWhere((i) => i.id == incident.id)
            .state,
        IncidentState.triaged,
      );
      await managerTap(tester, find.text('Assign owner').first);
      await managerTap(tester, find.text('Confirm assignment'));
      expect(
        find.text('Enter a future date in YYYY-MM-DD format'),
        findsOneWidget,
      );
      expect(repository.commands.length, 1);
      final member = controller.workspace!.members.firstWhere(
        (m) => m.role == Role.field,
      );
      await managerTap(tester, find.byType(DropdownButtonFormField<String>));
      await managerTap(tester, find.text('Field · ${member.userId}').last);
      await tester.enterText(
        managerField('Deadline (UTC, YYYY-MM-DD)'),
        '2026-02-30',
      );
      await tester.enterText(
        managerField('Required response'),
        'Inspect the affected point and document evidence',
      );
      await tester.enterText(
        managerField('Reason'),
        'Assign an accountable field responder',
      );
      await managerTap(tester, find.text('Confirm assignment'));
      expect(
        find.text('Enter a future date in YYYY-MM-DD format'),
        findsOneWidget,
      );
      expect(repository.commands.length, 1);
      await tester.enterText(
        managerField('Deadline (UTC, YYYY-MM-DD)'),
        '2026-12-01',
      );
      await managerTap(tester, find.text('Confirm assignment'));
      final assigned = repository.engine.incidents[incident.id]!;
      expect(assigned.ownerId, member.userId);
      expect(assigned.dueAt, DateTime.utc(2026, 12, 1));
      expect(
        assigned.requiredResponse,
        'Inspect the affected point and document evidence',
      );
      expect(repository.commands.last.version, incident.version + 1);
      await managerTap(tester, find.text('Escalate internally').first);
      expect(
        find.textContaining('does not contact an external authority'),
        findsOneWidget,
      );
      await tester.enterText(
        managerField('Reason'),
        'Critical concern requires internal review',
      );
      await managerTap(tester, find.text('Confirm'));
      expect(
        repository.engine.incidents[incident.id]!.escalatedAt,
        repository.engine.now,
      );
      expect(repository.commands.last.action, 'escalate');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'work approval restricts assignees to field members and preserves incident state',
    (tester) async {
      final repository = managerScenario((e) => e.incidents.isNotEmpty);
      final incident = repository.engine.incidents.values.first;
      final field = repository.engine.actorFor(incident.scope, Role.field);
      final order =
          WorkOrder.propose(
            id: 'manager-test-proposed-work',
            scope: incident.scope,
            incidentId: incident.id,
            task: 'Review tank cover evidence',
            isSimulated: true,
          ).transition(
            WorkOrderState.approvalPending,
            CommandContext(
              actor: field,
              at: repository.engine.now,
              eventId: 'manager-test-work-request',
              serverConfirmed: true,
              reason: 'Simulated request',
            ),
          );
      repository.engine.workOrders[order.id] = order;
      await openManagerScreen(
        tester,
        repository,
        5,
        facilityId: incident.scope.facilityId,
      );
      await managerTap(tester, find.text('Approve and assign'));
      final picker = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(picker.items!.map((i) => i.value), [field.id]);
      await managerTap(tester, find.byType(DropdownButtonFormField<String>));
      await managerTap(tester, find.text('Field · ${field.id}').last);
      await tester.enterText(
        managerField('Deadline (UTC, YYYY-MM-DD)'),
        '2026-12-01',
      );
      await tester.enterText(
        managerField('Reason'),
        'Authorize scoped maintenance',
      );
      await managerTap(tester, find.text('Confirm assignment'));
      expect(repository.engine.workOrders[order.id]!.assigneeId, field.id);
      expect(
        repository.engine.workOrders[order.id]!.state,
        WorkOrderState.assigned,
      );
      expect(repository.engine.incidents[incident.id], same(incident));
      expect(repository.commands.single.version, order.version);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accepting completion evidence leaves verification outstanding', (
    tester,
  ) async {
    final repository = managerScenario(
      (e) =>
          e.workOrders.values.any((w) => w.state == WorkOrderState.completed),
    );
    final order = repository.engine.workOrders.values.firstWhere(
      (w) => w.state == WorkOrderState.completed,
    );
    final incident = repository.engine.incidents[order.incidentId]!;
    await openManagerScreen(
      tester,
      repository,
      5,
      facilityId: order.scope.facilityId,
    );
    await managerTap(
      tester,
      find.descendant(
        of: find.byKey(ValueKey('work-order-${order.id}')),
        matching: find.text('Accept evidence'),
      ),
    );
    expect(find.text(order.completionEvidence!), findsWidgets);
    await tester.enterText(
      managerField('Reason'),
      'Completion evidence reviewed',
    );
    await managerTap(tester, find.text('Confirm'));
    expect(
      repository.engine.workOrders[order.id]!.state,
      WorkOrderState.accepted,
    );
    expect(repository.engine.incidents[order.incidentId], same(incident));
    expect(
      find.textContaining('Incident verification remains separate.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'interim measures require approved work and record its real reference',
    (tester) async {
      final repository = managerScenario(
        (e) => e.incidents.values.any((i) => i.state == IncidentState.assigned),
      );
      final incident = repository.engine.incidents.values.firstWhere(
        (i) => i.state == IncidentState.assigned,
      );
      final order = repository.engine.workOrders.values.firstWhere(
        (w) => w.incidentId == incident.id,
      );
      await openManagerScreen(
        tester,
        repository,
        2,
        facilityId: incident.scope.facilityId,
      );
      await managerTap(
        tester,
        find.descendant(
          of: find.byKey(ValueKey('incident-${incident.id}')),
          matching: find.text('Record interim measure'),
        ),
      );
      await tester.enterText(
        managerField('Reason'),
        'Approved work started; concern remains open',
      );
      await managerTap(tester, find.text('Confirm'));
      expect(
        repository.engine.incidents[incident.id]!.state,
        IncidentState.mitigation,
      );
      expect(
        repository.engine.incidents[incident.id]!.actionEvidence,
        order.id,
      );
      expect(repository.engine.incidents[incident.id]!.resolvedAt, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'verification records original method and controls without resolving the incident',
    (tester) async {
      final repository = managerScenario(
        (e) => e.workOrders.values.any(
          (w) =>
              w.state == WorkOrderState.accepted &&
              e.incidents[w.incidentId]!.state == IncidentState.mitigation &&
              e.incidents[w.incidentId]!.source == EvidenceSource.laboratory,
        ),
      );
      final order = repository.engine.workOrders.values.firstWhere(
        (w) =>
            w.state == WorkOrderState.accepted &&
            repository.engine.incidents[w.incidentId]!.state ==
                IncidentState.mitigation &&
            repository.engine.incidents[w.incidentId]!.source ==
                EvidenceSource.laboratory,
      );
      final incident = repository.engine.incidents[order.incidentId]!;
      final original =
          repository.engine.results[incident.sourceId]!.measurement!;
      final controller = await openManagerScreen(
        tester,
        repository,
        2,
        facilityId: incident.scope.facilityId,
      );
      await managerTap(
        tester,
        find.descendant(
          of: find.byKey(ValueKey('incident-${incident.id}')),
          matching: find.text('Request verification'),
        ),
      );
      expect(
        find.text('${original.indicator.label} · ${original.method}'),
        findsOneWidget,
      );
      await managerTap(tester, find.text('Save plan and request verification'));
      expect(
        find.text('Review interim controls before continuing'),
        findsOneWidget,
      );
      expect(
        find.text('Review the public notice before continuing'),
        findsOneWidget,
      );
      expect(repository.commands, isEmpty);
      await managerTap(tester, find.text('Interim controls reviewed'));
      await managerTap(tester, find.text('Public notice reviewed'));
      await tester.enterText(
        managerField('Reviewed notice reference'),
        'simulation://reviewed-notice',
      );
      await tester.enterText(
        managerField('Reason'),
        'Accepted work and notice reviewed; request follow-up',
      );
      await managerTap(tester, find.text('Save plan and request verification'));
      final updated = repository.engine.incidents[incident.id]!;
      expect(updated.state, IncidentState.verificationPending);
      expect(updated.plan!.pointIds, incident.pointIds);
      expect(updated.plan!.method, original.method);
      expect(updated.plan!.indicator, original.indicator);
      expect(updated.resolvedAt, isNull);
      expect(
        controller.workspace!.incidents
            .firstWhere((i) => i.id == incident.id)
            .requirements,
        isNotEmpty,
      );
      expect(find.text('Recorded verification requirements'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
