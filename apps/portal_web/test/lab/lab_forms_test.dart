import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/lab/lab_controller.dart';
import 'package:tankloop_portal/lab/lab_navigation.dart';
import 'lab_test_support.dart';

Future<void> tapLabel(WidgetTester tester, String text) async {
  final label = find.text(text).last;
  await tester.ensureVisible(label);
  await tester.tap(label);
  await tester.pumpAndSettle();
}

void main() {
  for (final unit in ResultUnit.values) {
    testWidgets(
      'entry submits exact ${unit.label} and the laboratory detection limit',
      (tester) async {
        final data = await generatedLabWorkspace(state: ResultState.valid);
        final repository = TestLabRepository(data);
        repository.onSubmit = (_) => Completer<LabReceipt>().future;
        final controller = LabController(repository, clock: () => labNow);
        await controller.refresh();
        await tester.pumpWidget(
          labTestApp(
            labScreen(LabSection.results, controller),
            controller: controller,
          ),
        );
        if (unit != ResultUnit.cfuPer100ml) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('lab-unit-cfuPer100ml')),
          );
          await tester.tap(find.byKey(const ValueKey('lab-unit-cfuPer100ml')));
          await tester.pumpAndSettle();
          await tapLabel(tester, unit.label);
        }
        if (unit == ResultUnit.presenceAbsence) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('lab-presence')),
          );
          await tester.tap(find.byKey(const ValueKey('lab-presence')));
          await tester.pumpAndSettle();
          await tapLabel(tester, 'Present (1)');
        } else {
          await tester.enterText(
            find.byKey(const ValueKey('lab-value')),
            '7.25',
          );
        }
        await tester.enterText(find.byKey(const ValueKey('lab-limit')), '0.5');
        await tester.enterText(
          find.byKey(const ValueKey('lab-reason')),
          'Exact transcription of simulated report',
        );
        await tapLabel(tester, 'Submit result for review');
        final command = repository.commands.single;
        expect(command.action, LabAction.enterResult);
        expect(command.payload['units'], wireName(unit));
        expect(
          command.payload['value'],
          unit == ResultUnit.presenceAbsence ? 1 : 7.25,
        );
        expect(command.payload['detection_limit'], .5);
        expect(
          command.payload['method'],
          data.record(command.resultId)!.sample.intendedMethod,
        );
        expect(command.expectedVersion, data.record(command.resultId)!.version);
        expect(controller.receipt, isNull);
        expect(find.text('Waiting for server receipt...'), findsOneWidget);
        expect(find.text('Simulated lab review'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'invalid counts and absent notes cannot cross the command boundary',
    (tester) async {
      final repository = TestLabRepository(
        await generatedLabWorkspace(state: ResultState.valid),
      );
      final controller = LabController(repository, clock: () => labNow);
      await controller.refresh();
      await tester.pumpWidget(
        labTestApp(
          labScreen(LabSection.results, controller),
          controller: controller,
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('lab-value')), 'NaN');
      await tester.enterText(find.byKey(const ValueKey('lab-limit')), '0');
      await tapLabel(tester, 'Submit result for review');
      expect(
        find.text('Enter a non-negative, finite value below 1,000,000,000.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Enter a positive, finite detection limit below 1,000,000,000.',
        ),
        findsOneWidget,
      );
      expect(find.text('This field is required.'), findsOneWidget);
      expect(repository.commands, isEmpty);
    },
  );

  testWidgets('H2S selection enforces screening presence/absence units', (
    tester,
  ) async {
    final repository = TestLabRepository(
      await generatedLabWorkspace(state: ResultState.valid),
    );
    final controller = LabController(repository, clock: () => labNow);
    await controller.refresh();
    await tester.pumpWidget(
      labTestApp(
        labScreen(LabSection.results, controller),
        controller: controller,
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('lab-indicator')));
    await tester.tap(find.byKey(const ValueKey('lab-indicator')));
    await tester.pumpAndSettle();
    await tapLabel(tester, Indicator.hydrogenSulfide.label);
    expect(find.byKey(const ValueKey('lab-presence')), findsOneWidget);
    final units = tester.widget<DropdownButtonFormField<ResultUnit>>(
      find.byKey(const ValueKey('lab-unit-presenceAbsence')),
    );
    expect(units.onChanged, isNull);
    expect(find.byKey(const ValueKey('lab-value')), findsNothing);
  });

  testWidgets('intake rejection requires both custody and rejection reason', (
    tester,
  ) async {
    final repository = TestLabRepository(
      await generatedLabWorkspace(state: ResultState.collected),
    );
    repository.onSubmit = (_) => Completer<LabReceipt>().future;
    final controller = LabController(repository, clock: () => labNow);
    await controller.refresh();
    await tester.pumpWidget(
      labTestApp(
        labScreen(LabSection.intake, controller),
        controller: controller,
      ),
    );
    await tapLabel(tester, 'Reject');
    await tapLabel(tester, 'Reject sample');
    expect(find.text('This field is required.'), findsNWidgets(2));
    expect(repository.commands, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('lab-custody')),
      'Simulated seal breach at handoff',
    );
    await tester.enterText(
      find.byKey(const ValueKey('lab-reason')),
      'Sample integrity rejected',
    );
    await tapLabel(tester, 'Reject sample');
    expect(repository.commands.single.action, LabAction.reject);
    expect(repository.commands.single.reason, 'Sample integrity rejected');
    expect(repository.commands.single.payload, {
      'custody_note': 'Simulated seal breach at handoff',
    });
    expect(
      find.textContaining('No valid result from this sample.'),
      findsOneWidget,
    );
    expect(controller.receipt, isNull);
    expect(
      controller.workspace!.records.any((r) => r.state == ResultState.rejected),
      false,
    );
  });

  testWidgets(
    'attestation validates signed evidence and recovers a lost acknowledgement',
    (tester) async {
      final data = await generatedLabWorkspace(state: ResultState.tested);
      final record = data.records.firstWhere(
        (r) => r.state == ResultState.tested,
      );
      final repository = TestLabRepository(data);
      repository.onSubmit = (_) async => throw const LabConnectionFailure();
      final controller = LabController(repository, clock: () => labNow);
      await controller.refresh();
      await tester.pumpWidget(
        labTestApp(
          labScreen(LabSection.results, controller, recordId: record.id),
          controller: controller,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('lab-report')),
        'file:///unsigned.txt',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lab-reason')),
        'Reviewed the synthetic report',
      );
      await tapLabel(tester, 'Attest result');
      expect(
        find.text(
          'Use an HTTPS signed report link or a simulation:// reference.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Confirm that you reviewed this sample and its signed report.',
        ),
        findsOneWidget,
      );
      expect(repository.commands, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('lab-report')),
        'simulation://signed-report',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Attest result');
      expect(controller.phase, LabPhase.offline);
      expect(controller.receipt, isNull);
      expect(find.text('simulation://signed-report'), findsOneWidget);
      expect(repository.commands.single.payload, {
        'report_ref': 'simulation://signed-report',
      });
      expect(find.text('Simulated lab review'), findsNothing);
      repository.workspace = await generatedLabWorkspace(
        state: ResultState.published,
        recordId: record.id,
      );
      await controller.refresh();
      await tester.pumpAndSettle();
      repository.onSubmit = (command) async => testReceipt(command, data);
      await tapLabel(tester, 'Retry unconfirmed action');
      expect(repository.commands.last, same(repository.commands.first));
      expect(controller.receipt, isNotNull);
      expect(
        find.text('Server receipt recorded - simulated data'),
        findsOneWidget,
      );
      expect(find.text('Retry unconfirmed action'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a manager publication preserves a revision draft but requires version review',
    (tester) async {
      final data = await generatedLabWorkspace(state: ResultState.reviewed);
      final record = data.records.firstWhere(
        (r) => r.state == ResultState.reviewed,
      );
      final repository = TestLabRepository(data);
      final controller = LabController(repository, clock: () => labNow);
      await controller.refresh();
      await tester.pumpWidget(
        labTestApp(
          labScreen(LabSection.revisions, controller, recordId: record.id),
          controller: controller,
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('lab-value')), '5');
      await tester.enterText(
        find.byKey(const ValueKey('lab-reason')),
        'Retain this correction draft',
      );
      repository.workspace = await generatedLabWorkspace(
        state: ResultState.published,
        recordId: record.id,
      );
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Retain this correction draft'), findsOneWidget);
      expect(find.text('A newer version is available'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Attest superseding revision'),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tapLabel(tester, 'Use latest record and reset draft');
      expect(find.text('A newer version is available'), findsNothing);
      expect(find.text('Retain this correction draft'), findsNothing);
      expect(repository.commands, isEmpty);
    },
  );

  testWidgets(
    'revision submits a new measurement without mutating original evidence',
    (tester) async {
      final data = await generatedLabWorkspace(state: ResultState.published);
      final record = data.records.firstWhere((r) => r.isReviewed);
      final repository = TestLabRepository(data);
      repository.onSubmit = (_) => Completer<LabReceipt>().future;
      final controller = LabController(repository, clock: () => labNow);
      await controller.refresh();
      await tester.pumpWidget(
        labTestApp(
          labScreen(LabSection.revisions, controller, recordId: record.id),
          controller: controller,
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('lab-value')), '3.5');
      await tester.enterText(find.byKey(const ValueKey('lab-limit')), '.25');
      await tester.enterText(
        find.byKey(const ValueKey('lab-report')),
        'https://reports.example/corrected',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lab-reason')),
        'Corrected decimal transcription',
      );
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Attest superseding revision');
      final command = repository.commands.single;
      expect(command.action, LabAction.correct);
      expect(command.resultId, record.id);
      expect(command.payload, {
        'value': 3.5,
        'detection_limit': .25,
        'report_ref': 'https://reports.example/corrected',
      });
      expect(command.reason, 'Corrected decimal transcription');
      expect(controller.workspace!.record(record.id), same(record));
      expect(find.text('Original result'), findsOneWidget);
      expect(find.text('Revision 1'), findsNothing);
      expect(controller.receipt, isNull);
    },
  );
}
