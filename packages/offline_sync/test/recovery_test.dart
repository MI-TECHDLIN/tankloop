import '../../data/test/support/fixture_repository.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

class PowerLossStore implements KeyValueStore {
  PowerLossStore(this.inner);
  final KeyValueStore inner;
  bool powered = true;
  @override
  Future<String?> read(String key) => inner.read(key);
  @override
  Future<void> write(String key, String value) {
    if (!powered) throw StateError('Process lost power before durable write');
    return inner.write(key, value);
  }

  @override
  Future<void> remove(String key) => inner.remove(key);
  @override
  Future<void> close() => inner.close();
}

class PhotoServer implements TankLoopRepository, EvidenceUploader {
  PhotoServer(this.inner, this.storage);
  final TankLoopRepository inner;
  final PowerLossStore storage;
  bool losePower = true;
  final objects = <String, Uint8List>{};
  int uploads = 0;
  @override
  Future<String> uploadEvidence(
    InspectionEvidence evidence, {
    Uint8List? bytes,
  }) async {
    uploads++;
    objects.putIfAbsent(evidence.id, () => bytes!);
    if (losePower) {
      storage.powered = false;
      losePower = false;
    }
    return 'private/${evidence.id}.jpg';
  }

  @override
  Future<DashboardSnapshot> today() => inner.today();
  @override
  Future<PublicWaterRecord?> publicRecord(String token) =>
      inner.publicRecord(token);
  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) =>
      inner.submitInspection(command);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'battery death after photo upload recovers bytes and the same event from Drift',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tankloop-power-loss-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/field.sqlite');
      final database = PowerLossStore(
        SqliteKeyValueStore(NativeDatabase(file)),
      );
      final repository = FixtureRepository();
      final data = await repository.today();
      final task = data.inspections.firstWhere((t) => !t.isSubmitted);
      final template = data.templateFor(task);
      var outbox = InspectionOutbox(
        store: database,
        namespace: 'inspector',
        scope: data.scope,
      );
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final photo = await outbox.photos.save(
        id: 'photo',
        bytes: bytes,
        capturedAt: data.asOf,
        questionId: template.questions.first.id,
      );
      await outbox.save(
        task: task,
        answers: {
          for (final q in template.questions)
            q.id: const InspectionAnswer(AnswerChoice.yes),
        },
        notes: 'Observed risk, not a lab finding',
        observedAt: data.asOf,
        evidence: [photo],
      );
      await outbox.enqueue(task.id, template);
      final eventId = outbox.entries.single.command.clientEventId;
      final server = PhotoServer(repository, database);
      await expectLater(outbox.sync(server, online: true), throwsStateError);
      outbox.dispose();
      await database.close();
      final reopened = SqliteKeyValueStore(NativeDatabase(file));
      addTearDown(reopened.close);
      outbox = InspectionOutbox(
        store: reopened,
        namespace: 'inspector',
        scope: data.scope,
      );
      addTearDown(outbox.dispose);
      await outbox.load();
      expect(outbox.entries.single.command.clientEventId, eventId);
      expect(outbox.entries.single.state, DraftState.pending);
      expect(
        outbox.entries.single.command.evidence.single.uploadedPath,
        isNull,
      );
      expect(await outbox.photos.read(photo), bytes);
      await outbox.sync(server, online: true, retryNow: true);
      expect(outbox.entries.single.state, DraftState.synced);
      expect(
        server.objects.length,
        1,
        reason: 'An interrupted upload retries the same storage identity',
      );
      expect(server.uploads, 2);
      expect(outbox.entries.single.receipt!.clientEventId, eventId);
      await outbox.clear();
      expect(await reopened.read('photo:inspector:photo'), isNull);
    },
  );

  test(
    'airplane mode never invokes network; double tap preserves one command',
    () async {
      final repo = FixtureRepository();
      final data = await repo.today();
      final outbox = InspectionOutbox(
        store: MemoryKeyValueStore(),
        namespace: 'field',
        scope: data.scope,
      );
      addTearDown(outbox.dispose);
      final task = data.inspections.firstWhere((t) => !t.isSubmitted);
      final template = data.templateFor(task);
      await outbox.save(
        task: task,
        answers: {
          for (final q in template.questions)
            q.id: const InspectionAnswer(AnswerChoice.unknown),
        },
        notes: '',
        observedAt: data.asOf,
      );
      await Future.wait([
        outbox.enqueue(task.id, template),
        outbox.enqueue(task.id, template),
      ]);
      await outbox.sync(repo, online: false);
      expect(outbox.entries.single.attempts, 0);
      expect(repo.engine.inspections[task.id]!.isSubmitted, isFalse);
      await Future.wait([
        outbox.sync(repo, online: true),
        outbox.sync(repo, online: true),
      ]);
      expect(outbox.entries.single.attempts, 1);
      expect(outbox.entries.single.receipt!.version, task.version + 1);
    },
  );

  test(
    'revoked QR never opens even when the downloaded point still has its old token',
    () async {
      final repo = FixtureRepository();
      final data = await repo.today();
      final token = data.publicTokens.values.first;
      final original = repo.engine.qrs.firstWhere((q) => q.token == token);
      expect(
        (await resolveFieldQr(
          'https://tankloop.example/#/point/$token?seed=1',
          repository: repo,
          dashboard: data,
          online: true,
        )).id,
        original.pointId,
      );
      final index = repo.engine.qrs.indexOf(original);
      repo.engine.qrs[index] = original.revoke(
        CommandContext(
          actor: repo.engine.actorFor(original.scope, Role.manager),
          at: repo.engine.now,
          eventId: 'revoke-for-test',
          serverConfirmed: true,
          reason: 'Label replaced',
        ),
      );
      await expectLater(
        resolveFieldQr(token, repository: repo, dashboard: data, online: true),
        throwsA(
          isA<RepositoryFailure>().having(
            (e) => e.message,
            'reason',
            contains('revoked'),
          ),
        ),
      );
      await expectLater(
        resolveFieldQr(token, repository: repo, dashboard: data, online: false),
        throwsA(
          isA<RepositoryFailure>().having(
            (e) => e.message,
            'reason',
            contains('Connect'),
          ),
        ),
      );
      expect(() => parsePointToken('not-a-point'), throwsFormatException);
    },
  );

  test(
    'work steps survive Drift restart and get one receipt after retry',
    () async {
      final repo = FixtureRepository();
      final data = await repo.today();
      final actor = repo.engine.actorFor(data.scope, Role.field);
      final manager = repo.engine.actorFor(data.scope, Role.manager);
      var assigned = WorkOrder.propose(
        id: 'recovery-work',
        scope: data.scope,
        incidentId: 'recovery-case',
        task: 'Inspect lid',
        isSimulated: true,
      );
      assigned = assigned.transition(
        WorkOrderState.approvalPending,
        CommandContext(
          actor: manager,
          at: repo.engine.now,
          eventId: 'propose',
          reason: 'Fixture',
          serverConfirmed: true,
        ),
      );
      assigned = assigned.transition(
        WorkOrderState.assigned,
        CommandContext(
          actor: manager,
          at: repo.engine.now,
          eventId: 'assign',
          reason: 'Fixture',
          serverConfirmed: true,
        ),
        assignee: actor.id,
        deadline: repo.engine.now.add(const Duration(days: 1)),
      );
      repo.engine.workOrders[assigned.id] = assigned;
      final current = FieldWorkOrder.fromJson(
        Map<String, dynamic>.from(assigned.toJson()),
      );
      final directory = await Directory.systemTemp.createTemp(
        'tankloop-work-restart-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/work.sqlite');
      var storage = SqliteKeyValueStore(NativeDatabase(file));
      var outbox = WorkOrderOutbox(
        store: storage,
        namespace: 'field',
        scope: current.scope,
      );
      await outbox.save(
        order: current,
        actorId: current.assigneeId!,
        notes: 'Simulated work step',
        observedAt: data.asOf,
      );
      await Future.wait([outbox.enqueue(current), outbox.enqueue(current)]);
      final eventId = outbox.entries.single.command.clientEventId;
      await outbox.sync(repo, online: false);
      outbox.dispose();
      await storage.close();
      storage = SqliteKeyValueStore(NativeDatabase(file));
      addTearDown(storage.close);
      outbox = WorkOrderOutbox(
        store: storage,
        namespace: 'field',
        scope: current.scope,
      );
      addTearDown(outbox.dispose);
      await outbox.load();
      final cases = repo.engine.incidents.map((id, c) => MapEntry(id, c.state));
      await Future.wait([
        outbox.sync(repo, online: true),
        outbox.sync(repo, online: true),
      ]);
      expect(outbox.entries.single.receipt!.clientEventId, eventId);
      expect(outbox.entries.single.attempts, 1);
      expect(
        repo.engine.incidents.map((id, c) => MapEntry(id, c.state)),
        cases,
      );
    },
  );
}
