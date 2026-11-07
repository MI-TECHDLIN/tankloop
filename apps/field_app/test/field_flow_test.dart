import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_field/main.dart';
import 'package:tankloop_field/runtime.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder get visitNotes => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      widget.decoration?.labelText == 'Visit notes (optional)',
);

class UnavailableRepository implements TankLoopRepository {
  const UnavailableRepository(this.failure);
  final RepositoryFailure failure;
  @override
  Future<DashboardSnapshot> today() async => throw failure;
  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) async =>
      throw failure;
  @override
  Future<PublicWaterRecord?> publicRecord(String token) async => throw failure;
}

void main() {
  debugDisableSkeletonAnimations = true;

  final testConfig = AppConfig(
    supabaseUrl: 'https://test.supabase.co',
    anonKey: 'test-key',
  );

  // Shared simulation repository for tests that need persistent state
  late final SimulationRepository sharedSimulation;

  Future<FieldRuntime> createTestRuntime(MemoryKeyValueStore store) async {
    return FieldRuntime.create(
      testConfig,
      store,
      repository: sharedSimulation,
    );
  }

  setUpAll(() {
    sharedSimulation = SimulationRepository();
  });

  testWidgets('captured evidence survives camera cache loss and app restart', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('tankloop-camera-');
    final photo = File('${directory.path}/capture.png');
    photo.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgaGj4DwADhAIAV8n6LgAAAABJRU5ErkJggg==',
      ),
    );
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => photo.path,
    );
    addTearDown(() async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
      await directory.delete(recursive: true);
    });
    final store = MemoryKeyValueStore();
    var runtime = await createTestRuntime(store);
    await tester.pumpWidget(FieldApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Start inspection'));
    await tester.ensureVisible(find.text('Add photo evidence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add photo evidence'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    for (
      var tick = 0;
      tick < 8 && runtime.outbox.entries.single.command.evidence.isEmpty;
      tick++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect(runtime.outbox.entries.single.command.evidence, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    runtime.outbox.dispose();
    runtime.dispose();
    photo.deleteSync();
    PaintingBinding.instance.imageCache.clear();
    runtime = await createTestRuntime(store);
    addTearDown(runtime.dispose);
    addTearDown(runtime.outbox.dispose);
    await tester.pumpWidget(FieldApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Start inspection'));
    await tester.ensureVisible(find.text('Photo evidence'));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    expect(
      find.byIcon(Icons.broken_image_outlined),
      findsNothing,
      reason: 'Saved photo must remain viewable after OS clears camera cache',
    );
  });

  testWidgets('manual public QR link opens assigned tasks and point history', (
    tester,
  ) async {
    final store = MemoryKeyValueStore();
    final runtime = await createTestRuntime(store);
    addTearDown(runtime.dispose);
    addTearDown(runtime.outbox.dispose);
    final task = runtime.dashboard.inspections.firstWhere(
      (t) => !t.isSubmitted,
    );
    final point = runtime.dashboard.points.firstWhere(
      (p) => p.assetId == task.assetId,
    );
    final token = runtime.dashboard.publicTokens[point.id]!;
    await tester.pumpWidget(FieldApp(runtime: runtime));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('Scan water point QR'));
    final code = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Manual point code',
    );
    await tester.enterText(code, runtime.publicUrl(token));
    await tapVisible(tester, find.text('Use manual code'));
    expect(find.text('Assigned checks'), findsOneWidget);
    expect(find.text('Inspection history'), findsOneWidget);
    expect(find.text(point.label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'Android lost camera result attaches to the original saved draft',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'tankloop-lost-camera-',
      );
      final image = File('${directory.path}/recovered.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => directory.delete(recursive: true));
      final store = MemoryKeyValueStore();
      final runtime = await createTestRuntime(store);
      addTearDown(runtime.dispose);
      addTearDown(runtime.outbox.dispose);
      final task = runtime.dashboard.inspections.firstWhere(
        (t) => !t.isSubmitted,
      );
      final question = runtime.dashboard.templateFor(task).questions.first.id;
      await runtime.outbox.save(
        task: task,
        answers: {},
        notes: 'Before camera',
        observedAt: runtime.dashboard.asOf,
      );
      await store.write(
        runtime.photoCapture.key,
        jsonEncode({
          'id': task.id,
          'work_order': false,
          'question_id': question,
        }),
      );
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'retrieve');
            return {
              'type': 'image',
              'path': image.path,
              'pathList': [image.path],
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await runtime.photoCapture.recover();
      final entry = runtime.outbox.forTask(task.id)!;
      expect(entry.command.notes, 'Before camera');
      expect(entry.command.evidence.single.questionId, question);
      expect(await store.read(runtime.photoCapture.key), isNull);
      expect(await runtime.outbox.photos.read(entry.command.evidence.single), [
        1,
        2,
        3,
      ]);
    },
  );

  testWidgets(
    'a field visit survives recreation, queues offline and gets one receipt',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryKeyValueStore();
      var runtime = await createTestRuntime(store);
      addTearDown(() {
        runtime.outbox.dispose();
        runtime.dispose();
      });
      final task = runtime.dashboard.inspections.firstWhere(
        (t) => !t.isSubmitted,
      );
      final template = runtime.dashboard.templateFor(task);
      final initialCaseCount = runtime.dashboard.cases.length;

      await tester.pumpWidget(FieldApp(runtime: runtime));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Start inspection'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Submit inspection'),
            )
            .onPressed,
        isNull,
      );
      for (var i = 0; i < template.questions.length; i++) {
        final card = find.byKey(ValueKey(template.questions[i].id));
        await tapVisible(
          tester,
          find.descendant(
            of: card,
            matching: find.widgetWithText(ChoiceChip, i == 0 ? 'Yes' : 'No'),
          ),
        );
      }
      await tester.ensureVisible(visitNotes);
      await tester.enterText(
        visitNotes,
        'Visit: tank lid needs attention.',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Save draft'));
      final eventId = runtime.outbox.forTask(task.id)!.command.clientEventId;
      expect(runtime.outbox.forTask(task.id)!.state, DraftState.draft);

      // Rebuild the entire app/runtime from serialized local state, like a reload.
      await tester.pumpWidget(const SizedBox.shrink());
      runtime.outbox.dispose();
      runtime.dispose();
      runtime = await createTestRuntime(store);
      await tester.pumpWidget(FieldApp(runtime: runtime));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Profile'));
      await tapVisible(tester, find.text('Pause sync'));
      await tapVisible(tester, find.byTooltip('Today'));
      await tapVisible(tester, find.text('Start inspection'));
      expect(
        tester.widget<TextField>(visitNotes).controller!.text,
        'Visit: tank lid needs attention.',
      );
      expect(runtime.outbox.forTask(task.id)!.command.clientEventId, eventId);
      await tapVisible(tester, find.text('Queue inspection'));
      expect(runtime.outbox.forTask(task.id)!.state, DraftState.pending);
      expect(
        runtime.dashboard.inspections
            .singleWhere((t) => t.id == task.id)
            .isSubmitted,
        isFalse,
      );
      expect(find.text('Pending sync'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      runtime.outbox.dispose();
      runtime.dispose();
      runtime = await createTestRuntime(store);
      await tester.pumpWidget(FieldApp(runtime: runtime));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Activity'));
      expect(find.text('Queued inspections'), findsOneWidget);
      expect(find.text('Need review'), findsOneWidget);
      await tapVisible(tester, find.text('Sync queued inspections'));
      expect(find.text('Receipt received'), findsOneWidget);
      expect(runtime.outbox.forTask(task.id)!.receipt!.clientEventId, eventId);
      expect(runtime.dashboard.cases.length, initialCaseCount + 1);
      expect(
        runtime.dashboard.inspections
            .singleWhere((t) => t.id == task.id)
            .version,
        1,
      );
      await tapVisible(tester, find.text('Sync queued inspections'));
      expect(runtime.dashboard.cases.length, initialCaseCount + 1);

      // The acknowledged command must also survive an app restart.
      await tester.pumpWidget(const SizedBox.shrink());
      runtime.outbox.dispose();
      runtime.dispose();
      runtime = await createTestRuntime(store);
      expect(runtime.dashboard.cases.length, initialCaseCount + 1);
      expect(
        runtime.dashboard.inspections
            .singleWhere((t) => t.id == task.id)
            .isSubmitted,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all Field surfaces fit a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final store = MemoryKeyValueStore();
    final runtime = await createTestRuntime(store);
    addTearDown(runtime.outbox.dispose);
    addTearDown(runtime.dispose);
    await tester.pumpWidget(FieldApp(runtime: runtime));
    await tester.pumpAndSettle();
    for (final tab in ['Water', 'Cases', 'Activity', 'Profile', 'Today']) {
      await tapVisible(tester, find.byTooltip(tab));
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab must fit the viewport',
      );
    }
    await tapVisible(tester, find.text('Start inspection'));
    expect(tester.takeException(), isNull);
  });

  test(
    'cached assignments are account-scoped and permission failures fail closed',
    () async {
      const config = AppConfig(
        supabaseUrl: 'https://project.example',
        anonKey: 'test-key',
      );
      final store = MemoryKeyValueStore();
      final first = await FieldRuntime.create(
        config,
        store,
        repository: SimulationRepository(),
        userId: 'account-a',
      );
      addTearDown(first.outbox.dispose);
      addTearDown(first.dispose);
      const disconnected = UnavailableRepository(
        RepositoryFailure(FailureKind.transient, 'Disconnected'),
      );
      final restored = await FieldRuntime.create(
        config,
        store,
        repository: disconnected,
        userId: 'account-a',
      );
      addTearDown(restored.outbox.dispose);
      addTearDown(restored.dispose);
      expect(restored.stale, isTrue);
      expect(restored.dashboard.scope.matches(first.dashboard.scope), isTrue);
      await expectLater(
        FieldRuntime.create(
          config,
          store,
          repository: disconnected,
          userId: 'account-b',
        ),
        throwsA(isA<RepositoryFailure>()),
      );
      await expectLater(
        FieldRuntime.create(
          config,
          store,
          repository: const UnavailableRepository(
            RepositoryFailure(FailureKind.permission, 'Membership revoked'),
          ),
          userId: 'account-a',
        ),
        throwsA(isA<RepositoryFailure>()),
      );
      expect(await store.read(first.cacheKey), isNull);
    },
  );
}
