import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

class FlakyRepository implements TankLoopRepository {
  FlakyRepository(
    this.inner, {
    this.failAfterCommit = false,
    this.permanent = false,
  });
  final TankLoopRepository inner;
  bool failAfterCommit;
  bool permanent;
  int calls = 0;
  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) async {
    calls++;
    if (permanent) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Membership revoked',
      );
    }
    final receipt = await inner.submitInspection(command);
    if (failAfterCommit) {
      failAfterCommit = false;
      throw const RepositoryFailure(FailureKind.transient, 'Receipt lost');
    }
    return receipt;
  }

  @override
  Future<DashboardSnapshot> today() => inner.today();
  @override
  Future<PublicWaterRecord?> publicRecord(String token) =>
      inner.publicRecord(token);
}

class FlakyEvidenceRepository extends FlakyRepository
    implements EvidenceUploader {
  FlakyEvidenceRepository(super.inner, {this.failAtUpload});
  final int? failAtUpload;
  int uploads = 0;

  @override
  Future<String> uploadEvidence(InspectionEvidence evidence) async {
    uploads++;
    if (uploads == failAtUpload) {
      throw const RepositoryFailure(
        FailureKind.transient,
        'Battery removed during photo upload',
      );
    }
    return 'private/${evidence.id}.jpg';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SimulationRepository repository;
  late DashboardSnapshot dashboard;
  late InspectionTask task;
  late ChecklistTemplate template;
  late MemoryKeyValueStore storage;
  late InspectionOutbox outbox;
  setUp(() async {
    repository = SimulationRepository();
    dashboard = await repository.today();
    task = dashboard.inspections.firstWhere((t) => !t.isSubmitted);
    template = dashboard.templateFor(task);
    storage = MemoryKeyValueStore();
    outbox = InspectionOutbox(
      store: storage,
      namespace: 'user-a',
      scope: dashboard.scope,
    );
    await outbox.load();
  });
  Future<void> saveAndQueue() async {
    await outbox.save(
      task: task,
      answers: {
        for (final q in template.questions)
          q.id: const InspectionAnswer(AnswerChoice.yes),
      },
      notes: 'Draft survives disconnection',
      observedAt: dashboard.asOf,
    );
    await outbox.enqueue(task.id, template);
  }

  test(
    'offline draft persists and resumes with identical event identity',
    () async {
      await saveAndQueue();
      final id = outbox.entries.single.command.clientEventId;
      await outbox.sync(repository, online: false);
      final reopened = InspectionOutbox(
        store: storage,
        namespace: 'user-a',
        scope: dashboard.scope,
      );
      await reopened.load();
      expect(reopened.entries.single.command.clientEventId, id);
      expect(
        reopened.entries.single.command.notes,
        'Draft survives disconnection',
      );
      expect(reopened.entries.single.state, DraftState.pending);
      expect(reopened.entries.single.receipt, isNull);
    },
  );
  test('photo evidence persists with the queued command', () async {
    await outbox.save(
      task: task,
      answers: {
        for (final q in template.questions)
          q.id: const InspectionAnswer(AnswerChoice.unknown),
      },
      notes: 'Photo attached',
      observedAt: dashboard.asOf,
      evidence: [
        InspectionEvidence(
          id: 'evidence-1',
          localPath: '/device/photos/evidence-1.jpg',
          capturedAt: dashboard.asOf,
        ),
      ],
    );
    await outbox.enqueue(task.id, template);
    final reopened = InspectionOutbox(
      store: storage,
      namespace: 'user-a',
      scope: dashboard.scope,
    );
    await reopened.load();
    expect(reopened.entries.single.command.evidence.single.id, 'evidence-1');
    expect(
      reopened.entries.single.command.evidence.single.localPath,
      '/device/photos/evidence-1.jpg',
    );
    expect(reopened.entries.single.state, DraftState.pending);
  });
  test(
    'partial photo upload resumes without re-uploading completed photos',
    () async {
      await outbox.save(
        task: task,
        answers: {
          for (final q in template.questions)
            q.id: const InspectionAnswer(AnswerChoice.unknown),
        },
        notes: 'Two photos',
        observedAt: dashboard.asOf,
        evidence: [
          InspectionEvidence(
            id: 'evidence-1',
            localPath: '/device/photos/evidence-1.jpg',
            capturedAt: dashboard.asOf,
          ),
          InspectionEvidence(
            id: 'evidence-2',
            localPath: '/device/photos/evidence-2.jpg',
            capturedAt: dashboard.asOf,
          ),
        ],
      );
      await outbox.enqueue(task.id, template);
      final network = FlakyEvidenceRepository(repository, failAtUpload: 2);
      await outbox.sync(network, online: true);
      expect(outbox.entries.single.state, DraftState.pending);
      expect(
        outbox.entries.single.command.evidence.first.uploadedPath,
        isNotNull,
      );
      expect(outbox.entries.single.command.evidence[1].uploadedPath, isNull);
      await outbox.sync(network, online: true, retryNow: true);
      expect(outbox.entries.single.state, DraftState.synced);
      expect(network.uploads, 3);
    },
  );
  test(
    'clock-skewed device timestamps remain immutable through retry',
    () async {
      final deviceTime = dashboard.asOf.add(const Duration(days: 3));
      await outbox.save(
        task: task,
        answers: {
          for (final q in template.questions)
            q.id: const InspectionAnswer(AnswerChoice.unknown),
        },
        notes: 'Device clock was ahead',
        observedAt: deviceTime,
      );
      await outbox.enqueue(task.id, template);
      final network = FlakyRepository(repository, failAfterCommit: true);
      await outbox.sync(network, online: true);
      expect(outbox.entries.single.command.observedAt, deviceTime);
      await outbox.sync(network, online: true, retryNow: true);
      expect(outbox.entries.single.command.observedAt, deviceTime);
      expect(outbox.entries.single.receipt, isNotNull);
    },
  );
  test('different accounts and facilities cannot see a cached queue', () async {
    await saveAndQueue();
    final otherUser = InspectionOutbox(
      store: storage,
      namespace: 'user-b',
      scope: dashboard.scope,
    );
    final otherFacility = InspectionOutbox(
      store: storage,
      namespace: 'user-a',
      scope: const Scope('other-org', 'other-facility'),
    );
    await otherUser.load();
    await otherFacility.load();
    expect(otherUser.entries, isEmpty);
    expect(otherFacility.entries, isEmpty);
    expect(
      () => otherFacility.save(
        task: task,
        answers: {},
        notes: '',
        observedAt: dashboard.asOf,
      ),
      throwsA(isA<RuleViolation>()),
    );
  });
  test(
    'lost ACK retries the same command without duplicating incident',
    () async {
      await saveAndQueue();
      final before = repository.engine.incidents.length;
      final network = FlakyRepository(repository, failAfterCommit: true);
      await outbox.sync(network, online: true);
      expect(outbox.entries.single.state, DraftState.pending);
      expect(outbox.entries.single.nextAttemptAt, isNotNull);
      await outbox.sync(network, online: true);
      expect(network.calls, 1, reason: 'automatic retry obeys backoff');
      await outbox.sync(network, online: true, retryNow: true);
      expect(outbox.entries.single.state, DraftState.synced);
      expect(outbox.entries.single.receipt!.version, 1);
      expect(repository.engine.incidents.length, before + 1);
    },
  );
  test(
    'revocation blocks retry and preserves editable source evidence',
    () async {
      await saveAndQueue();
      final network = FlakyRepository(repository, permanent: true);
      await outbox.sync(network, online: true);
      expect(outbox.entries.single.state, DraftState.blocked);
      expect(outbox.entries.single.command.answers, isNotEmpty);
      await outbox.sync(network, online: true, retryNow: true);
      expect(network.calls, 1);
    },
  );
  test(
    'double submission and concurrent autosave cannot duplicate the outbox',
    () async {
      await Future.wait([
        outbox.save(
          task: task,
          answers: {},
          notes: 'First',
          observedAt: dashboard.asOf,
        ),
        outbox.save(
          task: task,
          answers: {
            for (final q in template.questions)
              q.id: const InspectionAnswer(AnswerChoice.no),
          },
          notes: 'Latest',
          observedAt: dashboard.asOf,
        ),
      ]);
      await Future.wait([
        outbox.enqueue(task.id, template),
        outbox.enqueue(task.id, template),
      ]);
      expect(outbox.entries, hasLength(1));
      expect(outbox.entries.single.command.notes, 'Latest');
      await Future.wait([
        outbox.sync(repository, online: true),
        outbox.sync(repository, online: true),
      ]);
      expect(outbox.entries.single.attempts, 1);
      expect(
        () => outbox.save(
          task: task,
          answers: {},
          notes: 'Overwrite',
          observedAt: dashboard.asOf,
        ),
        throwsA(isA<RuleViolation>()),
      );
    },
  );
  test('incomplete answers cannot be queued', () async {
    await outbox.save(
      task: task,
      answers: {},
      notes: '',
      observedAt: dashboard.asOf,
    );
    expect(
      () => outbox.enqueue(task.id, template),
      throwsA(isA<RuleViolation>()),
    );
    expect(outbox.entries.single.state, DraftState.draft);
  });
  test(
    'Drift database retains a queue after closing the SQLite connection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'tankloop-sqlite-',
      );
      final file = File('${directory.path}/drafts.sqlite');
      final first = SqliteKeyValueStore(NativeDatabase(file));
      outbox = InspectionOutbox(
        store: first,
        namespace: 'user-a',
        scope: dashboard.scope,
      );
      await outbox.load();
      await saveAndQueue();
      await first.close();
      final second = SqliteKeyValueStore(NativeDatabase(file));
      final reopened = InspectionOutbox(
        store: second,
        namespace: 'user-a',
        scope: dashboard.scope,
      );
      await reopened.load();
      expect(reopened.pendingCount, 1);
      expect(
        reopened.entries.single.command.notes,
        'Draft survives disconnection',
      );
      await reopened.clear();
      expect(await second.read(reopened.storageKey), isNull);
      await second.close();
      await directory.delete(recursive: true);
    },
  );
}
