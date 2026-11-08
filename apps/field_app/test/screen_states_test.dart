import '../../../packages/data/test/support/fixture_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_field/activity.dart';
import 'package:tankloop_field/cases.dart';
import 'package:tankloop_field/inspection.dart';
import 'package:tankloop_field/profile.dart';
import 'package:tankloop_field/qr_scan.dart';
import 'package:tankloop_field/runtime.dart';
import 'package:tankloop_field/today.dart';
import 'package:tankloop_field/water_point.dart';
import 'package:tankloop_field/water_points.dart';
import 'package:tankloop_field/work_order.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

void main() {
  debugDisableSkeletonAnimations = true;
  for (final screen in [
    'today',
    'water',
    'cases',
    'activity',
    'profile',
    'inspection',
    'scan',
    'point',
    'work',
  ]) {
    for (final state in [
      'refreshing',
      'empty',
      'error',
      'permission-denied',
      'offline',
      'stale',
      'success',
    ]) {
      testWidgets('$screen renders real $state state on a narrow phone', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final config = AppConfig(
          supabaseUrl: 'https://test.supabase.co',
          anonKey: 'test-key',
        );
        final runtime = await FieldRuntime.create(
          config,
          MemoryKeyValueStore(),
          repository: FixtureRepository(liveRecords: true),
        );
        addTearDown(runtime.outbox.dispose);
        addTearDown(runtime.dispose);
        final task = runtime.dashboard.inspections.firstWhere(
          (t) => !t.isSubmitted,
        );
        final point = runtime.dashboard.points.first;
        final data = Map<String, dynamic>.from(runtime.dashboard.toJson());
        data['work_orders'] = [
          {
            'id': 'assigned-work',
            ...runtime.dashboard.scope.toJson(),
            'task': 'Inspect the repaired lid',
            'incident_id': 'case-1',
            'assignee_id': runtime.dashboard.actorId,
            'version': 2,
            'state': 'assigned',
            'is_simulated': true,
          },
        ];
        if (state == 'empty') {
          for (final key in [
            'inspections',
            'points',
            'assets',
            'cases',
            'work_orders',
          ]) {
            data[key] = [];
          }
          data['actor_id'] = '';
        } else if (screen == 'activity') {
          await runtime.outbox.save(
            task: task,
            answers: {},
            notes: 'Draft for state rendering',
            observedAt: runtime.dashboard.asOf,
          );
        }
        runtime.dashboard = DashboardSnapshot.fromJson(data);
        runtime.refreshing = state == 'refreshing';
        runtime.error = state == 'error'
            ? 'Test connection failed. Saved content is retained.'
            : null;
        runtime.accessRevoked = state == 'permission-denied';
        runtime.online = state != 'offline';
        runtime.stale = state == 'stale';
        final Widget child = switch (screen) {
          'today' => const TodayScreen(),
          'water' => const WaterPointsScreen(),
          'cases' => const CasesScreen(),
          'activity' => const ActivityScreen(),
          'profile' => const ProfileScreen(),
          'inspection' => InspectionPage(taskId: task.id),
          'scan' => const QrScanPage(),
          'point' => WaterPointScreen(pointId: point.id),
          _ => const WorkOrderScreen(orderId: 'assigned-work'),
        };
        final tab = [
          'today',
          'water',
          'cases',
          'activity',
          'profile',
        ].contains(screen);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [runtimeProvider.overrideWithValue(runtime)],
            child: MaterialApp(
              theme: tankLoopTheme(),
              home: tab
                  ? Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: child,
                      ),
                    )
                  : child,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(ValueKey(state == 'refreshing' ? 'success' : state)),
          findsOneWidget,
        );
        if (state == 'refreshing') {
          expect(find.byType(FrostedSkeleton), findsNothing);
        }
        if (state == 'permission-denied') {
          expect(find.byType(TextField), findsNothing);
          expect(find.text(runtime.dashboard.facility.label), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    }
  }
}
