import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_domain/domain.dart';
import '../../tool/src/qr_sticker_sheet.dart';

void main() {
  test(
    'every sticker opens its simulator water point with the same seed and day',
    () {
      for (final seed in [20261101, 12345]) {
        final engine = SimulationEngine(seed: seed)
          ..advance(const Duration(days: 10));
        final stickers = demoQrStickers(
          engine: engine,
          base: Uri.parse('https://verify.example.test/demo/'),
          day: 10,
        );
        expect(stickers.length, engine.qrs.where((qr) => !qr.isRevoked).length);
        expect(
          stickers.map((sticker) => sticker.link).toSet().length,
          stickers.length,
        );
        for (final sticker in stickers) {
          final route = Uri.parse(sticker.link.fragment);
          expect(route.queryParameters, {'seed': '$seed', 'day': '10'});
          final record = engine.publicRecord(route.pathSegments.last)!;
          expect(sticker.pointLabel, record.pointLabel);
          expect(sticker.facilityLabel, record.facilityLabel);
          expect(record.isSimulated, isTrue);
          expect(sticker.link.path, '/demo/');
        }
      }
    },
  );

  test(
    'QR artwork is vector-only with a four-module quiet zone and readable modules',
    () {
      final engine = SimulationEngine();
      final stickers = demoQrStickers(
        engine: engine,
        base: Uri.parse('https://verify.example.test/'),
        day: 0,
      );
      for (final sticker in stickers) {
        final svg = sticker.svg;
        final bounds = RegExp(r'viewBox="0 0 (\d+) (\d+)"').firstMatch(svg)!;
        final side = int.parse(bounds[1]!);
        expect(bounds[2], '$side');
        expect(38 / side, greaterThan(.5));
        expect(svg, contains('fill="white"'));
        expect(svg, contains('fill="black"'));
        final modules = RegExp(
          r'M(\d+) (\d+)h1v1h-1z',
        ).allMatches(svg).toList();
        expect(modules, isNotEmpty);
        for (final module in modules) {
          expect(int.parse(module[1]!), inInclusiveRange(4, side - 5));
          expect(int.parse(module[2]!), inInclusiveRange(4, side - 5));
        }
        expect(svg, isNot(contains('<image')));
        expect(svg, isNot(contains('href=')));
      }
    },
  );

  test(
    'A4 sheet is deterministic, self-contained and visibly discloses every sticker',
    () {
      final base = Uri.parse('https://verify.example.test/field&lab/');
      final html = demoStickerSheet(base: base);
      final count = SimulationEngine().qrs.length;
      expect(demoStickerSheet(base: base), html);
      expect(
        RegExp(r'<article class="sticker"').allMatches(html).length,
        count,
      );
      expect(
        RegExp(r'<section class="sheet"').allMatches(html).length,
        (count / 6).ceil(),
      );
      expect(
        RegExp(
          r'<p class="demo-label">SIMULATED DEMO</p>',
        ).allMatches(html).length,
        count,
      );
      expect(
        RegExp(
          "Scan to see this water point's latest checked record",
        ).allMatches(html).length,
        count,
      );
      expect(html, contains('@page{size:A4 portrait;margin:10mm}'));
      expect(html, contains('grid-template-columns:repeat(2,minmax(0,1fr))'));
      expect(html, contains('Seed 20261101 · Day 10 · Model 1'));
      expect(html, contains('Generated records, not real water tests.'));
      expect(html, contains('field&amp;lab'));
      expect(html, isNot(contains('<img')));
      expect(html, isNot(contains('<script src')));
      expect(html, isNot(contains('<link')));
    },
  );

  test(
    'connected sheets omit exercise overrides and facility filters match generated identities',
    () {
      final engine = SimulationEngine();
      final stickers = demoQrStickers(
        engine: engine,
        base: Uri.parse('https://verify.example.test/'),
        day: 0,
        connected: true,
        facilityIndex: 1,
      );
      expect(stickers, isNotEmpty);
      for (final sticker in stickers) {
        expect(Uri.parse(sticker.link.fragment).hasQuery, isFalse);
        expect(sticker.facilityLabel, engine.facilities[1].label);
      }
    },
  );

  test('revoked tokens are omitted from printable labels', () {
    final engine = SimulationEngine();
    final qr = engine.qrs.first;
    engine.qrs[0] = qr.revoke(
      CommandContext(
        actor: engine.actorFor(qr.scope, Role.manager),
        at: engine.now,
        eventId: 'qr-print-revocation',
        serverConfirmed: true,
        reason: 'Replace simulated label',
      ),
    );
    final stickers = demoQrStickers(
      engine: engine,
      base: Uri.parse('https://verify.example.test/'),
      day: 0,
    );
    expect(stickers.length, engine.qrs.length - 1);
    expect(
      stickers.any((sticker) => sticker.link.fragment.contains(qr.token)),
      isFalse,
    );
  });

  test(
    'invalid configuration and over-dense QR artwork fail before printing',
    () {
      for (final url in [
        'file:///demo/',
        'javascript:alert(1)',
        'https://staff:private@verify.example.test/',
        'https://verify.example.test/?token=private',
        'https://verify.example.test/#/lab',
      ]) {
        expect(
          () => demoStickerSheet(base: Uri.parse(url)),
          throwsFormatException,
        );
      }
      expect(
        () => demoStickerSheet(
          base: Uri.parse('https://verify.example.test/'),
          day: 366,
        ),
        throwsFormatException,
      );
      expect(
        () => demoStickerSheet(
          base: Uri.parse('https://verify.example.test/'),
          facilityIndex: 99,
        ),
        throwsFormatException,
      );
      expect(
        () => qrStickerSvg(
          Uri.parse('https://verify.example.test/${'long' * 200}'),
        ),
        throwsFormatException,
      );
    },
  );
}
