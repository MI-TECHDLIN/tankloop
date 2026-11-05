import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';
import 'package:tankloop_portal/public/public_point_link.dart';
import 'package:tankloop_portal/public/public_record_document.dart';
import 'package:tankloop_portal/public/public_test_card.dart';
import 'public_test_support.dart';

void main() {
  testWidgets(
    'reported fractional values remain exact on screen and in print',
    (tester) async {
      final simulation = simulatedPublic();
      final original = simulation.engine.publicRecord(
        simulation.engine.featuredToken,
      )!;
      final sample = PublicTest.fromJson({
        ...original.latestTest!.toJson(),
        'value': 7.25,
        'units': 'mpn_per100ml',
        'detection_limit': .125,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: tankLoopTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicTestCard(
                test: sample,
                timezone: original.timezone,
                historical: false,
                textFirst: true,
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Reported value: 7.25 ${sample.units.label}'),
        findsOneWidget,
      );
      expect(
        find.text('Detection limit: 0.125 ${sample.units.label}'),
        findsOneWidget,
      );
      expect(sample.exactFinding, contains('(7.25 ${sample.units.label})'));
      final record = PublicWaterRecord.fromJson({
        ...original.toJson(),
        'tests': [sample.toJson()],
      });
      final html = publicRecordDocument(
        lookup: PublicPointLookup.found(record),
        link: Uri.parse('https://verify.example.test/'),
        loadedAt: original.updatedAt,
        isSnapshot: false,
      );
      expect(
        html,
        contains(const HtmlEscape().convert('(7.25 ${sample.units.label})')),
      );
      expect(
        html,
        contains(const HtmlEscape().convert('0.125 ${sample.units.label}')),
      );
    },
  );

  test('canonical links retain only public routing and exercise parameters', () {
    final link = publicPointLink(
      base: Uri.parse(
        'https://staff:private@verify.example.test:8443/demo/?access_token=private#/lab',
      ),
      token: 'ab' * 16,
      seed: 123,
      day: 4,
      textFirst: true,
    );
    expect(
      link.toString(),
      'https://verify.example.test:8443/demo/#/point/${'ab' * 16}?seed=123&day=4&view=text',
    );
    expect(link.userInfo, isEmpty);
    expect(link.hasQuery, isFalse);
    expect(
      publicPointLink(base: link, token: 'cd' * 16).fragment,
      '/point/${'cd' * 16}',
    );
  });

  test(
    'print view preserves status, all concerns, timestamps, scope and history',
    () {
      final lookup = historicalLookup();
      final record = lookup.record!;
      final html = publicRecordDocument(
        lookup: PublicPointLookup.found(record, hasUnreviewedResults: true),
        link: publicPointLink(
          base: Uri.parse('https://verify.example.test/demo/'),
          token: record.token,
        ),
        loadedAt: DateTime.utc(2026, 11, 5, 8),
        isSnapshot: true,
      );
      expect(html, contains('@page{size:A4'));
      expect(html, contains('Printed snapshot, not a live update.'));
      expect(html, contains('Snapshot not refreshed.'));
      expect(html, contains('SIMULATED DEMONSTRATION'));
      expect(html, contains('Generated records, not real water tests.'));
      expect(html, contains(record.wording));
      if (record.actionWording != null) {
        expect(html, contains(record.actionWording!));
      }
      expect(html, contains(PublicWaterRecord.limitation));
      expect(html, contains('No valid current data'));
      expect(html, contains('Unverified records are awaiting review.'));
      expect(html, contains('Open concerns (${record.concerns.length})'));
      for (final concern in record.concerns) {
        expect(
          html,
          contains(recordTime(concern.reportedAt, timezone: record.timezone)),
        );
      }
      for (final sample in record.tests) {
        expect(html, contains(const HtmlEscape().convert(sample.exactFinding)));
        for (final timestamp in [
          sample.collectedAt,
          sample.testedAt,
          sample.reviewedAt,
          sample.publishedAt,
        ]) {
          expect(
            html,
            contains(recordTime(timestamp, timezone: record.timezone)),
          );
        }
      }
      expect(html, isNot(contains('report_ref')));
      expect(html, isNot(contains('reviewed_by')));
    },
  );

  test(
    'print output escapes database text rather than turning it into markup',
    () {
      final base = simulatedPublic().engine;
      final original = base.publicRecord(base.featuredToken)!;
      final record = PublicWaterRecord.fromJson({
        ...original.toJson(),
        'point_label': '<img src=x onerror=alert(1)>',
        'facility_label': 'North & South "court"',
        'wording': '<script>alert(1)</script>',
      });
      final html = publicRecordDocument(
        lookup: PublicPointLookup.found(record),
        link: Uri.parse('https://verify.example.test/'),
        loadedAt: base.now,
        isSnapshot: false,
      );
      expect(html, isNot(contains('<img src=x')));
      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
      expect(html, contains('North &amp; South &quot;court&quot;'));
    },
  );
}
