import 'package:tankloop_domain/domain.dart';

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

Facility _facility(Map<String, dynamic> j) => Facility(
  id: j['id'] as String,
  organizationId: j['organization_id'] as String,
  label: j['public_label'] as String,
  timezone: j['timezone'] as String,
  isSimulated: j['is_simulated'] as bool,
);

/// A read projection, not a client-side result state machine. Only the server
/// can supply an attestation or create a superseding revision through this API.
class LabRecord {
  LabRecord.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      version = j['version'] as int,
      state = enumFromWire(ResultState.values, j['state'] as String),
      source = enumFromWire(EvidenceSource.values, j['source'] as String),
      pointLabel = j['point_label'] as String,
      openIncidentCount = j['open_incident_count'] as int,
      receivedAt = _date(j['received_at']),
      testedAt = _date(j['tested_at']),
      reviewedAt = _date(j['reviewed_at']),
      publishedAt = _date(j['published_at']),
      reviewedBy = j['reviewed_by'] as String?,
      reportRef = j['report_ref'] as String?,
      rejectionReason = j['rejection_reason'] as String?,
      revisionOf = j['revision_of'] as String?,
      correctionReason = j['correction_reason'] as String?,
      correctedBy = j['corrected_by'] as String?,
      correctedAt = _date(j['corrected_at']) {
    final s = j['sample'] as Map<String, dynamic>;
    sample = SampleRecord(
      id: s['id'] as String,
      code: s['code'] as String,
      scope: Scope(s['organization_id'] as String, s['facility_id'] as String),
      pointId: s['point_id'] as String,
      collectorId: s['collector_id'] as String,
      collectedAt: _date(s['collected_at'])!,
      intendedMethod: s['intended_method'] as String,
      isSimulated: s['is_simulated'] as bool,
    );
    preservationNote = s['preservation_note'] as String;
    measurement = j['value'] == null
        ? null
        : Measurement(
            indicator: enumFromWire(Indicator.values, j['indicator'] as String),
            method: j['method'] as String,
            value: (j['value'] as num).toDouble(),
            unit: enumFromWire(ResultUnit.values, j['units'] as String),
            detectionLimit: (j['detection_limit'] as num).toDouble(),
          );
    custody = List.unmodifiable(
      (j['custody'] as List).map((row) {
        final c = row as Map<String, dynamic>;
        return CustodyEvent(
          id: c['id'] as String,
          sampleId: c['sample_id'] as String,
          scope: sample.scope,
          fromActor: c['from_actor'] as String,
          toActor: c['to_actor'] as String,
          occurredAt: _date(c['occurred_at'])!,
          note: c['note'] as String,
          isSimulated: c['is_simulated'] as bool,
        );
      }),
    );
    audit = List.unmodifiable(
      (j['audit'] as List).map(
        (a) => LabAuditEvent.fromJson(a as Map<String, dynamic>),
      ),
    );
  }

  final String id;
  final int version;
  final ResultState state;
  final EvidenceSource source;
  final String pointLabel;
  final int openIncidentCount;
  late final SampleRecord sample;
  late final String preservationNote;
  late final Measurement? measurement;
  late final List<CustodyEvent> custody;
  late final List<LabAuditEvent> audit;
  final DateTime? receivedAt;
  final DateTime? testedAt;
  final DateTime? reviewedAt;
  final DateTime? publishedAt;
  final String? reviewedBy;
  final String? reportRef;
  final String? rejectionReason;
  final String? revisionOf;
  final String? correctionReason;
  final String? correctedBy;
  final DateTime? correctedAt;

  bool get needsIntake =>
      state == ResultState.collected || state == ResultState.received;
  bool get isReviewed =>
      (state == ResultState.reviewed || state == ResultState.published) &&
      source == EvidenceSource.laboratory &&
      hasText(reviewedBy) &&
      hasText(reportRef);
  bool get isHistorical => state == ResultState.superseded;
  bool get needsAttention =>
      needsIntake || state == ResultState.valid || state == ResultState.tested;
}

class LabAuditEvent {
  LabAuditEvent.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      actorId = j['actor_id'] as String?,
      at = _date(j['occurred_at'])!,
      from = j['previous_state'] as String,
      to = j['new_state'] as String,
      reason = j['reason'] as String;
  final String id;
  final String? actorId;
  final DateTime at;
  final String from;
  final String to;
  final String reason;
}

class LabWorkspace {
  LabWorkspace.fromJson(Map<String, dynamic> j)
    : facility = _facility(j['facility'] as Map<String, dynamic>),
      facilities = List.unmodifiable(
        (j['facilities'] as List).map(
          (f) => _facility(f as Map<String, dynamic>),
        ),
      ),
      actorId = j['actor_id'] as String,
      asOf = _date(j['as_of'])!,
      fetchedAt = _date(j['fetched_at'])!,
      simulationSeed = (j['simulation'] as Map)['simulation_seed'] as int?,
      modelVersion = (j['simulation'] as Map)['model_version'] as int?,
      records = List.unmodifiable(
        (j['records'] as List).map(
          (r) => LabRecord.fromJson(r as Map<String, dynamic>),
        ),
      );
  final Facility facility;
  final List<Facility> facilities;
  final String actorId;
  final DateTime asOf;
  final DateTime fetchedAt;
  final int? simulationSeed;
  final int? modelVersion;
  final List<LabRecord> records;

  List<LabRecord> get activeRecords =>
      records.where((r) => !r.isHistorical).toList();
  LabRecord? record(String? id) => records.where((r) => r.id == id).firstOrNull;
  List<LabRecord> lineage(LabRecord selected) {
    final family = {
      for (final row in records.where((r) => r.sample.id == selected.sample.id))
        row.id: row,
    };
    LabRecord? current =
        family.values.where((r) => !r.isHistorical).firstOrNull ?? selected;
    final chain = <LabRecord>[];
    final seen = <String>{};
    // Successive corrections can have the same simulated timestamp. Their
    // immutable parent links, rather than timestamp or ID order, are decisive.
    while (current != null && seen.add(current.id)) {
      chain.add(current);
      current = family[current.revisionOf];
    }
    return chain.reversed.toList();
  }
}

enum LabAction { accept, reject, enterResult, attest, correct }

class LabCommand {
  LabCommand({
    required this.eventId,
    required this.resultId,
    required this.expectedVersion,
    required this.action,
    required Map<String, Object?> payload,
    required this.reason,
  }) : payload = Map.unmodifiable(payload);
  final String eventId;
  final String resultId;
  final int expectedVersion;
  final LabAction action;
  final Map<String, Object?> payload;
  final String reason;

  Map<String, Object?> toParams() => {
    'p_event_id': eventId,
    'p_result_id': resultId,
    'p_expected_version': expectedVersion,
    'p_action': wireName(action),
    'p_payload': payload,
    'p_reason': reason,
  };
}

class LabReceipt {
  LabReceipt.fromJson(Map<String, dynamic> j)
    : eventId = j['client_event_id'] as String,
      resultId = j['result_id'] as String,
      previousResultId = j['previous_result_id'] as String,
      action = enumFromWire(LabAction.values, j['action'] as String),
      version = j['version'] as int,
      state = enumFromWire(ResultState.values, j['state'] as String),
      actorId = j['actor_id'] as String,
      recordedAt = _date(j['recorded_at'])!,
      isSimulated = j['is_simulated'] as bool;
  final String eventId;
  final String resultId;
  final String previousResultId;
  final LabAction action;
  final int version;
  final ResultState state;
  final String actorId;
  final DateTime recordedAt;
  final bool isSimulated;
}
