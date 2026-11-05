import 'dart:convert';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:tankloop_localization/localization.dart';

/// Printable HTML consumes the same narrow projection as the public screen.
/// No private source objects or attachments are accepted by this renderer.
String publicRecordDocument({
  required PublicPointLookup lookup,
  required Uri link,
  required DateTime loadedAt,
  required bool isSnapshot,
}) {
  final record = lookup.record!;
  String escape(Object value) => const HtmlEscape().convert('$value');
  String time(DateTime value) =>
      escape(recordTime(value, timezone: record.timezone));
  String section(String title, String body) =>
      '<section><h2>${escape(title)}</h2>$body</section>';
  String test(PublicTest value) => section(
    value.indicator.label,
    '''
    <p class="tag">${value.isSimulated ? 'Simulated lab review' : 'Independently reviewed'}</p>
    <p>${escape(value.exactFinding)}</p>
    <dl><dt>Method</dt><dd>${escape(value.method)}</dd>
    <dt>Reported value</dt><dd>${escape(value.valueText)} ${escape(value.units.label)}</dd>
    <dt>Detection limit</dt><dd>${escape(value.detectionLimit)} ${escape(value.units.label)}</dd>
    <dt>Collected</dt><dd>${time(value.collectedAt)}</dd>
    <dt>Tested</dt><dd>${time(value.testedAt)}</dd>
    <dt>Reviewed</dt><dd>${time(value.reviewedAt)}</dd>
    <dt>Published</dt><dd>${time(value.publishedAt)}</dd></dl>
    <p>Other hazards and other sampling points were not assessed by this sample.</p>''',
  );
  return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><title>TankLoop Verify - ${escape(record.pointLabel)}</title>
<style>
@page{size:A4;margin:14mm}*{box-sizing:border-box}body{font:15px/1.5 system-ui,sans-serif;color:#102a43;background:#f6f8fa;margin:0;padding:24px}main{max-width:780px;margin:auto;background:white;padding:28px;border:1px solid #b3c9c7;border-radius:20px}h1{font-size:32px;line-height:1.2}h2{font-size:20px}p,dd,a{overflow-wrap:anywhere}section{border-top:1px solid #b3c9c7;margin-top:20px;padding-top:12px;break-inside:avoid}dl{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,2fr);gap:6px 16px}dt{font-weight:650}dd{margin:0;min-width:0}.notice{border:2px solid #88501c;padding:14px;border-radius:10px}.tag{font-weight:700}.actions{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:24px}button,.actions a{font:inherit;min-height:48px;padding:12px 20px;border:1px solid #102a43;border-radius:24px;background:white;color:#102a43}.brand{font-weight:800;letter-spacing:1px}a{color:#0f766e}@media(max-width:500px){body{padding:12px}main{padding:18px}dl{grid-template-columns:minmax(0,1fr)}}@media print{body{padding:0;background:white;font-size:10pt}main{max-width:none;border:0;padding:0}.actions{display:none}h1{font-size:24pt}h2{font-size:14pt}a{color:inherit}.notice{border-radius:0}}
</style></head><body><main>
<nav class="actions" aria-label="Print actions"><button type="button" onclick="window.print()">Print / save PDF</button><a href="${escape(link)}" rel="noopener">Open point record</a></nav>
<p class="brand">tankloop · VERIFY</p>
${record.isSimulated ? '<p class="notice"><strong>SIMULATED DEMONSTRATION</strong><br>Generated records, not real water tests.</p>' : ''}
<p>${escape(record.facilityLabel)}</p><h1>${escape(record.pointLabel)}</h1>
<p><strong>Printed snapshot, not a live update.</strong> Match this name to the water point on the label.</p>
<p>Loaded on device: ${time(loadedAt)}<br>${record.isSimulated ? 'Simulated record clock' : 'Record checked'}: ${time(record.updatedAt)}</p>
${isSnapshot ? '<p class="notice">Snapshot not refreshed. This record may be out of date. Open the point link and refresh before relying on it.</p>' : ''}
${section(record.state.label, '<p>${escape(record.wording)}</p>${record.actionWording == null ? '' : '<p>${escape(record.actionWording!)}</p>'}')}
<p class="notice">${escape(PublicWaterRecord.limitation)}</p>
${!record.isCurrent ? '<p><strong>No valid current data</strong><br>We do not have a current verified test record for this point. Any published samples below are historical.</p>' : ''}
${lookup.hasUnreviewedResults ? '<p><strong>Unverified records are awaiting review.</strong> A field observation or an unreviewed sample is not a verified laboratory finding.</p>' : ''}
<h2>Last verified record</h2>
${record.latestTest == null ? '<p>No reviewed result to show.</p>' : test(record.latestTest!)}
<p>${record.isSimulated ? 'The 30-day demonstration review window is a demo policy, not an approved monitoring schedule.' : 'The current record service uses a 30-day review window.'} Currentness is not proof of continuing water quality.</p>
<h2>Open concerns (${record.concerns.length})</h2>
${record.concerns.isEmpty ? '<p>No open concerns recorded. This is not a water-safety certification.</p>' : record.concerns.map((concern) => section(concern.source == EvidenceSource.residentReport ? 'Unverified resident report' : humanState(wireName(concern.source)), '<p>Response: ${escape(humanState(wireName(concern.state)))}<br>Reported ${time(concern.reportedAt)}</p>${concern.state == IncidentState.verificationPending ? '<p>Repair recorded; verification is still pending.</p>' : ''}')).join()}
${record.tests.length > 1 ? '<h2>Historical published samples</h2>${record.tests.skip(1).map(test).join()}' : ''}
<section><h2>Latest record and concern reporting</h2><p>Open this public link to refresh the record or report a concern. Contact details and private report descriptions are never printed here.</p><a href="${escape(link)}" rel="noopener">${escape(link)}</a></section>
</main></body></html>''';
}
