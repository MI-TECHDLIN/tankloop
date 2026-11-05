import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_portal/manager_dashboard.dart';

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
}
