import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_field/handover/handover.dart';
import 'package:tankloop_field/handover/handover_page.dart';
import 'package:tankloop_field/runtime.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import '../../../packages/data/test/support/fixture_repository.dart';

HandoverDraft draftFor(String actor, String id, String kind) => HandoverDraft({
  'version': 1,
  'actor_id': actor,
  'model': 'openai/gpt-oss-120b',
  'generated_at': '2026-11-09T12:00:00Z',
  'fingerprint': 'source-hash',
  'original_text':
      'Work was recorded as completed. This alone does not close the case.',
  'limitation': 'This draft describes records, not water safety.',
  'snapshot': {
    'kind': kind,
    'id': id,
    'sources': [
      {
        'id': 'work_order:record',
        'record_id': 'record',
        'kind': 'work_order',
        'revision': 'revision',
        'is_simulated': false,
        'fields': {
          'state': 'completed',
          'due_at': '2026-11-09T12:00:00Z',
          'version': 3,
        },
      },
    ],
  },
  'highlights': [
    {
      'source_id': 'work_order:record',
      'text':
          'Work was recorded as completed. This alone does not close the case.',
    },
  ],
  'next_steps': [
    {
      'text': 'Case owner: check the separate verification requirements.',
      'source_ids': ['work_order:record'],
    },
  ],
  'gaps': [
    {
      'text': 'No reviewed test is included in these records.',
      'source_ids': <String>[],
    },
  ],
});

class FakeHandoverService implements HandoverService {
  FakeHandoverService(this.actor);
  final String actor;
  HandoverFailure? failure;
  Completer<Json>? pendingReview;
  int generations = 0;
  int reviews = 0;
  @override
  Future<HandoverDraft> generate(String kind, String id) async {
    generations++;
    if (failure != null) throw failure!;
    return draftFor(actor, id, kind);
  }

  @override
  Future<Json> review(String kind, String id, HandoverDraft draft) async {
    reviews++;
    if (failure != null) throw failure!;
    return pendingReview?.future ??
        {
          'reviewer_id': actor,
          'reviewed_at': '2026-11-09T12:01:00Z',
          'fingerprint': draft.fingerprint,
        };
  }
}

Finder pageScroll([String key = 'handover-scroll']) => find
    .descendant(of: find.byKey(Key(key)), matching: find.byType(Scrollable))
    .first;

