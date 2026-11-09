import '../../../packages/data/test/support/fixture_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_field/runtime.dart';
import 'package:tankloop_field/water_points.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

void main() {
  debugDisableSkeletonAnimations = true;

  testWidgets('a public point says what happened and what happens next', (
    tester,
  ) async {
    final runtime = await FieldRuntime.create(
      const AppConfig(supabaseUrl: 'https://test.supabase.co', anonKey: 'k'),
      MemoryKeyValueStore(),
      repository: FixtureRepository(liveRecords: true),
    );
    addTearDown(runtime.outbox.dispose);
    addTearDown(runtime.dispose);
    final points = runtime.dashboard.points;
    expect(points, isNotEmpty);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: MaterialApp(
          theme: tankLoopTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: WaterPointsScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('WHAT HAPPENED?'), findsNWidgets(points.length));
    expect(find.text('WHAT HAPPENS NEXT?'), findsNWidgets(points.length));
    expect(
      find.text(
        'An inspection records what was seen. It does not show whether the water is safe to drink.',
      ),
      findsNWidgets(points.length),
    );
    // A past due date is never described as the next inspection.
    final data = runtime.dashboard;
    for (final point in points) {
      final openCase = data.cases.any(
        (c) => c.pointLabel == point.label && c.state != IncidentState.resolved,
      );
      final upcoming =
          data.inspections
              .where((t) => t.assetId == point.assetId && !t.isSubmitted)
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      if (openCase || upcoming.isEmpty) continue;
      final due = upcoming.first.dueAt;
      expect(
        find.text(
          due.isBefore(data.asOf)
              ? 'An inspection was due ${recordDate(due)} and is still to be done.'
              : 'The next inspection is due ${recordDate(due)}.',
        ),
        findsOneWidget,
        reason: point.label,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundled font and icon licenses are listed', (tester) async {
    registerTankLoopLicenses();
    final names = await tester.runAsync(() async {
      final entries = await LicenseRegistry.licenses.toList();
      return {
        for (final entry in entries)
          if (entry.paragraphs.isNotEmpty) ...entry.packages,
      };
    });
    expect(
      names,
      containsAll([
        'Plus Jakarta Sans',
        'Playfair Display',
        'Phosphor Icons',
        'Lucide',
      ]),
    );
  });
}
