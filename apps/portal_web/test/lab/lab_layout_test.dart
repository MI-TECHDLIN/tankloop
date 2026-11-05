import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/lab/lab_navigation.dart';
import 'package:tankloop_portal/lab/lab_routes.dart';
import 'lab_test_support.dart';

void main() {
  for (final size in [const Size(320, 740), const Size(1440, 1000)]) {
    for (final section in LabSection.values) {
      testWidgets(
        '${section.label} route fits ${size.width.toInt()}px at 130% text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repository = TestLabRepository(
            await generatedLabWorkspace(
              state: switch (section) {
                LabSection.inbox => ResultState.valid,
                LabSection.intake => ResultState.collected,
                LabSection.results => ResultState.tested,
                LabSection.revisions => ResultState.published,
              },
            ),
          );
          final router = GoRouter(
            initialLocation: '/lab/${section.path}',
            routes: labRoutes(repository),
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(theme: tankLoopTheme(), routerConfig: router),
          );
          await tester.pumpAndSettle();
          expect(find.text(section.label), findsWidgets);
          expect(
            find.text(
              'SIMULATED DEMONSTRATION\nGenerated records, not real water tests.',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('Model 1 · Seed 20261101'),
            findsOneWidget,
          );
          expect(
            find.byTooltip('Open lab navigation'),
            size.width < 880 ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('shared skeleton honors the reduced-motion preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: FrostedSkeleton(width: 120, height: 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostedSkeleton), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, false);
  });
}
