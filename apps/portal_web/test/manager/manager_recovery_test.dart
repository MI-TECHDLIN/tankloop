import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/manager_controller.dart';
import 'package:tankloop_portal/manager_dashboard.dart';
import 'manager_test_support.dart';

void main() {
  testWidgets(
    'a dialog opened on an old snapshot cannot publish after refresh',
    (tester) async {
      final repository = managerScenario(
        (e) => e.results.values.any((r) => r.state == ResultState.reviewed),
      );
      final result = repository.engine.results.values.firstWhere(
        (r) => r.state == ResultState.reviewed,
      );
      final controller = await openManagerScreen(
        tester,
        repository,
        4,
        facilityId: result.sample.scope.facilityId,
      );
      await managerTap(
        tester,
        find.byKey(ValueKey('sample-${result.sample.id}')),
      );
      await managerTap(tester, find.text('Publish reviewed result'));
      await tester.enterText(
        managerField('Reason'),
        'Review completed before concurrent refresh',
      );
      await controller.refresh();
      await tester.pumpAndSettle();
      await managerTap(tester, find.text('Publish result'));
      expect(repository.commands, isEmpty);
      expect(repository.engine.results[result.id], same(result));
      expect(
        find.textContaining('records changed while this action was open'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid command feedback still expires to the stale read-only state',
    (tester) async {
      var now = managerNow;
      final repository = TestManagerRepository(clock: () => now);
      final controller = ManagerController(repository, clock: () => now);
      await controller.refresh();
      await tester.pumpWidget(
        managerTestApp(managerScreen(2, controller), controller: controller),
      );
      await controller.act(
        () async => throw const RepositoryFailure(
          FailureKind.invalid,
          'Review the response requirements.',
        ),
        'Unused confirmation',
        basedOn: controller.workspace!,
      );
      await tester.pumpAndSettle();
      expect(controller.canWrite, true);
      now = now.add(const Duration(minutes: 6));
      await tester.pump(const Duration(minutes: 6));
      await tester.pumpAndSettle();
      expect(find.text('Stale data'), findsOneWidget);
      expect(controller.canWrite, false);
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
    },
  );

  testWidgets(
    'offline exercise is visibly read-only and refresh reconnects it',
    (tester) async {
      final repository = TestManagerRepository(connected: false);
      final controller = await openManagerScreen(tester, repository, 4);
      final cached = controller.workspace!;
      await controller.setOfflineExercise(true);
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      expect(controller.workspace, same(cached));
      expect(controller.canWrite, false);
      await managerTap(tester, find.text('Refresh records'));
      expect(controller.offlineExercise, false);
      expect(controller.canWrite, true);
      expect(find.text('Offline'), findsNothing);
    },
  );

  testWidgets(
    'changing facility clears the selected record while the new scope loads',
    (tester) async {
      final repository = TestManagerRepository(clock: DateTime.now);
      final first = await repository.load();
      final second = await repository.load(
        facilityId: first.facilities
            .firstWhere((f) => f.id != first.facility.id)
            .id,
      );
      final pending = Completer<ManagerWorkspace>();
      repository.onLoad = (id) =>
          id == second.facility.id ? pending.future : Future.value(first);
      await tester.pumpWidget(
        MaterialApp(
          theme: tankLoopTheme(),
          home: ManagerDashboard(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await managerTap(tester, find.byType(DropdownButtonFormField<int>));
      await managerTap(tester, find.text('Facilities').last);
      await managerTap(
        tester,
        find.byKey(ValueKey('asset-${first.assets.first.id}')),
      );
      expect(find.text(first.assets.first.id), findsOneWidget);
      await managerTap(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text(second.facility.label).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(first.assets.first.id), findsNothing);
      expect(find.text('Manager workspace'), findsOneWidget);
      expect(find.byType(FrostedSkeleton), findsWidgets);
      pending.complete(second);
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('asset-${second.assets.first.id}')),
        findsOneWidget,
      );
      expect(find.text('Back to list'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('only the latest scope response can populate the controller', () async {
    final repository = TestManagerRepository();
    final first = await repository.load();
    final second = await repository.load(
      facilityId: first.facilities
          .firstWhere((f) => f.id != first.facility.id)
          .id,
    );
    final oldRead = Completer<ManagerWorkspace>();
    repository.onLoad = (id) =>
        id == second.facility.id ? Future.value(second) : oldRead.future;
    final controller = ManagerController(repository, clock: () => managerNow);
    addTearDown(controller.dispose);
    final old = controller.refresh();
    await controller.refresh(facilityId: second.facility.id);
    oldRead.complete(first);
    await old;
    expect(controller.workspace, same(second));
    expect(controller.refreshing, false);
    expect(controller.canWrite, true);
  });

  test(
    'session loss discards pending private data and confirmation messages',
    () async {
      final repository = TestManagerRepository();
      final data = await repository.load();
      final pending = Completer<ManagerWorkspace>();
      repository.onLoad = (_) => pending.future;
      final controller = ManagerController(repository, clock: () => managerNow);
      addTearDown(controller.dispose);
      final refresh = controller.refresh();
      controller.sessionChanged();
      pending.complete(data);
      await refresh;
      expect(controller.workspace, isNull);
      expect(controller.phase, ManagerViewState.denied);
      expect(controller.refreshing, false);
      expect(controller.actionMessage, isNull);
    },
  );

  test('old account completion cannot unlock a new account action', () async {
    final repository = TestManagerRepository();
    final controller = ManagerController(repository, clock: () => managerNow);
    addTearDown(controller.dispose);
    await controller.refresh();
    final oldAck = Completer<int>();
    final newAck = Completer<int>();
    final old = controller.act(
      () => oldAck.future,
      'Old account action',
      basedOn: controller.workspace!,
    );
    controller.sessionChanged();
    await controller.refresh();
    final next = controller.act(
      () => newAck.future,
      'Current account action',
      basedOn: controller.workspace!,
    );
    oldAck.complete(1);
    expect(await old, false);
    expect(controller.busy, true);
    expect(controller.actionMessage, isNull);
    newAck.complete(2);
    expect(await next, true);
    expect(controller.busy, false);
    expect(controller.actionMessage, contains('Current account action'));
  });

  test(
    'lost acknowledgement requires a fresh version and never repeats automatically',
    () async {
      final repository = managerScenario(
        (e) => e.results.values.any((r) => r.state == ResultState.reviewed),
      );
      final record = repository.engine.results.values.firstWhere(
        (r) => r.state == ResultState.reviewed,
      );
      final controller = ManagerController(repository, clock: () => managerNow);
      addTearDown(controller.dispose);
      await controller.refresh(facilityId: record.sample.scope.facilityId);
      final cached = controller.workspace!;
      var attempts = 0;
      final confirmed = await controller.act(
        () async {
          attempts++;
          await repository.publishResult(
            id: record.id,
            expectedVersion: record.version,
            reason: 'Simulated publication',
          );
          throw const ManagerConnectionFailure();
        },
        'Published',
        basedOn: cached,
      );
      expect(confirmed, false);
      expect(controller.phase, ManagerViewState.offline);
      expect(controller.workspace, same(cached));
      expect(
        cached.currentResult(record.sample.id)!.state,
        ResultState.reviewed,
      );
      expect(controller.actionMessage, isNot(contains('acknowledged')));
      await controller.refresh();
      expect(
        controller.workspace!.currentResult(record.sample.id)!.state,
        ResultState.published,
      );
      expect(attempts, 1);
      expect(repository.commands.length, 1);
    },
  );

  test(
    'conflict and permission failures retain or clear records appropriately',
    () async {
      final repository = TestManagerRepository();
      final controller = ManagerController(repository, clock: () => managerNow);
      addTearDown(controller.dispose);
      await controller.refresh();
      final cached = controller.workspace!;
      await controller.act(
        () async => throw const RepositoryFailure(
          FailureKind.conflict,
          'Changed on server',
        ),
        'Unused',
        basedOn: cached,
      );
      expect(controller.workspace, same(cached));
      expect(controller.phase, ManagerViewState.stale);
      expect(controller.canWrite, false);
      await controller.refresh();
      await controller.act(
        () async => throw const RepositoryFailure(
          FailureKind.permission,
          'Membership revoked',
        ),
        'Unused',
        basedOn: controller.workspace!,
      );
      expect(controller.phase, ManagerViewState.denied);
      expect(controller.workspace, isNull);
      expect(controller.actionMessage, isNull);
      expect(controller.busy, false);
    },
  );
}
