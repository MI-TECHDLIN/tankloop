import 'entities.dart';
import 'incidents.dart';
import 'results.dart';
import 'work_orders.dart';

enum PublicState {
  noValidCurrentData('No valid current data'),
  riskObserved('Risk observed'),
  underInvestigation('Under investigation'),
  confirmedFinding('Confirmed finding'),
  correctiveActionUnderway('Corrective action underway'),
  followUpReviewed('Follow-up reviewed');

  const PublicState(this.label);
  final String label;
}

String isoDate(DateTime value) =>
    value.toUtc().toIso8601String().split('T').first;

class PublicTest {
  const PublicTest({
    required this.indicator,
    required this.method,
    required this.value,
    required this.units,
    required this.detectionLimit,
    required this.collectedAt,
    required this.testedAt,
    required this.reviewedAt,
    required this.publishedAt,
    required this.isSimulated,
  });
  final Indicator indicator;
  final String method;
  final double value;
  final ResultUnit units;
  final double detectionLimit;
  final DateTime collectedAt;
  final DateTime testedAt;
  final DateTime reviewedAt;
  final DateTime publishedAt;
  final bool isSimulated;
  String get valueText => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
  String get exactFinding {
    if (indicator == Indicator.hydrogenSulfide) {
      return 'H₂S screening indicator ${value > 0 ? 'detected' : 'not detected'} in this sample on ${isoDate(collectedAt)}. This does not establish E. coli presence or absence.';
    }
    if (value == 0) {
      return 'No ${indicator.label} detected in this sample on ${isoDate(collectedAt)}; other hazards were not assessed.';
    }
    return '${indicator.label} detected in this sample on ${isoDate(collectedAt)} ($valueText ${units.label}); other hazards were not assessed.';
  }

  Map<String, Object?> toJson() => {
    'indicator': wireName(indicator),
    'method': method,
    'value': value,
    'units': wireName(units),
    'detection_limit': detectionLimit,
    'collected_at': collectedAt.toUtc().toIso8601String(),
    'tested_at': testedAt.toUtc().toIso8601String(),
    'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    'published_at': publishedAt.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
  };
  factory PublicTest.fromJson(Map<String, dynamic> j) => PublicTest(
    indicator: enumFromWire(Indicator.values, j['indicator'] as String),
    method: j['method'] as String,
    value: (j['value'] as num).toDouble(),
    units: enumFromWire(ResultUnit.values, j['units'] as String),
    detectionLimit: (j['detection_limit'] as num).toDouble(),
    collectedAt: DateTime.parse(j['collected_at'] as String),
    testedAt: DateTime.parse(j['tested_at'] as String),
    reviewedAt: DateTime.parse(j['reviewed_at'] as String),
    publishedAt: DateTime.parse(j['published_at'] as String),
    isSimulated: j['is_simulated'] as bool,
  );
}

class PublicConcern {
  const PublicConcern({
    required this.source,
    required this.state,
    required this.reportedAt,
    required this.isSimulated,
  });
  final EvidenceSource source;
  final IncidentState state;
  final DateTime reportedAt;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'source': wireName(source),
    'state': wireName(state),
    'reported_at': reportedAt.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
  };
  factory PublicConcern.fromJson(Map<String, dynamic> j) => PublicConcern(
    source: enumFromWire(EvidenceSource.values, j['source'] as String),
    state: enumFromWire(IncidentState.values, j['state'] as String),
    reportedAt: DateTime.parse(j['reported_at'] as String),
    isSimulated: j['is_simulated'] as bool,
  );
}

/// Deliberately excludes staff, reporter contacts, private locations and report files.
class PublicWaterRecord {
  PublicWaterRecord({
    required this.token,
    required this.pointLabel,
    required this.facilityLabel,
    required this.timezone,
    required this.state,
    required this.wording,
    required this.updatedAt,
    required this.isSimulated,
    required this.isCurrent,
    required List<PublicConcern> concerns,
    required List<PublicTest> tests,
    this.actionWording,
  }) : concerns = List.unmodifiable(concerns),
       tests = List.unmodifiable(tests);
  final String token;
  final String pointLabel;
  final String facilityLabel;
  final String timezone;
  final PublicState state;
  final String wording;
  final String? actionWording;
  final DateTime updatedAt;
  final bool isSimulated;
  final bool isCurrent;
  final List<PublicConcern> concerns;
  final List<PublicTest> tests;
  PublicTest? get latestTest => tests.firstOrNull;
  static const limitation =
      'A test describes one sample, at one point, at one time. It does not establish the safety of the whole water system.';

