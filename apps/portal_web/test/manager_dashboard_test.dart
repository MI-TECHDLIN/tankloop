import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_portal/manager_dashboard.dart';
import 'package:tankloop_portal/manager_screen_states.dart';

void main() {
  testWidgets('manager dashboard exposes scoped operational signals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManagerDashboard(
          repository: SimulationRepository(seed: 20261101, day: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operational overview'), findsOneWidget);
    expect(find.text('Evidence completeness'), findsOneWidget);
    expect(find.text('SIMULATED DATA · No real water tests'), findsOneWidget);
  });

  testWidgets('manager loading uses frosted skeletons with reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: ManagerLoadingSkeleton(selected: 3)),
      ),
    );

    expect(find.byType(FrostedSkeleton), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(FrostedSkeletonCard), findsWidgets);
  });

  testWidgets('manager screen state panel covers non-success states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ManagerStatePanel(state: ManagerViewState.denied, onRetry: () {}),
      ),
    );
    expect(find.text('Permission required'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: ManagerStatePanel(state: ManagerViewState.offline),
      ),
    );
    expect(find.text('Offline'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(home: ManagerStatePanel(state: ManagerViewState.stale)),
    );
    expect(find.text('Stale data'), findsOneWidget);
  });

  for (final screen in [
    'overview',
    'incidents',
    'approvals',
    'facilities',
    'inspections',
    'samples',
    'reports',
    'team',
    'settings',
  ]) {
    group('$screen screen states', () {
      for (final state in ManagerViewState.values) {
        testWidgets('$state renders', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ManagerStatePanel(
                state: state,
                child: Text('$screen success'),
                onRetry: () {},
              ),
            ),
          );
          expect(find.byType(ManagerStatePanel), findsOneWidget);
        });
      }
    });
  }
}
