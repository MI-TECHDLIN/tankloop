import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/main.dart';
import 'package:tankloop_portal/public_point.dart';

class PublicRepository implements TankLoopRepository {
  PublicRepository(this.load);
  Future<PublicWaterRecord?> Function() load;
  @override
  Future<PublicWaterRecord?> publicRecord(String token) => load();
  @override
  Future<DashboardSnapshot> today() => throw UnimplementedError();
  @override
  Future<SyncReceipt> submitInspection(InspectionSubmission command) =>
      throw UnimplementedError();
}

Widget recordPage(TankLoopRepository repository, String token) => MaterialApp(
  theme: tankLoopTheme(),
  home: PublicPointPage(repository: repository, token: token),
);

void main() {
  for (final size in [const Size(320, 740), const Size(1440, 1000)]) {
    testWidgets(
      'QR page preserves evidence wording at ${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = SimulationRepository();
        final token = repository.engine.featuredToken;
        final record = (await repository.publicRecord(token))!;
        await tester.pumpWidget(recordPage(repository, token));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'SIMULATED DEMONSTRATION\nGenerated records, not real water tests.',
          ),
          findsOneWidget,
        );
        expect(find.text(record.state.label), findsOneWidget);
        expect(find.text(record.wording), findsOneWidget);
        expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
        expect(find.text(record.latestTest!.exactFinding), findsWidgets);
        expect(find.textContaining('Reported value:'), findsOneWidget);
        expect(find.textContaining('Detection limit:'), findsOneWidget);
        expect(find.text('Collected'), findsOneWidget);
        expect(find.text('Reviewed'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Text-first view'));
        await tester.pumpAndSettle();
        expect(find.byType(WaterNetworkArtwork), findsNothing);
        expect(find.text(record.wording), findsOneWidget);
        expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unknown or revoked QR makes no current water-quality claim', (
    tester,
  ) async {
    await tester.pumpWidget(
      recordPage(SimulationRepository(), '00000000000000000000000000000000'),
    );
    await tester.pumpAndSettle();
    expect(find.text('This point label is unavailable'), findsOneWidget);
    expect(find.textContaining('No current claim can be made'), findsOneWidget);
    expect(find.text('CURRENT RECORD STATUS'), findsNothing);
  });

  testWidgets('network failure stays unknown and can be retried', (
    tester,
  ) async {
    final pending = Completer<PublicWaterRecord?>();
    final repository = PublicRepository(() => pending.future);
    await tester.pumpWidget(recordPage(repository, 'point-token'));
    expect(find.text('Loading the point record'), findsOneWidget);
    pending.completeError(
      const RepositoryFailure(FailureKind.transient, 'Offline'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Live status unavailable'), findsOneWidget);
    expect(find.text('CURRENT RECORD STATUS'), findsNothing);
    final simulation = SimulationRepository();
    repository.load = () =>
        simulation.publicRecord(simulation.engine.featuredToken);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('CURRENT RECORD STATUS'), findsOneWidget);
    expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
  });

  testWidgets('a point without current evidence is explicitly unknown', (
    tester,
  ) async {
    final repository = SimulationRepository(day: 0);
    await tester.pumpWidget(
      recordPage(repository, repository.engine.featuredToken),
    );
    await tester.pumpAndSettle();
    expect(find.text('No valid current data'), findsWidgets);
    expect(find.text('No reviewed result to show'), findsOneWidget);
    expect(find.text('No open concerns recorded'), findsOneWidget);
    expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
  });

  testWidgets(
    'simulation root resolves a real token and advances the dated route',
    (tester) async {
      await tester.pumpWidget(
        const PortalApp(config: AppConfig(mode: AppMode.simulation)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Seed 20261101 · Day 10 · Deterministic, generated timeline'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Advance 1 day'));
      await tester.tap(find.text('Advance 1 day'));
      await tester.pumpAndSettle();
      expect(
        find.text('Seed 20261101 · Day 11 · Deterministic, generated timeline'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
