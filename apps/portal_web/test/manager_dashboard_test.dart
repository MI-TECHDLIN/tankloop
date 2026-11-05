import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_portal/manager_dashboard.dart';
import 'package:tankloop_portal/manager_widgets.dart';
import 'manager/manager_test_support.dart';

void main() {
  testWidgets(
    'dashboard navigation opens actual records in all four expanded screens',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = SimulationManagerRepository();
      final data = await repository.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: tankLoopTheme(),
          home: ManagerDashboard(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Operational overview'), findsOneWidget);
      expect(find.text('Evidence completeness'), findsOneWidget);
      expect(find.text('SIMULATED DATA · No real water tests'), findsOneWidget);
      for (final (label, index) in [
        ('Facilities', 1),
        ('Inspections', 3),
        ('Samples & Results', 4),
        ('Team', 7),
      ]) {
        await managerTap(
          tester,
          find.descendant(
            of: find.byType(NavigationDrawer),
            matching: find.text(label),
          ),
        );
        expect(managerContent(index, data), findsOneWidget);
        await managerTap(tester, managerContent(index, data));
        expect(find.text('Back to list'), findsOneWidget);
        expect(find.byType(ManagerDetail), findsWidgets);
        expect(find.text('Scoped manager · facility access'), findsNothing);
        expect(
          find.textContaining('evidence status requires review'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
