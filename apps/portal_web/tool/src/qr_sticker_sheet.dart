import 'dart:convert';
import 'package:qr/qr.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_portal/public/public_point_link.dart';

class DemoQrSticker {
  const DemoQrSticker({
    required this.pointLabel,
    required this.facilityLabel,
    required this.link,
    required this.svg,
  });
  final String pointLabel;
  final String facilityLabel;
  final Uri link;
  final String svg;
}

String _escape(Object value) => const HtmlEscape().convert('$value');

void validateStickerBase(Uri base) {
  if (!{'http', 'https'}.contains(base.scheme) ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    throw const FormatException(
      'Use the reachable HTTP(S) portal base URL, without credentials, query or fragment.',
    );
  }
}

String qrStickerSvg(Uri link) {
  final image = QrImage(
    QrCode.fromData(
      data: link.toString(),
      errorCorrectLevel: QrErrorCorrectLevel.M,
    ),
  );
  // At 38 mm this retains modules wider than 0.5 mm, including the quiet zone.
  if (image.moduleCount > 65) {
    throw const FormatException(
      'The portal URL is too long for a readable 38 mm sticker QR. Use a shorter portal base URL.',
    );
  }
  final side = image.moduleCount + 8;
  final path = StringBuffer();
  for (var row = 0; row < image.moduleCount; row++) {
    for (var column = 0; column < image.moduleCount; column++) {
      if (image.isDark(row, column)) {
        path.write('M${column + 4} ${row + 4}h1v1h-1z');
      }
    }
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $side $side" role="img" aria-label="QR code for this water point" shape-rendering="crispEdges"><rect width="$side" height="$side" fill="white"/><path d="$path" fill="black"/></svg>';
}

List<DemoQrSticker> demoQrStickers({
  required SimulationEngine engine,
  required Uri base,
  required int day,
  bool connected = false,
  int? facilityIndex,
}) {
  validateStickerBase(base);
  if (day < 0 || day > 365) {
    throw const FormatException('Day must be between 0 and 365.');
  }
  if (facilityIndex != null &&
      (facilityIndex < 0 || facilityIndex >= engine.facilities.length)) {
    throw FormatException(
      'Facility index must be between 0 and ${engine.facilities.length - 1}.',
    );
  }
  return [
    for (final qr in engine.qrs.where(
      (qr) =>
          !qr.isRevoked &&
          (facilityIndex == null ||
              qr.scope.matches(engine.facilities[facilityIndex].scope)),
    ))
      (() {
        final record = engine.publicRecord(qr.token)!;
        final link = publicPointLink(
          base: base,
          token: qr.token,
          seed: connected ? null : engine.seed,
          day: connected ? null : day,
        );
        return DemoQrSticker(
          pointLabel: record.pointLabel,
          facilityLabel: record.facilityLabel,
          link: link,
          svg: qrStickerSvg(link),
        );
      })(),
  ];
}

String demoStickerSheet({
  required Uri base,
  int seed = 20261101,
  int day = 10,
  bool connected = false,
  int? facilityIndex,
}) {
  if (day < 0 || day > 365) {
    throw const FormatException('Day must be between 0 and 365.');
  }
  final engine = SimulationEngine(seed: seed)..advance(Duration(days: day));
  final modelVersion =
      (engine.toJson()['simulation'] as Map<String, Object?>)['model_version'];
  final stickers = demoQrStickers(
    engine: engine,
    base: base,
    day: day,
    connected: connected,
    facilityIndex: facilityIndex,
  );
  final pages = <String>[];
  for (var start = 0; start < stickers.length; start += 6) {
    pages.add(
      '''<section class="sheet" aria-label="Sticker sheet ${pages.length + 1}">
<header><strong>tankloop · VERIFY</strong><span>SIMULATED DEMO DATA</span></header>
<div class="stickers">${stickers.skip(start).take(6).map((sticker) => '''
<article class="sticker" data-public-url="${_escape(sticker.link)}">
<p class="demo-label">SIMULATED DEMO</p>
<div class="identity"><h2>${_escape(sticker.pointLabel)}</h2><p>${_escape(sticker.facilityLabel)}</p></div>
<a class="qr" href="${_escape(sticker.link)}" aria-label="Open ${_escape(sticker.pointLabel)}, ${_escape(sticker.facilityLabel)}">${sticker.svg}</a>
<p class="instruction">Scan to see this water point's latest checked record</p>
</article>''').join()}</div>
<footer>Generated records, not real water tests. · Seed $seed · Day $day · Model $modelVersion<br>Exercise clock: ${_escape(engine.now.toIso8601String())} · Sheet ${pages.length + 1} of ${(stickers.length / 6).ceil()}</footer>
</section>''',
    );
  }
  return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer">
<title>TankLoop simulated demo QR stickers</title><style>
@page{size:A4 portrait;margin:10mm}*{box-sizing:border-box}body{font-family:system-ui,sans-serif;color:#102a43;background:#edf6f5;margin:0}h1,h2,p{margin:0}.controls{max-width:190mm;margin:24px auto;padding:20px;background:white;border-radius:20px}.controls p{margin:12px 0;overflow-wrap:anywhere}button{min-height:48px;font:600 16px system-ui;padding:12px 24px;border:0;border-radius:24px;background:#102a43;color:white}.sheet{width:190mm;margin:16px auto;padding:0;background:white;break-after:page}.sheet:last-child{break-after:auto}header{height:12mm;display:flex;align-items:center;justify-content:space-between;gap:4mm;font-size:10pt}header span{font-size:8pt;font-weight:700}.stickers{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:4mm}.sticker{min-width:0;height:80mm;border:0.3mm dashed #526777;border-radius:3mm;padding:4mm;display:grid;grid-template-rows:5mm 12mm 38mm minmax(0,1fr);gap:1.5mm;text-align:center;break-inside:avoid}.demo-label{font-weight:800;font-size:9pt;letter-spacing:1px;border:0.3mm solid #102a43;justify-self:center;padding:0 3mm}.identity h2{font-size:15pt;line-height:1.15}.identity p{font-size:9pt;margin-top:1mm}.qr{display:block;width:38mm;height:38mm;justify-self:center;background:white}.qr svg{display:block;width:100%;height:100%}.instruction{font-size:10pt;line-height:1.25;align-self:center}footer{height:12mm;font-size:8pt;line-height:1.4;padding-top:3mm;text-align:center}a:focus-visible,button:focus-visible{outline:3px solid #0f766e;outline-offset:3px}@media screen and (max-width:760px){.sheet{width:auto;margin:12px}.controls{margin:12px}.stickers{grid-template-columns:minmax(0,1fr)}header{padding:0 8px}footer{height:auto;padding:12px}}@media print{body{background:white}.controls{display:none}.sheet{margin:0}.demo-label{color:black}.sticker{border-color:#526777}a{color:inherit}}
</style></head><body>
<div class="controls"><h1>Physical demo QR stickers</h1><p>SIMULATED DEMO DATA. ${stickers.length} stickers, six per A4 sheet. Print at 100% scale on A4, with browser headers and footers off. Cut on the dashed lines. The black QR includes a four-module white quiet zone.</p><p>Portal: ${_escape(base)}<br>${connected ? 'Connected demo: the database must use the matching simulator seed.' : 'Standalone simulation: each link retains its seed and exercise day.'}</p><button type="button" onclick="window.print()">Print A4 / save PDF</button></div>
${pages.join('\n')}
</body></html>''';
}