  Map<String, Object?> toJson() => {
    'token': token,
    'point_label': pointLabel,
    'facility_label': facilityLabel,
    'timezone': timezone,
    'state': wireName(state),
    'wording': wording,
    'action_wording': actionWording,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
    'is_current': isCurrent,
    'concerns': concerns.map((c) => c.toJson()).toList(),
    'tests': tests.map((t) => t.toJson()).toList(),
  };
  factory PublicWaterRecord.fromJson(Map<String, dynamic> j) =>
      PublicWaterRecord(
        token: j['token'] as String,
        pointLabel: j['point_label'] as String,
        facilityLabel: j['facility_label'] as String,
        timezone: j['timezone'] as String,
        state: enumFromWire(PublicState.values, j['state'] as String),
        wording: j['wording'] as String,
        actionWording: j['action_wording'] as String?,
        updatedAt: DateTime.parse(j['updated_at'] as String),
        isSimulated: j['is_simulated'] as bool,
        isCurrent: j['is_current'] as bool,
        concerns: (j['concerns'] as List)
            .map((v) => PublicConcern.fromJson(v as Map<String, dynamic>))
            .toList(),
        tests: (j['tests'] as List)
            .map((v) => PublicTest.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}

class PublicQr {
  PublicQr._({
    required this.token,
    required this.pointId,
    required this.scope,
    required this.issuedAt,
    required this.isSimulated,
    required this.history,
    this.revokedAt,
  });
  factory PublicQr.issue({
    required String token,
    required String pointId,
    required Scope scope,
    required DateTime at,
    required bool isSimulated,
  }) {
    requireRule(
      token.length >= 32,
      'opaque_token_required',
      'Use an opaque, non-sequential public token.',
    );
    return PublicQr._(
      token: token,
      pointId: pointId,
      scope: scope,
      issuedAt: at.toUtc(),
      isSimulated: isSimulated,
      history: const [],
    );
  }
  final String token;
  final String pointId;
  final Scope scope;
  final DateTime issuedAt;
  final bool isSimulated;
  final List<DomainEvent> history;
  final DateTime? revokedAt;
  bool get isRevoked => revokedAt != null;
  PublicQr revoke(CommandContext context) {
    context.authorize(scope, {Role.manager, Role.admin});
    requireRule(
      !isRevoked && !context.at.isBefore(issuedAt),
      'invalid_revocation',
      'This QR is already revoked or the timestamp is invalid.',
    );
    return PublicQr._(
      token: token,
      pointId: pointId,
      scope: scope,
      issuedAt: issuedAt,
      isSimulated: isSimulated,
      revokedAt: context.at,
      history: recordTransition(
        history: history,
        context: context,
        scope: scope,
        id: token,
        from: 'active',
        to: 'revoked',
        isSimulated: isSimulated,
      ),
    );
  }

  // Tokens are permanently bound to one point. Rotation issues a new token and
  // preserves the old record and revocation audit instead of reattaching it.
  Map<String, Object?> toJson() => {
    'token': token,
    'point_id': pointId,
    ...scope.toJson(),
    'issued_at': issuedAt.toIso8601String(),
    'revoked_at': revokedAt?.toUtc().toIso8601String(),
    'is_simulated': isSimulated,
  };
}

PublicWaterRecord? projectPublicRecord({
  required PublicQr qr,
  required SamplingPoint point,
  required Facility facility,
  required Iterable<ResultRecord> results,
  required Iterable<IncidentRecord> incidents,
  required Iterable<WorkOrder> workOrders,
  required DateTime now,
  Duration freshFor = const Duration(days: 30),
}) {
  if (qr.isRevoked) return null;
  requireRule(
    qr.pointId == point.id &&
        qr.scope.matches(point.scope) &&
        facility.scope.matches(point.scope),
    'projection_scope',
    'The QR identity must match the water point.',
  );
  final published =
      results
          .where(
            (r) =>
                r.sample.pointId == point.id &&
                r.sample.scope.matches(point.scope) &&
                r.state == ResultState.published &&
                r.isReviewed &&
                !r.publishedAt!.isAfter(now),
          )
          .toList()
        ..sort((a, b) => b.sample.collectedAt.compareTo(a.sample.collectedAt));
  final tests = published
      .map(
        (r) => PublicTest(
          indicator: r.measurement!.indicator,
          method: r.measurement!.method,
          value: r.measurement!.value,
          units: r.measurement!.unit,
          detectionLimit: r.measurement!.detectionLimit,
          collectedAt: r.sample.collectedAt,
          testedAt: r.testedAt!,
          reviewedAt: r.reviewedAt!,
          publishedAt: r.publishedAt!,
          isSimulated: r.isSimulated,
        ),
      )
      .toList();
  final current =
      tests.isNotEmpty &&
      !tests.first.collectedAt.isAfter(now) &&
      now.difference(tests.first.collectedAt) <= freshFor;
  final open =
      incidents
          .where(
            (i) =>
                i.scope.matches(point.scope) &&
                i.pointIds.contains(point.id) &&
                i.isOpen,
          )
          .toList()
        ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
  final confirmed = open
      .where(
        (i) =>
            i.source == EvidenceSource.laboratory &&
            results.any(
              (r) =>
                  r.id == i.sourceId && r.isReviewed && r.measurement!.detected,
            ),
      )
      .firstOrNull;
  final underway = workOrders.any(
    (w) =>
        open.any((i) => i.id == w.incidentId) &&
        w.approvedBy != null &&
        {
          WorkOrderState.assigned,
          WorkOrderState.inProgress,
          WorkOrderState.completed,
          WorkOrderState.accepted,
          WorkOrderState.rework,
        }.contains(w.state),
  );
  final observed = open
      .where(
        (i) =>
            i.source == EvidenceSource.inspection &&
            {IncidentState.reported, IncidentState.triaged}.contains(i.state),
      )
      .firstOrNull;
  final PublicState state;
  final String wording;
  if (confirmed != null) {
    final finding = results.singleWhere((r) => r.id == confirmed.sourceId);
    state = PublicState.confirmedFinding;
    wording =
        'A verified ${finding.measurement!.indicator.label} finding was recorded on ${isoDate(finding.reviewedAt!)}.';
  } else if (underway) {
    state = PublicState.correctiveActionUnderway;
    wording = 'Work is underway. Verification has not yet been completed.';
  } else if (observed != null) {
    state = PublicState.riskObserved;
    wording =
        'Inspection concern reported on ${isoDate(observed.reportedAt)}. Testing may be needed.';
  } else if (open.isNotEmpty) {
    state = PublicState.underInvestigation;
    wording = 'A water-quality concern is being investigated.';
  } else if (current) {
    state = PublicState.followUpReviewed;
    wording =
        'Follow-up sample reviewed on ${isoDate(tests.first.reviewedAt)}; ${tests.first.exactFinding}';
  } else {
    state = PublicState.noValidCurrentData;
    wording = 'We do not have a current verified test record for this point.';
  }
  return PublicWaterRecord(
    token: qr.token,
    pointLabel: point.label,
    facilityLabel: facility.label,
    timezone: facility.timezone,
    state: state,
    wording: wording,
    actionWording: confirmed != null && underway
        ? 'Work is underway. Verification has not yet been completed.'
        : null,
    updatedAt: now.toUtc(),
    isSimulated: point.isSimulated,
    isCurrent: current,
    concerns: open
        .map(
          (i) => PublicConcern(
            source: i.source,
            state: i.state,
            reportedAt: i.reportedAt,
            isSimulated: i.isSimulated,
          ),
        )
        .toList(),
    tests: tests,
  );
}
