import 'entities.dart';

enum ResultState {
  collected,
  received,
  valid,
  rejected,
  tested,
  reviewed,
  published,
  superseded,
}

class SampleRecord {
  const SampleRecord({
    required this.id,
    required this.code,
    required this.scope,
    required this.pointId,
    required this.collectorId,
    required this.collectedAt,
    required this.intendedMethod,
    required this.isSimulated,
  });
  final String id;
  final String code;
  final Scope scope;
  final String pointId;
  final String collectorId;
  final DateTime collectedAt;
  final String intendedMethod;
  final bool isSimulated;
  Map<String, Object?> toJson() => {
    'id': id,
    'code': code,
    ...scope.toJson(),
    'point_id': pointId,
    'collector_id': collectorId,
    'collected_at': collectedAt.toUtc().toIso8601String(),
    'intended_method': intendedMethod,
    'is_simulated': isSimulated,
  };
}

class Measurement {
  Measurement({
    required this.indicator,
    required this.method,
    required this.value,
    required this.unit,
    required this.detectionLimit,
  }) {
    requireRule(
      hasText(method),
      'method_required',
      'Preserve the reported method.',
    );
    requireRule(
      value.isFinite &&
          value >= 0 &&
          detectionLimit.isFinite &&
          detectionLimit > 0,
      'invalid_measurement',
      'Use a non-negative finite value and a positive detection limit.',
    );
    requireRule(
      unit != ResultUnit.presenceAbsence || value == 0 || value == 1,
      'invalid_presence',
      'Presence/absence is 0 or 1.',
    );
    requireRule(
      indicator != Indicator.hydrogenSulfide ||
          unit == ResultUnit.presenceAbsence,
      'screening_units',
      'H₂S screening uses presence/absence, not an E. coli count.',
    );
  }
  final Indicator indicator;
  final String method;
  final double value;
  final ResultUnit unit;
  final double detectionLimit;
  bool get detected => value > 0;
  Map<String, Object?> toJson() => {
    'indicator': wireName(indicator),
    'method': method,
    'value': value,
    'units': wireName(unit),
    'detection_limit': detectionLimit,
  };
}

/// The result lifecycle is independent of work orders and incidents.
/// A rejected sample has no outgoing transition into a tested/negative result.
class ResultRecord {
  ResultRecord._({
    required this.id,
    required this.sample,
    required this.source,
    required this.state,
    required this.history,
    this.measurement,
    this.receivedAt,
    this.testedAt,
    this.reviewedAt,
    this.publishedAt,
    this.reviewedBy,
    this.reportRef,
    this.rejectionReason,
    this.revisionOf,
    this.correctionReason,
    this.correctedBy,
    this.correctedAt,
  });

  factory ResultRecord.collected({
    required String id,
    required SampleRecord sample,
    EvidenceSource source = EvidenceSource.laboratory,
  }) => ResultRecord._(
    id: id,
    sample: sample,
    source: source,
    state: ResultState.collected,
    history: const [],
  );

  static const transitions = <ResultState, Set<ResultState>>{
    ResultState.collected: {ResultState.received},
    ResultState.received: {ResultState.valid, ResultState.rejected},
    ResultState.valid: {ResultState.tested},
    ResultState.rejected: {},
    ResultState.tested: {ResultState.reviewed},
    ResultState.reviewed: {ResultState.published, ResultState.superseded},
    ResultState.published: {ResultState.superseded},
    ResultState.superseded: {},
  };

  final String id;
  final SampleRecord sample;
  final EvidenceSource source;
  final ResultState state;
  final List<DomainEvent> history;
  final Measurement? measurement;
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
  bool get isSimulated => sample.isSimulated;
  int get version => history.length;
  bool get isReviewed =>
      (state == ResultState.reviewed || state == ResultState.published) &&
      hasText(reviewedBy) &&
      hasText(reportRef) &&
      source == EvidenceSource.laboratory;
  Provenance get provenance => isReviewed
      ? Provenance.independentlyReviewed
      : source == EvidenceSource.fieldScreen
      ? Provenance.fieldScreened
      : source == EvidenceSource.laboratory
      ? Provenance.labUploaded
      : Provenance.userReported;
  VerificationStage get verificationStage => switch (state) {
    ResultState.collected => VerificationStage.draft,
    ResultState.received ||
    ResultState.valid ||
    ResultState.tested => VerificationStage.received,
    ResultState.rejected => VerificationStage.rejected,
    ResultState.reviewed || ResultState.published => VerificationStage.reviewed,
    ResultState.superseded => VerificationStage.superseded,
  };

