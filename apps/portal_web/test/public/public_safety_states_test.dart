import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'public_test_support.dart';

void main() {
  testWidgets(
    'all six safety headlines come from generated, guarded transitions',
    (tester) async {
      final engine = SimulationEngine();
      final states = <PublicState, PublicPointLookup>{};
      for (var hour = 0; hour <= 21 * 24; hour++) {
        engine.advanceTo(engine.startsAt.add(Duration(hours: hour)));
        for (final qr in engine.qrs) {
          final record = engine.publicRecord(qr.token)!;
          states.putIfAbsent(
            record.state,
            () => PublicPointLookup.found(record),
          );
        }
      }
      final resident = simulatedPublic(day: 0);
      await resident.submitConcern(
        PublicConcernSubmission(
          eventId: '60000000-0000-4000-8000-000000000001',
          token: resident.engine.qrs.first.token,
          category: ConcernCategory.damage,
          description: 'Simulated leak reported by a resident.',
        ),
      );
      final investigation = await resident.lookup(
        resident.engine.qrs.first.token,
      );
      states[investigation.record!.state] = investigation;
      expect(states.keys, containsAll(PublicState.values));
      for (final state in PublicState.values) {
        final lookup = states[state]!;
        await tester.pumpWidget(
          publicPage(
            repository: PublicRepositoryFake(() async => lookup),
            token: lookup.record!.token,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(state.label), findsWidgets);
        expect(find.text(lookup.record!.wording), findsWidgets);
        expect(find.text(PublicWaterRecord.limitation), findsOneWidget);
        expect(find.text('SAFE'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'public controls meet accessible target, label and contrast guidelines',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = simulatedPublic();
      await tester.pumpWidget(
        publicPage(
          repository: repository,
          token: repository.engine.featuredToken,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );
}
