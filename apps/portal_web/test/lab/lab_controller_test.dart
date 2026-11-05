import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/lab/lab_controller.dart';
import 'lab_test_support.dart';

void main() {
  test(
    'lost acknowledgement can be retried after the server record advances',
    () async {
      final data = await generatedLabWorkspace(state: ResultState.tested);
      final record = data.records.firstWhere(
        (r) => r.state == ResultState.tested,
      );
      final repository = TestLabRepository(data);
      final controller = LabController(repository, clock: () => labNow);
      addTearDown(controller.dispose);
      await controller.refresh();
      repository.onSubmit = (_) async => throw const LabConnectionFailure();
      final result = await controller.submit(
        record: record,
        expectedVersion: record.version,
        action: LabAction.attest,
        payload: {'report_ref': 'simulation://signed-report'},
        reason: 'Authorized review',
      );
      expect(result, isNull);
      expect(controller.receipt, isNull);
      expect(
        controller.workspace!.record(record.id)!.state,
        ResultState.tested,
      );
      expect(controller.phase, LabPhase.offline);
      expect(controller.hasPendingCommand, true);
      repository.workspace = await generatedLabWorkspace(
        state: ResultState.published,
        recordId: record.id,
      );
      await controller.refresh();
      expect(
        controller.canWrite,
        false,
        reason: 'Resolve the uncertain action before starting another.',
      );
      expect(controller.canRetry, true);
      repository.onSubmit = (command) async => testReceipt(command, data);
      final receipt = await controller.retryPending();
      expect(repository.commands.length, 2);
      expect(repository.commands.last, same(repository.commands.first));
      expect(receipt!.eventId, repository.commands.first.eventId);
      expect(controller.receipt, same(receipt));
      expect(
        controller.workspace!.record(record.id)!.state,
        ResultState.published,
      );
      expect(controller.hasPendingCommand, false);
    },
  );

  test(
    'permission failure clears records, draft command and receipt',
    () async {
      final data = await generatedLabWorkspace();
      final repository = TestLabRepository(data);
      final controller = LabController(repository, clock: () => labNow);
      addTearDown(controller.dispose);
      await controller.refresh();
      repository.onSubmit = (_) async =>
          throw const RepositoryFailure(FailureKind.permission, 'Revoked');
      final record = data.records.first;
      await controller.submit(
        record: record,
        expectedVersion: record.version,
        action: LabAction.correct,
        payload: {},
        reason: 'Correction',
      );
      expect(controller.phase, LabPhase.permissionDenied);
      expect(controller.workspace, isNull);
      expect(controller.receipt, isNull);
      expect(controller.hasPendingCommand, false);
      expect(controller.busy, false);
    },
  );

  test(
    'a stale version requires a refresh and never changes cached evidence',
    () async {
      final data = await generatedLabWorkspace();
      final repository = TestLabRepository(data);
      final controller = LabController(repository, clock: () => labNow);
      addTearDown(controller.dispose);
      await controller.refresh();
      repository.onSubmit = (_) async => throw const RepositoryFailure(
        FailureKind.conflict,
        'Changed on server',
      );
      final record = data.records.first;
      await controller.submit(
        record: record,
        expectedVersion: record.version,
        action: LabAction.correct,
        payload: {},
        reason: 'Correction',
      );
      expect(controller.phase, LabPhase.stale);
      expect(controller.workspace, same(data));
      expect(controller.receipt, isNull);
      expect(controller.hasPendingCommand, false);
      expect(controller.canWrite, false);
    },
  );

  test('session invalidation discards an in-flight private snapshot', () async {
    final repository = TestLabRepository(await generatedLabWorkspace());
    final pending = Completer<LabWorkspace>();
    repository.onLoad = (_) => pending.future;
    final controller = LabController(repository, clock: () => labNow);
    addTearDown(controller.dispose);
    final refresh = controller.refresh();
    controller.sessionChanged();
    pending.complete(repository.workspace);
    await refresh;
    expect(controller.phase, LabPhase.permissionDenied);
    expect(controller.workspace, isNull);
    expect(controller.refreshing, false);
  });

  test('only the newest facility read can populate the workspace', () async {
    final simulation = SimulationLabRepository(clock: () => labNow);
    final first = await simulation.load();
    final second = await simulation.load(facilityId: first.facilities.last.id);
    final repository = TestLabRepository(first);
    final oldRead = Completer<LabWorkspace>();
    repository.onLoad = (id) =>
        id == second.facility.id ? Future.value(second) : oldRead.future;
    final controller = LabController(repository, clock: () => labNow);
    addTearDown(controller.dispose);
    final pending = controller.refresh();
    await controller.refresh(facilityId: second.facility.id);
    oldRead.complete(first);
    await pending;
    expect(controller.workspace, same(second));
    expect(controller.refreshing, false);
  });

  test(
    'a concurrent refresh cannot discard a confirmed command receipt',
    () async {
      final data = await generatedLabWorkspace(state: ResultState.tested);
      final record = data.records.firstWhere(
        (r) => r.state == ResultState.tested,
      );
      final repository = TestLabRepository(data);
      final controller = LabController(repository, clock: () => labNow);
      addTearDown(controller.dispose);
      await controller.refresh();
      final ack = Completer<LabReceipt>();
      repository.onSubmit = (_) => ack.future;
      final submit = controller.submit(
        record: record,
        expectedVersion: record.version,
        action: LabAction.attest,
        payload: {'report_ref': 'simulation://signed-report'},
        reason: 'Simulated authorized review',
      );
      await controller.refresh();
      ack.complete(testReceipt(repository.commands.single, data));
      expect(await submit, isNotNull);
      expect(controller.receipt, isNotNull);
      expect(controller.busy, false);
    },
  );

  test(
    'an old session completion cannot unlock a new session command',
    () async {
      final data = await generatedLabWorkspace(state: ResultState.tested);
      final record = data.records.firstWhere(
        (r) => r.state == ResultState.tested,
      );
      final repository = TestLabRepository(data);
      final controller = LabController(repository, clock: () => labNow);
      addTearDown(controller.dispose);
      await controller.refresh();
      final oldAck = Completer<LabReceipt>();
      final newAck = Completer<LabReceipt>();
      repository.onSubmit = (_) => oldAck.future;
      Future<LabReceipt?> send() => controller.submit(
        record: record,
        expectedVersion: record.version,
        action: LabAction.attest,
        payload: {'report_ref': 'simulation://signed-report'},
        reason: 'Simulated authorized review',
      );
      final oldSubmit = send();
      controller.sessionChanged();
      await controller.refresh();
      repository.onSubmit = (_) => newAck.future;
      final newSubmit = send();
      oldAck.complete(testReceipt(repository.commands.first, data));
      expect(await oldSubmit, isNull);
      expect(controller.busy, true);
      expect(controller.receipt, isNull);
      newAck.complete(testReceipt(repository.commands.last, data));
      expect(await newSubmit, isNotNull);
      expect(controller.receipt!.eventId, repository.commands.last.eventId);
    },
  );
}
