import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/lab/lab_controller.dart';
import 'package:tankloop_portal/lab/lab_navigation.dart';
import 'package:tankloop_portal/lab/lab_routes.dart';
import 'lab_test_support.dart';

void main() {
  for (final failure in [
    const LabConnectionFailure(),
    const RepositoryFailure(FailureKind.transient, 'Temporary service failure'),
  ]) {
    testWidgets(
      'result draft survives refresh failure: ${failure.runtimeType}',
      (tester) async {
        final data = await generatedLabWorkspace(state: ResultState.valid);
        final repository = TestLabRepository(data);
        final controller = LabController(repository, clock: () => labNow);
        await controller.refresh();
        await tester.pumpWidget(
          labTestApp(
            labScreen(LabSection.results, controller),
            controller: controller,
          ),
        );
        await tester.enterText(find.byKey(const ValueKey('lab-value')), '12.5');
        await tester.enterText(find.byKey(const ValueKey('lab-limit')), '0.5');
        repository.onLoad = (_) async => throw failure;
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(find.text('12.5'), findsOneWidget);
        expect(find.text('0.5'), findsOneWidget);
        expect(controller.canWrite, false);
        repository.onLoad = null;
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(find.text('12.5'), findsOneWidget);
        expect(find.text('0.5'), findsOneWidget);
        expect(controller.canWrite, true);
      },
    );
  }

  testWidgets('refresh keeps the entered result draft mounted and read-only', (
    tester,
  ) async {
    final data = await generatedLabWorkspace(state: ResultState.valid);
    final repository = TestLabRepository(data);
    final controller = LabController(repository, clock: () => labNow);
    await controller.refresh();
    await tester.pumpWidget(
      labTestApp(
        labScreen(LabSection.results, controller),
        controller: controller,
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('lab-value')), '7.5');
    final pending = Completer<LabWorkspace>();
    repository.onLoad = (_) => pending.future;
    final refresh = controller.refresh();
    await tester.pump();
    expect(find.byKey(const ValueKey('lab-value')), findsOneWidget);
    expect(controller.canWrite, isFalse);
    pending.complete(data);
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('7.5'), findsOneWidget);
    expect(controller.canWrite, isTrue);
  });

  testWidgets('mobile route navigation closes its drawer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = TestLabRepository(await generatedLabWorkspace());
    final router = GoRouter(
      initialLocation: '/lab/inbox',
      routes: labRoutes(repository),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: tankLoopTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open lab navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Results'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/lab/results');
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
      false,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