  ResultRecord transition(
    ResultState target,
    CommandContext context, {
    Measurement? reading,
    String? linkedReport,
    String? rejection,
  }) {
    requireRule(
      transitions[state]!.contains(target) && target != ResultState.superseded,
      'invalid_result_transition',
      'Cannot move a result from ${state.name} to ${target.name}. Corrections use a revision.',
    );
    context.authorize(
      sample.scope,
      target == ResultState.published ? {Role.manager, Role.admin} : {Role.lab},
    );
    requireRule(
      !context.at.isBefore(sample.collectedAt),
      'time_order',
      'A result event cannot precede collection.',
    );
    if (target == ResultState.rejected) {
      requireRule(
        hasText(rejection),
        'rejection_reason',
        'Explain why this sample is invalid.',
      );
    }
    if (target == ResultState.tested) {
      requireRule(
        reading != null && reading.method == sample.intendedMethod,
        'measurement_required',
        'Record the sample plan method and exact indicator, value and units.',
      );
    }
    if (target == ResultState.reviewed) {
      requireRule(
        source == EvidenceSource.laboratory &&
            measurement != null &&
            hasText(linkedReport),
        'independent_review_required',
        'Independent review requires laboratory evidence, an authorized reviewer and a linked report.',
      );
    }
    return ResultRecord._(
      id: id,
      sample: sample,
      source: source,
      state: target,
      history: recordTransition(
        history: history,
        context: context,
        scope: sample.scope,
        id: id,
        from: state.name,
        to: target.name,
        isSimulated: isSimulated,
        evidenceIds: [?linkedReport],
      ),
      measurement: target == ResultState.tested ? reading : measurement,
      receivedAt: target == ResultState.received ? context.at : receivedAt,
      testedAt: target == ResultState.tested ? context.at : testedAt,
      reviewedAt: target == ResultState.reviewed ? context.at : reviewedAt,
      publishedAt: target == ResultState.published ? context.at : publishedAt,
      reviewedBy: target == ResultState.reviewed
          ? context.actor.id
          : reviewedBy,
      reportRef: target == ResultState.reviewed ? linkedReport : reportRef,
      rejectionReason: rejection ?? rejectionReason,
      revisionOf: revisionOf,
      correctionReason: correctionReason,
      correctedBy: correctedBy,
      correctedAt: correctedAt,
    );
  }

  ResultCorrection correct({
    required String newId,
    required Measurement reading,
    required String linkedReport,
    required CommandContext context,
  }) {
    context.authorize(sample.scope, {Role.lab});
    requireRule(
      isReviewed && newId != id && hasText(newId),
      'invalid_revision',
      'Only a reviewed record can be superseded by a new identifier.',
    );
    requireRule(
      hasText(linkedReport) &&
          reading.method == sample.intendedMethod &&
          reading.indicator == measurement!.indicator &&
          reading.unit == measurement!.unit,
      'correction_scope',
      'Keep the sample, indicator and method scope; link the corrected report.',
    );
    final audit = recordTransition(
      history: history,
      context: context,
      scope: sample.scope,
      id: id,
      from: state.name,
      to: 'superseded',
      isSimulated: isSimulated,
      evidenceIds: [newId, linkedReport],
    );
    return ResultCorrection(
      original: ResultRecord._(
        id: id,
        sample: sample,
        source: source,
        state: ResultState.superseded,
        history: audit,
        measurement: measurement,
        receivedAt: receivedAt,
        testedAt: testedAt,
        reviewedAt: reviewedAt,
        publishedAt: publishedAt,
        reviewedBy: reviewedBy,
        reportRef: reportRef,
        revisionOf: revisionOf,
        correctionReason: correctionReason,
        correctedAt: correctedAt,
        correctedBy: correctedBy,
      ),
      replacement: ResultRecord._(
        id: newId,
        sample: sample,
        source: source,
        state: ResultState.reviewed,
        history: const [],
        measurement: reading,
        receivedAt: receivedAt,
        testedAt: testedAt,
        reviewedAt: context.at,
        reviewedBy: context.actor.id,
        reportRef: linkedReport,
        revisionOf: id,
        correctionReason: context.reason,
        correctedBy: context.actor.id,
        correctedAt: context.at,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    ...sample.scope.toJson(),
    'sample_id': sample.id,
    'source': wireName(source),
    'state': wireName(state),
    if (measurement != null) ...measurement!.toJson(),
    'received_at': receivedAt?.toUtc().toIso8601String(),
    'tested_at': testedAt?.toUtc().toIso8601String(),
    'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
    'published_at': publishedAt?.toUtc().toIso8601String(),
    'reviewed_by': reviewedBy,
    'report_ref': reportRef,
    'rejection_reason': rejectionReason,
    'revision_of': revisionOf,
    'correction_reason': correctionReason,
    'corrected_by': correctedBy,
    'corrected_at': correctedAt?.toUtc().toIso8601String(),
    'version': version,
    'is_simulated': isSimulated,
  };
}

class ResultCorrection {
  const ResultCorrection({required this.original, required this.replacement});
  final ResultRecord original;
  final ResultRecord replacement;
}