void main() {
  late MemoryKeyValueStore store;
  late FakeHandoverService service;
  late HandoverController controller;
  late bool online;
  late bool access;
  setUp(() {
    store = MemoryKeyValueStore();
    service = FakeHandoverService('actor-a');
    online = true;
    access = true;
    controller = HandoverController(
      service: service,
      store: store,
      storageKey: handoverStorageKey('project:actor-a', 'facility-a'),
      actorId: 'actor-a',
      kind: 'point',
      id: 'point-a',
      canConnect: () => online,
      hasAccess: () => access,
    );
  });
  tearDown(() => controller.dispose());

  test(
    'only an explicitly reviewed fresh draft can be saved, preserving provenance',
    () async {
      await controller.generate();
      await controller.save();
      expect(store.values, isEmpty);
      expect(service.reviews, 0);
      controller.confirmReview(true);
      controller.edit('A repair was recorded. Follow-up still needs review.');
      expect(controller.reviewed, isFalse);
      await controller.save();
      expect(store.values, isEmpty);
      controller.confirmReview(true);
      await controller.save();
      final saved =
          (jsonDecode(store.values.values.single) as Json)['point:point-a']
              as Json;
      expect(saved['reviewer_id'], 'actor-a');
      expect(
        saved['generation']['original_text'],
        contains('Work was recorded'),
      );
      expect(
        saved['reviewed_text'],
        'A repair was recorded. Follow-up still needs review.',
      );
      expect(saved['generation']['snapshot']['sources'], isNotEmpty);
      expect(saved['generation']['model'], 'openai/gpt-oss-120b');
      expect(controller.reviewed, isFalse);
    },
  );

  test(
    'offline and provider failure retain wording and previously saved draft',
    () async {
      await controller.generate();
      controller.confirmReview(true);
      await controller.save();
      final originalSaved = Map.of(store.values);
      controller.edit('My retained wording');
      online = false;
      controller.confirmReview(true);
      await controller.save();
      await controller.generate();
      expect(controller.wording, 'My retained wording');
      expect(store.values, originalSaved);
      expect(service.generations, 1);
      online = true;
      service.failure = const HandoverFailure('timeout', 'Timed out');
      await controller.generate();
      expect(controller.wording, 'My retained wording');
      expect(store.values, originalSaved);
    },
  );

  test(
    'source change requires regeneration and new review without losing human edits',
    () async {
      await controller.generate();
      controller.edit('Keep this human wording');
      controller.confirmReview(true);
      service.failure = const HandoverFailure(
        'stale_sources',
        'Records changed',
      );
      await controller.save();
      expect(controller.mustRegenerate, isTrue);
      expect(controller.wording, 'Keep this human wording');
      controller.confirmReview(true);
      expect(controller.canSave, isFalse);
      expect(store.values, isEmpty);
      service.failure = null;
      await controller.generate();
      expect(controller.previousWording, 'Keep this human wording');
      expect(controller.reviewed, isFalse);
      expect(controller.mustRegenerate, isFalse);
    },
  );

  test(
    'review response cannot save wording changed during the request',
    () async {
      await controller.generate();
      controller.confirmReview(true);
      service.pendingReview = Completer<Json>();
      final save = controller.save();
      await Future<void>.delayed(Duration.zero);
      controller.edit('Changed after review');
      service.pendingReview!.complete({
        'reviewer_id': 'actor-a',
        'reviewed_at': '2026-11-09T12:01:00Z',
        'fingerprint': 'source-hash',
      });
      await save;
      expect(store.values, isEmpty);
    },
  );

  test('access revoked during validation cannot persist a draft', () async {
    await controller.generate();
    controller.confirmReview(true);
    service.pendingReview = Completer<Json>();
    final save = controller.save();
    await Future<void>.delayed(Duration.zero);
    access = false;
    service.pendingReview!.complete({
      'reviewer_id': 'actor-a',
      'reviewed_at': '2026-11-09T12:01:00Z',
      'fingerprint': 'source-hash',
    });
    await save;
    expect(store.values, isEmpty);
    expect(controller.failure!.code, 'forbidden');
  });

  test(
    'saved drafts are namespaced and cannot restore another reviewer or target',
    () async {
      await controller.generate();
      controller.confirmReview(true);
      await controller.save();
      final other = HandoverController(
        service: service,
        store: store,
        storageKey: controller.storageKey,
        actorId: 'actor-b',
        kind: 'point',
        id: 'point-a',
        canConnect: () => true,
        hasAccess: () => true,
      );
      addTearDown(other.dispose);
      await other.load();
      expect(other.draft, isNull);
      expect(
        handoverStorageKey('project:actor-b', 'facility-a'),
        isNot(controller.storageKey),
      );
      expect(
        handoverStorageKey('project:actor-a', 'facility-b'),
        isNot(controller.storageKey),
      );
    },
  );

  testWidgets(
    'person can prepare, inspect dated source, edit, review and save',
    (tester) async {
      final runtime = await FieldRuntime.create(
        const AppConfig(supabaseUrl: 'https://handover.test', anonKey: 'test'),
        store,
        repository: FixtureRepository(liveRecords: true),
      );
      addTearDown(runtime.dispose);
      addTearDown(runtime.outbox.dispose);
      service = FakeHandoverService(runtime.dashboard.actorId);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimeProvider.overrideWithValue(runtime),
            handoverServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: tankLoopTheme(),
            home: const HandoverPage(
              kind: 'point',
              id: 'point-a',
              label: 'Evaluation outlet',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare AI draft'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('See work order source').first,
        250,
        scrollable: pageScroll(),
      );
      await tester.tap(find.text('See work order source').first);
      await tester.pumpAndSettle();
      expect(find.text('Dated work order record'), findsOneWidget);
      expect(find.text('due at: 2026-11-09T12:00:00Z'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Close source'),
        200,
        scrollable: pageScroll('handover-source-scroll'),
      );
      await tester.tap(find.text('Close source'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(TextField),
        400,
        scrollable: pageScroll(),
      );
      await tester.enterText(
        find.byType(TextField),
        'Work recorded. Verification remains to be reviewed.',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(
        FilledButton,
        'Save reviewed draft on device',
      );
      await tester.scrollUntilVisible(save, 250, scrollable: pageScroll());
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('handover-saved')), findsOneWidget);
      expect(service.reviews, 1);
      expect(
        store.values[handoverStorageKey(
          runtime.identity,
          runtime.dashboard.scope.facilityId,
        )],
        contains('Verification remains'),
      );
      expect(tester.takeException(), isNull);
      await runtime.clearDeviceData();
      expect(
        store.values[handoverStorageKey(
          runtime.identity,
          runtime.dashboard.scope.facilityId,
        )],
        isNull,
      );
    },
  );

  testWidgets(
    '320px and 200 percent text stay readable through the review controls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final runtime = await FieldRuntime.create(
        const AppConfig(supabaseUrl: 'https://handover.test', anonKey: 'test'),
        store,
        repository: FixtureRepository(liveRecords: true),
      );
      addTearDown(runtime.dispose);
      addTearDown(runtime.outbox.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimeProvider.overrideWithValue(runtime),
            handoverServiceProvider.overrideWithValue(
              FakeHandoverService(runtime.dashboard.actorId),
            ),
          ],
          child: MaterialApp(
            theme: tankLoopTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const HandoverPage(
              kind: 'point',
              id: 'point-a',
              label: 'Long evaluation outlet name',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Prepare AI draft'),
        250,
        scrollable: pageScroll(),
      );
      await tester.tap(find.text('Prepare AI draft'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Save reviewed draft on device'),
        500,
        maxScrolls: 60,
        scrollable: pageScroll(),
      );
      expect(
        find.text('I reviewed the wording, dated sources and missing steps.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
