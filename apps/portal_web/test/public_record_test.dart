import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/public/public_record_skeleton.dart';
import 'public/public_test_support.dart';

void main() {
  testWidgets(
    'loading uses an accessible design-system skeleton and reduced motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final pending = Completer<PublicPointLookup>();
      await tester.pumpWidget(
        publicPage(
          repository: PublicRepositoryFake(() => pending.future),
          token: 'pending',
          reduceMotion: true,
        ),
      );
      expect(find.byType(PublicRecordSkeleton), findsOneWidget);
      expect(find.byType(FrostedSkeleton), findsWidgets);
      expect(
        find.bySemanticsLabel(
          'Loading the point record. Retrieving dated evidence and open concerns.',
        ),
        findsOneWidget,
      );
      expect(find.text('CURRENT RECORD STATUS'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      pending.complete(const PublicPointLookup.missing());
      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );

  for (final entry in [
    (const PublicPointLookup.missing(), 'Point record not found'),
    (const PublicPointLookup.revoked(), 'This QR label has been revoked'),
  ]) {
    testWidgets('empty access: ${entry.$2}', (tester) async {
      await tester.pumpWidget(
        publicPage(
          repository: PublicRepositoryFake(() async => entry.$1),
          token: 'unavailable',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        find.textContaining('No current water-quality claim'),
        findsOneWidget,
      );
      expect(find.text('CURRENT RECORD STATUS'), findsNothing);
      expect(find.text('Report a concern'), findsNothing);
    });
  }

  for (final entry in [
    (PublicFailureKind.unavailable, 'Record service unavailable'),
    (PublicFailureKind.permission, 'Public record access unavailable'),
  ]) {
    testWidgets('error recovery: ${entry.$2}', (tester) async {
      final fake = PublicRepositoryFake(
        () async => throw PublicRequestFailure(entry.$1),
      );
      await tester.pumpWidget(publicPage(repository: fake, token: 'retry'));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(find.text('CURRENT RECORD STATUS'), findsNothing);
      final simulation = simulatedPublic();
      fake.load = () => simulation.lookup(simulation.engine.featuredToken);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('CURRENT RECORD STATUS'), findsOneWidget);
      expect(fake.lookups, 2);
    });
  }

  testWidgets(
    'offline first load makes no request; reconnect loads the token',
    (tester) async {
      var online = false;
      final connection = StreamController<bool>();
      addTearDown(connection.close);
      final simulation = simulatedPublic();
      final fake = PublicRepositoryFake(
        () => simulation.lookup(simulation.engine.featuredToken),
      );
      await tester.pumpWidget(
        publicPage(
          repository: fake,
          token: 'offline',
          online: () => online,
          connectivity: connection.stream,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("You're offline"), findsOneWidget);
      expect(fake.lookups, 0);
      online = true;
      connection.add(true);
      await tester.pumpAndSettle();
      expect(find.text('CURRENT RECORD STATUS'), findsOneWidget);
      expect(fake.lookups, 1);
    },
  );

  testWidgets('stale evidence never hides an open confirmed concern', (
    tester,
  ) async {
    final historical = historicalLookup();
    await tester.pumpWidget(
      publicPage(
        repository: PublicRepositoryFake(() async => historical),
        token: historical.record!.token,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No valid current data'), findsOneWidget);
    expect(find.text('Historical record'), findsOneWidget);
    expect(find.text(historical.record!.wording), findsOneWidget);
    expect(find.text('Confirmed finding'), findsOneWidget);
    expect(
      find.textContaining('outdated under the 30-day review window'),
      findsOneWidget,
    );
    expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
  });

  testWidgets(
    'failed refresh retains dated concerns as a snapshot; revoked access clears it',
    (tester) async {
      final simulation = simulatedPublic();
      final record = (await simulation.lookup(
        simulation.engine.featuredToken,
      )).record!;
      final fake = PublicRepositoryFake(() => simulation.lookup(record.token));
      await tester.pumpWidget(
        publicPage(repository: fake, token: record.token),
      );
      await tester.pumpAndSettle();
      fake.load = () async =>
          throw const PublicRequestFailure(PublicFailureKind.unavailable);
      await tester.tap(find.byTooltip('Refresh public record'));
      await tester.pumpAndSettle();
      expect(find.text('Snapshot not refreshed'), findsOneWidget);
      expect(find.text('CURRENT RECORD STATUS'), findsNothing);
      expect(find.text('LAST LOADED RECORD STATUS'), findsOneWidget);
      expect(find.text(record.wording), findsOneWidget);
      final reportButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Report a concern'),
      );
      expect(reportButton.onPressed, isNull);
      fake.load = () async => const PublicPointLookup.revoked();
      await tester.tap(find.byTooltip('Refresh public record'));
      await tester.pumpAndSettle();
      expect(find.text('This QR label has been revoked'), findsOneWidget);
      expect(find.text(record.pointLabel), findsNothing);
      expect(find.text(record.wording), findsNothing);
    },
  );

  testWidgets(
    'open page expires after five minutes without pretending a new sample exists',
    (tester) async {
      var now = DateTime.utc(2026, 11, 5, 8);
      final simulation = simulatedPublic();
      await tester.pumpWidget(
        publicPage(
          repository: simulation,
          token: simulation.engine.featuredToken,
          clock: () => now,
        ),
      );
      await tester.pumpAndSettle();
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Snapshot not refreshed'), findsOneWidget);
      expect(find.text('LAST LOADED RECORD STATUS'), findsOneWidget);
    },
  );

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1440, 1000),
  ]) {
    testWidgets(
      'success, text-first, share and print preserve the public record at ${size.width}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final simulation = simulatedPublic();
        final record = (await simulation.lookup(
          simulation.engine.featuredToken,
        )).record!;
        String? printed;
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          publicPage(
            repository: simulation,
            token: record.token,
            onPrint: (html) => printed = html,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'SIMULATED DEMONSTRATION\nGenerated records, not real water tests.',
          ),
          findsOneWidget,
        );
        expect(find.text(record.wording), findsOneWidget);
        expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
        expect(find.textContaining('Reported value:'), findsOneWidget);
        expect(find.textContaining('Detection limit:'), findsOneWidget);
        for (final timestamp in [
          'Collected',
          'Tested',
          'Reviewed',
          'Published',
        ]) {
          expect(find.text(timestamp), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Text-first view'));
        await tester.pumpAndSettle();
        expect(find.byType(WaterNetworkArtwork), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text(record.wording), findsOneWidget);
        await tester.ensureVisible(find.text('Share link'));
        await tester.tap(find.text('Share link'));
        await tester.pumpAndSettle();
        expect(
          clipboard,
          'https://verify.example.test/demo/#/point/${record.token}?view=text',
        );
        await tester.tap(find.text('Print view'));
        await tester.pumpAndSettle();
        expect(printed, contains(PublicWaterRecord.limitation));
        expect(printed, contains('SIMULATED DEMONSTRATION'));
        expect(printed, contains('Printed snapshot, not a live update.'));
        expect(printed, contains(record.wording));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('missing evidence and unreviewed samples are explicit', (
    tester,
  ) async {
    final simulation = simulatedPublic(day: 2);
    final unreviewed = simulation.engine.results.values.firstWhere(
      (r) => !r.isReviewed && r.state != ResultState.rejected,
    );
    final token = simulation.engine.qrs
        .singleWhere((qr) => qr.pointId == unreviewed.sample.pointId)
        .token;
    await tester.pumpWidget(publicPage(repository: simulation, token: token));
    await tester.pumpAndSettle();
    expect(find.text('No valid current data'), findsWidgets);
    expect(find.text('No reviewed result to show'), findsOneWidget);
    expect(find.text('Unverified records are awaiting review'), findsOneWidget);
    expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
  });
}
