import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_design_system/design_system.dart';

void main() {
  // Label measurements need the real interface font, not the test font.
  setUpAll(() async {
    final loader = FontLoader(TankType.sans);
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      final bytes = File(
        'assets/fonts/PlusJakartaSans-$weight.ttf',
      ).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  test('every theme text style names the package-qualified sans family', () {
    final theme = tankLoopTheme();
    final styles = [
      theme.textTheme.displayMedium,
      theme.textTheme.headlineLarge,
      theme.textTheme.titleLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.labelSmall,
    ];
    for (final style in styles) {
      expect(
        style?.fontFamily,
        'packages/tankloop_design_system/PlusJakartaSans',
      );
    }
  });

  testWidgets('the wordmark resolves the bundled Playfair family', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: tankLoopTheme(), home: const TankBrand()),
    );
    final wordmark = tester.widget<Text>(find.text('tankloop'));
    expect(
      wordmark.style?.fontFamily,
      'packages/tankloop_design_system/PlayfairDisplay',
    );
  });

  testWidgets('a centered notice is only as tall as its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: tankLoopTheme(),
        home: const Scaffold(
          body: Center(
            child: NoticeCard(
              title: 'Assignments unavailable',
              message: 'Retry later.',
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(NoticeCard)).height, lessThan(200));
  });

  for (final (width, scale, full) in [
    (412.0, 1.0, true),
    (320.0, 2.0, false),
  ]) {
    testWidgets(
      'navigation at ${width.toInt()}dp and ${(scale * 100).toInt()}% text keeps whole labels',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: tankLoopTheme(),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: FloatingNav(
                  selected: selected,
                  onSelected: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final label in FloatingNav.labels) {
          expect(find.byTooltip(label), findsOneWidget);
          expect(find.bySemanticsLabel(label), findsOneWidget);
          expect(
            find.text(label),
            label == 'Today' || full ? findsOneWidget : findsNothing,
          );
        }
        final handle = tester.ensureSemantics();
        expect(
          tester.getSemantics(find.bySemanticsLabel('Activity')),
          isSemantics(
            label: 'Activity',
            isButton: true,
            hasSelectedState: true,
            isFocusable: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
        await tester.tap(find.byTooltip('Activity'));
        await tester.pumpAndSettle();
        expect(find.text('Activity'), findsOneWidget);
        final text = tester.widget<Text>(find.text('Activity'));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
