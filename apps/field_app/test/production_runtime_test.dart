import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_field/main.dart';
import 'package:tankloop_field/runtime.dart';
import 'package:tankloop_field/sign_in.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import '../../../packages/data/test/support/fixture_repository.dart';

const config = AppConfig(supabaseUrl: 'https://field.test', anonKey: 'test');
const cacheKey = 'dashboard:https://field.test:test-user';

class OfflineRepository implements TankLoopRepository {
  @override
  Future<DashboardSnapshot> today() async =>
      throw const RepositoryFailure(FailureKind.transient, 'Offline');
  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) async =>
      throw UnimplementedError();
  @override
  Future<PublicWaterRecord?> publicRecord(String token) async =>
      throw UnimplementedError();
}

class CountingRepository extends FixtureRepository {
  CountingRepository() : super(liveRecords: true);
  int loads = 0;
  @override
  Future<DashboardSnapshot> today() {
    loads++;
    return super.today();
  }
}

void main() {
  for (final wholeFacility in [true, false]) {
    test(
      'offline startup quarantines ${wholeFacility ? 'seeded facility' : 'mixed record'} cache and retains drafts',
      () async {
        final store = MemoryKeyValueStore();
        final fixture = FixtureRepository(liveRecords: !wholeFacility);
        final runtime = await FieldRuntime.create(
          config,
          store,
          repository: fixture,
        );
        final task = runtime.dashboard.inspections.firstWhere(
          (task) => !task.isSubmitted,
        );
        await runtime.outbox.save(
          task: task,
          answers: {},
          notes: 'Retained draft',
          observedAt: runtime.dashboard.asOf,
        );
        final draftKey = runtime.outbox.storageKey;
        final draft = await store.read(draftKey);
        final cached =
            jsonDecode((await store.read(cacheKey))!) as Map<String, dynamic>;
        if (!wholeFacility) {
          (cached['inspections'] as List).first['is_simulated'] = true;
          await store.write(cacheKey, jsonEncode(cached));
        }
        final original = await store.read(cacheKey);
        runtime.outbox.dispose();
        runtime.dispose();
        await expectLater(
          FieldRuntime.create(config, store, repository: OfflineRepository()),
          throwsA(
            isA<RepositoryFailure>().having(
              (failure) => failure.kind,
              'kind',
              FailureKind.transient,
            ),
          ),
        );
        expect(await store.read(cacheKey), original);
        expect(await store.read(draftKey), draft);
      },
    );
  }

  test('real cached assignments and drafts remain usable offline', () async {
    final store = MemoryKeyValueStore();
    var runtime = await FieldRuntime.create(
      config,
      store,
      repository: FixtureRepository(liveRecords: true),
    );
    final task = runtime.dashboard.inspections.firstWhere(
      (task) => !task.isSubmitted,
    );
    await runtime.outbox.save(
      task: task,
      answers: {},
      notes: 'Real draft',
      observedAt: runtime.dashboard.asOf,
    );
    runtime.outbox.dispose();
    runtime.dispose();
    runtime = await FieldRuntime.create(
      config,
      store,
      repository: OfflineRepository(),
    );
    addTearDown(runtime.dispose);
    addTearDown(runtime.outbox.dispose);
    expect(runtime.stale, isTrue);
    expect(runtime.dashboard.inspections, isNotEmpty);
    expect(runtime.outbox.forTask(task.id)!.command.notes, 'Real draft');
  });

  test(
    'old generated drafts are archived while real drafts remain active',
    () async {
      final store = MemoryKeyValueStore();
      var runtime = await FieldRuntime.create(
        config,
        store,
        repository: FixtureRepository(liveRecords: true),
      );
      final tasks = runtime.dashboard.inspections
          .where((task) => !task.isSubmitted)
          .take(2)
          .toList();
      for (final task in tasks) {
        await runtime.outbox.save(
          task: task,
          answers: {},
          notes: task.id,
          observedAt: runtime.dashboard.asOf,
        );
      }
      final key = runtime.outbox.storageKey;
      final document =
          jsonDecode((await store.read(key))!) as Map<String, dynamic>;
      (document['entries'] as List).first['command']['is_simulated'] = true;
      await store.write(key, jsonEncode(document));
      runtime.outbox.dispose();
      runtime.dispose();
      runtime = await FieldRuntime.create(
        config,
        store,
        repository: FixtureRepository(liveRecords: true),
      );
      addTearDown(runtime.dispose);
      addTearDown(runtime.outbox.dispose);
      expect(runtime.outbox.entries.single.command.taskId, tasks.last.id);
      final archive =
          jsonDecode((await store.read('quarantined:$key'))!)
              as Map<String, dynamic>;
      expect(
        (archive['entries'] as List).single['command']['task_id'],
        tasks.first.id,
      );
    },
  );

  testWidgets(
    'every tab refreshes by dragging content and keeps one scroll target',
    (tester) async {
      final repository = CountingRepository();
      final runtime = await FieldRuntime.create(
        config,
        MemoryKeyValueStore(),
        repository: repository,
      );
      addTearDown(runtime.dispose);
      addTearDown(runtime.outbox.dispose);
      await tester.pumpWidget(FieldApp(runtime: runtime));
      await tester.pumpAndSettle();
      for (final tab in ['Today', 'Water', 'Cases', 'Activity', 'Profile']) {
        await tester.tap(find.byTooltip(tab));
        await tester.pumpAndSettle();
        expect(find.byType(RefreshIndicator), findsOneWidget);
        expect(find.byTooltip('Refresh assignments'), findsNothing);
        final scroll = find.byType(Scrollable).first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        final before = repository.loads;
        await tester.drag(scroll, const Offset(0, 500));
        await tester.pumpAndSettle();
        expect(repository.loads, greaterThan(before), reason: tab);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('sign-in has no demo badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
    expect(find.text('SIMULATED DEMO'), findsNothing);
  });
}
