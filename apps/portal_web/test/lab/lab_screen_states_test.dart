import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/lab/lab_controller.dart';
import 'package:tankloop_portal/lab/lab_navigation.dart';
import 'package:tankloop_portal/lab/widgets/lab_record_widgets.dart';
import 'package:tankloop_portal/lab/widgets/lab_screen_frame.dart';
import 'lab_test_support.dart';

void main() {
  for (final section in LabSection.values) {
    group('${section.label} screen: all seven states', () {
      final state = switch (section) {
        LabSection.inbox => ResultState.valid,
        LabSection.intake => ResultState.collected,
        LabSection.results => ResultState.tested,
        LabSection.revisions => ResultState.published,
      };
      final successTitle = switch (section) {
        LabSection.inbox => 'Needs attention',
        LabSection.intake => 'Record intake decision',
        LabSection.results => 'Authorized attestation',
        LabSection.revisions => 'Preserved result history',
      };
      final emptyTitle = switch (section) {
        LabSection.inbox => 'No samples waiting',
        LabSection.intake => 'No samples received',
        LabSection.results => 'No result records yet',
        LabSection.revisions => 'No reviewed results to revise',
      };

      Future<void> render(WidgetTester tester, LabController controller) =>
          tester.pumpWidget(
            labTestApp(labScreen(section, controller), controller: controller),
          );

      testWidgets('loading uses accessible design-system skeletons', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final repository = TestLabRepository(await generatedLabWorkspace());
        final pending = Completer<LabWorkspace>();
        repository.onLoad = (_) => pending.future;
        final controller = LabController(repository, clock: () => labNow);
        unawaited(controller.refresh());
        await render(tester, controller);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(LabLoadingSkeleton), findsOneWidget);
        expect(find.byType(FrostedSkeleton), findsWidgets);
        expect(
          find.bySemanticsLabel('Loading ${section.label}'),
          findsOneWidget,
        );
        expect(find.byType(LabSampleIdentity), findsNothing);
        expect(controller.canWrite, false);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('empty explains the missing evidence', (tester) async {
        final repository = TestLabRepository(
          await generatedLabWorkspace(empty: true),
        );
        final controller = LabController(repository, clock: () => labNow);
        await controller.refresh();
        await render(tester, controller);
        await tester.pumpAndSettle();
        expect(controller.phase, LabPhase.empty);
        expect(find.text(emptyTitle), findsOneWidget);
        expect(find.byType(LabRecordPicker), findsNothing);
        expect(controller.canWrite, false);
        expect(tester.takeException(), isNull);
      });

      testWidgets('error has a working server retry', (tester) async {
        final repository = TestLabRepository(
          await generatedLabWorkspace(state: state),
        );
        repository.onLoad = (_) async => throw const RepositoryFailure(
          FailureKind.transient,
          'The lab service is unavailable.',
        );
        final controller = LabController(repository, clock: () => labNow);
        await controller.refresh();
        await render(tester, controller);
        await tester.pumpAndSettle();
        expect(controller.phase, LabPhase.error);
        expect(find.text('${section.label} unavailable'), findsOneWidget);
        expect(controller.canWrite, false);
        repository.onLoad = null;
        await tester.tap(find.text('Refresh lab records'));
        await tester.pumpAndSettle();
        expect(find.text(successTitle), findsOneWidget);
        expect(controller.phase, LabPhase.success);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'permission denied removes previously visible private records',
        (tester) async {
          final repository = TestLabRepository(
            await generatedLabWorkspace(state: state),
          );
          final controller = LabController(repository, clock: () => labNow);
          await controller.refresh();
          await render(tester, controller);
          repository.onLoad = (_) async => throw const RepositoryFailure(
            FailureKind.permission,
            'Your laboratory assignment was revoked.',
          );
          await controller.refresh();
          await tester.pumpAndSettle();
          expect(controller.phase, LabPhase.permissionDenied);
          expect(find.text('Laboratory access required'), findsOneWidget);
          expect(find.byType(LabSampleIdentity), findsNothing);
          expect(find.byType(LabRecordTile), findsNothing);
          expect(find.byType(LabRecordPicker), findsNothing);
          expect(controller.workspace, isNull);
          expect(controller.receipt, isNull);
          expect(controller.canWrite, false);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('offline retains cached evidence and disables all writes', (
        tester,
      ) async {
        final repository = TestLabRepository(
          await generatedLabWorkspace(state: state),
        );
        final controller = LabController(repository, clock: () => labNow);
        await controller.refresh();
        await render(tester, controller);
        repository.onLoad = (_) async => throw const LabConnectionFailure();
        await controller.refresh();
        await tester.pumpAndSettle();
        expect(controller.phase, LabPhase.offline);
        expect(find.text('Offline - read-only'), findsOneWidget);
        expect(find.text(successTitle), findsOneWidget);
        expect(controller.workspace, same(repository.workspace));
        expect(controller.canWrite, false);
        for (final button in tester.widgetList<FilledButton>(
          find.byType(FilledButton),
        )) {
          expect(button.onPressed, isNull);
        }
        expect(repository.commands, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('stale is explicit after the five-minute freshness window', (
        tester,
      ) async {
        final repository = TestLabRepository(
          await generatedLabWorkspace(state: state),
        );
        var clock = labNow;
        final controller = LabController(repository, clock: () => clock);
        await controller.refresh();
        final collected =
            controller.workspace!.records.first.sample.collectedAt;
        await render(tester, controller);
        clock = clock.add(const Duration(minutes: 6));
        await tester.pump(const Duration(minutes: 6));
        await tester.pumpAndSettle();
        expect(controller.phase, LabPhase.stale);
        expect(find.text('Stale record - refresh required'), findsOneWidget);
        expect(find.text(successTitle), findsOneWidget);
        expect(controller.canWrite, false);
        expect(
          controller.workspace!.records.first.sample.collectedAt,
          collected,
        );
        for (final button in tester.widgetList<FilledButton>(
          find.byType(FilledButton),
        )) {
          expect(button.onPressed, isNull);
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'success preserves provenance, scope and simulation disclosure',
        (tester) async {
          final repository = TestLabRepository(
            await generatedLabWorkspace(state: state),
          );
          final controller = LabController(repository, clock: () => labNow);
          await controller.refresh();
          await render(tester, controller);
          await tester.pumpAndSettle();
          expect(controller.phase, LabPhase.success);
          expect(find.text(successTitle), findsOneWidget);
          expect(
            find.text(
              'SIMULATED DEMONSTRATION\nGenerated records, not real water tests.',
            ),
            findsOneWidget,
          );
          expect(find.text('Independently reviewed'), findsNothing);
          expect(find.byType(LabLoadingSkeleton), findsNothing);
          expect(controller.receipt, isNull);
          if (section == LabSection.results) {
            expect(
              find.text('Lab-uploaded · Authorized review pending'),
              findsOneWidget,
            );
            expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
            expect(find.textContaining('Detection limit:'), findsOneWidget);
          }
          if (section == LabSection.revisions) {
            expect(find.text('Simulated lab review'), findsWidgets);
            expect(find.text('Signed report'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    });
  }
}
