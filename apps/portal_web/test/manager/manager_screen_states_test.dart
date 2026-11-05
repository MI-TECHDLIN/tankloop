import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_portal/manager_controller.dart';
import 'package:tankloop_portal/manager_screen_states.dart';
import 'package:tankloop_portal/manager_widgets.dart';
import 'manager_test_support.dart';

void main() {
  for (var index = 0; index < managerScreenNames.length; index++) {
    group('${managerScreenNames[index]} actual screen: all seven states', () {
      Future<void> render(
        WidgetTester tester,
        ManagerController controller, {
        bool reducedMotion = false,
      }) => tester.pumpWidget(
        managerTestApp(
          managerScreen(index, controller),
          controller: controller,
          reduceMotion: reducedMotion,
        ),
      );

      testWidgets('loading is accessible and respects reduced motion', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final repository = TestManagerRepository();
        final pending = Completer<ManagerWorkspace>();
        repository.onLoad = (_) => pending.future;
        final controller = ManagerController(
          repository,
          clock: () => managerNow,
        );
        unawaited(controller.refresh());
        await render(tester, controller, reducedMotion: true);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(ManagerStateSkeleton), findsOneWidget);
        expect(find.byType(FrostedSkeleton), findsWidgets);
        expect(
          find.bySemanticsLabel('Loading manager records'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ManagerRecordTile), findsNothing);
        expect(tester.binding.hasScheduledFrame, false);
        expect(controller.canWrite, false);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('empty comes from the actual record set', (tester) async {
        final repository = TestManagerRepository();
        final empty = emptyManagerWorkspace(await repository.load());
        repository.onLoad = (_) async => empty;
        final controller = ManagerController(
          repository,
          clock: () => managerNow,
        );
        await controller.refresh();
        await render(tester, controller);
        await tester.pumpAndSettle();
        expect(find.text('Nothing in scope'), findsOneWidget);
        expect(
          tester
              .widget<ManagerStatePanel>(find.byType(ManagerStatePanel))
              .state,
          ManagerViewState.empty,
        );
        expect(find.byType(ManagerRecordTile), findsNothing);
        expect(find.byType(ManagerIncidentActions), findsNothing);
        expect(repository.commands, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('error retries through the repository and restores records', (
        tester,
      ) async {
        final repository = TestManagerRepository();
        final data = await repository.load();
        repository.onLoad = (_) async => throw const RepositoryFailure(
          FailureKind.transient,
          'Manager service unavailable.',
        );
        final controller = ManagerController(
          repository,
          clock: () => managerNow,
        );
        await controller.refresh();
        await render(tester, controller);
        await tester.pumpAndSettle();
        expect(find.text('Manager view unavailable'), findsOneWidget);
        expect(managerContent(index, data), findsNothing);
        expect(controller.canWrite, false);
        repository.onLoad = null;
        await managerTap(tester, find.text('Retry'));
        expect(managerContent(index, data), findsWidgets);
        expect(controller.phase, ManagerViewState.success);
        expect(repository.loads.length, 3);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'permission loss removes previously visible private records',
        (tester) async {
          final repository = TestManagerRepository();
          final controller = ManagerController(
            repository,
            clock: () => managerNow,
          );
          await controller.refresh();
          final data = controller.workspace!;
          await render(tester, controller);
          expect(managerContent(index, data), findsWidgets);
          repository.onLoad = (_) async => throw const RepositoryFailure(
            FailureKind.permission,
            'Manager membership revoked.',
          );
          await controller.refresh();
          await tester.pumpAndSettle();
          expect(find.text('Permission required'), findsOneWidget);
          expect(managerContent(index, data), findsNothing);
          expect(find.textContaining('Last fetched:'), findsNothing);
          expect(controller.workspace, isNull);
          expect(controller.actionMessage, isNull);
          expect(controller.canWrite, false);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('offline retains records and pauses authoritative actions', (
        tester,
      ) async {
        final repository = TestManagerRepository();
        final controller = ManagerController(
          repository,
          clock: () => managerNow,
        );
        await controller.refresh();
        final cached = controller.workspace!;
        await render(tester, controller);
        repository.onLoad = (_) async => throw const ManagerConnectionFailure();
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(find.text('Offline'), findsOneWidget);
        expect(managerContent(index, cached), findsWidgets);
        expect(controller.workspace, same(cached));
        expect(controller.canWrite, false);
        for (final button in tester.widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        )) {
          expect(button.onPressed, isNull);
        }
        for (final button in tester.widgetList<FilledButton>(
          find.byType(FilledButton),
        )) {
          expect(button.onPressed, isNull);
        }
        expect(repository.commands, isEmpty);
        repository.onLoad = null;
        await managerTap(tester, find.text('Refresh records'));
        expect(controller.phase, ManagerViewState.success);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'stale expires by fetch time and preserves the evidence clock',
        (tester) async {
          var now = managerNow;
          final repository = TestManagerRepository(clock: () => now);
          final controller = ManagerController(repository, clock: () => now);
          await controller.refresh();
          final cached = controller.workspace!;
          await render(tester, controller);
          now = now.add(const Duration(minutes: 6));
          await tester.pump(const Duration(minutes: 6));
          await tester.pumpAndSettle();
          expect(find.text('Stale data'), findsOneWidget);
          expect(managerContent(index, cached), findsWidgets);
          expect(controller.workspace, same(cached));
          expect(controller.workspace!.asOf, repository.engine.now);
          expect(controller.canWrite, false);
          for (final button in tester.widgetList<OutlinedButton>(
            find.byType(OutlinedButton),
          )) {
            expect(button.onPressed, isNull);
          }
          for (final button in tester.widgetList<FilledButton>(
            find.byType(FilledButton),
          )) {
            expect(button.onPressed, isNull);
          }
          await managerTap(tester, find.text('Refresh records'));
          expect(controller.canWrite, true);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('success shows generated, scoped records and provenance', (
        tester,
      ) async {
        final repository = TestManagerRepository();
        final controller = ManagerController(
          repository,
          clock: () => managerNow,
        );
        await controller.refresh();
        await render(tester, controller);
        await tester.pumpAndSettle();
        expect(managerContent(index, controller.workspace!), findsWidgets);
        expect(
          find.text('SIMULATED DATA · No real water tests'),
          findsOneWidget,
        );
        expect(find.textContaining('Exercise clock:'), findsOneWidget);
        expect(find.textContaining('Last fetched:'), findsOneWidget);
        expect(find.byType(ManagerStateSkeleton), findsNothing);
        expect(controller.canWrite, true);
        expect(repository.commands, isEmpty);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
