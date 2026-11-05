import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'public_test_support.dart';

Future<void> openForm(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Report a concern').first);
  await tester.tap(find.text('Report a concern').first);
  await tester.pumpAndSettle();
}

Future<void> fillConcern(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('concern-category')));
  await tester.tap(find.byKey(const ValueKey('concern-category')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Unusual smell').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('concern-description')),
    'Private description for manager review.',
  );
}

Future<void> sendConcern(
  WidgetTester tester, {
  String label = 'Send anonymous concern',
}) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets(
    'empty concern requires category and description, and defaults to anonymous',
    (tester) async {
      final repository = simulatedPublic();
      await tester.pumpWidget(
        publicPage(
          repository: repository,
          token: repository.engine.featuredToken,
        ),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      expect(find.textContaining('Anonymous by default.'), findsOneWidget);
      expect(find.byKey(const ValueKey('concern-contact')), findsNothing);
      await sendConcern(tester);
      await tester.pumpAndSettle();
      expect(find.text('Choose a concern category.'), findsOneWidget);
      expect(
        find.text('Add a description of at least 5 characters.'),
        findsOneWidget,
      );
      expect(find.text('Simulated concern received'), findsNothing);
    },
  );

  testWidgets(
    'loading waits for a real receipt and double taps cannot duplicate a report',
    (tester) async {
      final simulation = simulatedPublic();
      final fake = PublicRepositoryFake(
        () => simulation.lookup(simulation.engine.featuredToken),
      );
      final pending = Completer<PublicConcernReceipt>();
      fake.send = (_) => pending.future;
      await tester.pumpWidget(
        publicPage(repository: fake, token: simulation.engine.featuredToken),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      await fillConcern(tester);
      await sendConcern(tester);
      expect(find.text('Sending concern. Awaiting a receipt.'), findsOneWidget);
      expect(find.byType(FrostedSkeleton), findsOneWidget);
      expect(find.text('Simulated concern received'), findsNothing);
      await tester.ensureVisible(find.text('Awaiting receipt'));
      await tester.tap(find.text('Awaiting receipt'));
      expect(fake.commands, hasLength(1));
      expect(fake.commands.single.contact, isNull);
      expect(fake.commands.single.contactConsent, isFalse);
      pending.complete(
        PublicConcernReceipt(
          eventId: fake.commands.single.eventId,
          receivedAt: simulation.engine.now,
          isSimulated: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Simulated concern received'), findsOneWidget);
      expect(
        find.textContaining('Private description for manager review.'),
        findsNothing,
      );
    },
  );

  testWidgets('lost receipt retry sends the same event and content', (
    tester,
  ) async {
    final simulation = simulatedPublic();
    final fake = PublicRepositoryFake(
      () => simulation.lookup(simulation.engine.featuredToken),
    );
    fake.send = (_) async =>
        throw const PublicRequestFailure(PublicFailureKind.unavailable);
    await tester.pumpWidget(
      publicPage(repository: fake, token: simulation.engine.featuredToken),
    );
    await tester.pumpAndSettle();
    await openForm(tester);
    await fillConcern(tester);
    await sendConcern(tester);
    await tester.pumpAndSettle();
    expect(find.text('Concern not confirmed'), findsOneWidget);
    expect(find.textContaining('only in this open form'), findsOneWidget);
    fake.send = (command) async => PublicConcernReceipt(
      eventId: command.eventId,
      receivedAt: simulation.engine.now,
      isSimulated: true,
    );
    await sendConcern(tester, label: 'Retry concern');
    await tester.pumpAndSettle();
    expect(fake.commands, hasLength(2));
    expect(fake.commands.last.eventId, fake.commands.first.eventId);
    expect(fake.commands.last.sameContent(fake.commands.first), isTrue);
    expect(find.text('Simulated concern received'), findsOneWidget);
  });

  testWidgets(
    'permission-denied reporting makes no receipt or saved-device claim',
    (tester) async {
      final simulation = simulatedPublic();
      final fake = PublicRepositoryFake(
        () => simulation.lookup(simulation.engine.featuredToken),
      );
      fake.send = (_) async =>
          throw const PublicRequestFailure(PublicFailureKind.permission);
      await tester.pumpWidget(
        publicPage(repository: fake, token: simulation.engine.featuredToken),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      await fillConcern(tester);
      await sendConcern(tester);
      await tester.pumpAndSettle();
      expect(find.text('Public reporting access unavailable'), findsOneWidget);
      expect(find.textContaining('Permission denied'), findsOneWidget);
      expect(find.text('Simulated concern received'), findsNothing);
      expect(find.textContaining('saved on this device'), findsNothing);
    },
  );

  testWidgets(
    'offline form retains text only in the open form and blocks submission',
    (tester) async {
      var online = true;
      final connection = StreamController<bool>();
      addTearDown(connection.close);
      final simulation = simulatedPublic();
      final fake = PublicRepositoryFake(
        () => simulation.lookup(simulation.engine.featuredToken),
      );
      await tester.pumpWidget(
        publicPage(
          repository: fake,
          token: simulation.engine.featuredToken,
          online: () => online,
          connectivity: connection.stream,
        ),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      await fillConcern(tester);
      online = false;
      connection.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Offline - concern not sent'), findsOneWidget);
      expect(
        find.textContaining('not saved on this device or queued'),
        findsOneWidget,
      );
      await sendConcern(tester);
      expect(fake.commands, isEmpty);
      expect(
        find.text('Private description for manager review.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('stale point requires refresh before a concern can be sent', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 5, 10);
    final simulation = simulatedPublic();
    final fake = PublicRepositoryFake(
      () => simulation.lookup(simulation.engine.featuredToken),
    );
    await tester.pumpWidget(
      publicPage(
        repository: fake,
        token: simulation.engine.featuredToken,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();
    await openForm(tester);
    await fillConcern(tester);
    now = now.add(const Duration(minutes: 6));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Refresh the point record first'), findsOneWidget);
    await sendConcern(tester);
    expect(fake.commands, isEmpty);
  });

  testWidgets(
    'success adds an unverified simulated concern without publishing contact details',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final simulation = simulatedPublic();
      final token = simulation.engine.featuredToken;
      final before = (await simulation.lookup(token)).record!;
      await tester.pumpWidget(publicPage(repository: simulation, token: token));
      await tester.pumpAndSettle();
      await openForm(tester);
      await fillConcern(tester);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('concern-contact')),
        'private-reporter@example.invalid',
      );
      await sendConcern(tester, label: 'Send concern');
      await tester.pumpAndSettle();
      expect(find.text('Simulated concern received'), findsOneWidget);
      expect(
        find.textContaining('No facility or external service was contacted.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('private-reporter@example.invalid'),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Back to point record'));
      await tester.tap(find.text('Back to point record'));
      await tester.pumpAndSettle();
      final after = (await simulation.lookup(token)).record!;
      expect(after.concerns.length, before.concerns.length + 1);
      expect(
        after.tests.map((test) => test.toJson()),
        before.tests.map((test) => test.toJson()),
      );
      expect(find.text(after.wording), findsOneWidget);
      expect(find.text('Unverified resident report'), findsOneWidget);
      expect(
        find.textContaining('private-reporter@example.invalid'),
        findsNothing,
      );
      expect(
        find.textContaining('Private description for manager review.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
