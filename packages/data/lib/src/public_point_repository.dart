import 'package:tankloop_domain/domain.dart';

enum PublicLookupStatus { found, missing, revoked }

/// Only the public projection and aggregate review metadata cross this boundary.
class PublicPointLookup {
  const PublicPointLookup.missing()
    : status = PublicLookupStatus.missing,
      record = null,
      hasUnreviewedResults = false;
  const PublicPointLookup.revoked()
    : status = PublicLookupStatus.revoked,
      record = null,
      hasUnreviewedResults = false;
  const PublicPointLookup.found(
    PublicWaterRecord this.record, {
    this.hasUnreviewedResults = false,
  }) : status = PublicLookupStatus.found;

  final PublicLookupStatus status;
  final PublicWaterRecord? record;
  final bool hasUnreviewedResults;

  factory PublicPointLookup.fromJson(Map<String, dynamic> json) =>
      switch (json['status']) {
        'found' => PublicPointLookup.found(
          PublicWaterRecord.fromJson(json['record'] as Map<String, dynamic>),
          hasUnreviewedResults: json['has_unreviewed_results'] == true,
        ),
        'revoked' => const PublicPointLookup.revoked(),
        'missing' => const PublicPointLookup.missing(),
        _ => throw const FormatException(
          'Unrecognized public lookup response.',
        ),
      };
}

enum PublicFailureKind {
  unavailable,
  permission,
  invalid,
  conflict,
  rateLimited,
  revoked,
}

class PublicRequestFailure implements Exception {
  const PublicRequestFailure(this.kind);
  final PublicFailureKind kind;
}

enum ConcernCategory {
  appearance('Appearance has changed'),
  smell('Unusual smell'),
  damage('Leak or damaged water point'),
  mismatch('The point label does not match'),
  other('Another concern');

  const ConcernCategory(this.label);
  final String label;
}

class PublicConcernSubmission {
  const PublicConcernSubmission({
    required this.eventId,
    required this.token,
    required this.category,
    required this.description,
    this.contact,
    this.contactConsent = false,
  });
  final String eventId;
  final String token;
  final ConcernCategory category;
  final String description;
  final String? contact;
  final bool contactConsent;

  void validate() {
    if (!isPublicToken(token) ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        ).hasMatch(eventId) ||
        description.trim().length < 5 ||
        description.length > 2000 ||
        (contact != null &&
            (!contactConsent ||
                contact!.trim().length < 3 ||
                contact!.length > 320)) ||
        (contactConsent && contact == null)) {
      throw const PublicRequestFailure(PublicFailureKind.invalid);
    }
  }

  Map<String, Object?> toParameters() => {
    'p_event_id': eventId,
    'p_token': token,
    'p_category': category.name,
    'p_description': description,
    'p_contact': contact,
    'p_contact_consent': contactConsent,
  };

  bool sameContent(PublicConcernSubmission other) =>
      token == other.token &&
      category == other.category &&
      description == other.description &&
      contact == other.contact &&
      contactConsent == other.contactConsent;
}

class PublicConcernReceipt {
  const PublicConcernReceipt({
    required this.eventId,
    required this.receivedAt,
    required this.isSimulated,
  });
  final String eventId;
  final DateTime receivedAt;
  final bool isSimulated;

  factory PublicConcernReceipt.fromJson(Map<String, dynamic> json) =>
      PublicConcernReceipt(
        eventId: json['event_id'] as String,
        receivedAt: DateTime.parse(json['received_at'] as String),
        isSimulated: json['is_simulated'] as bool,
      );
}

bool isPublicToken(String token) =>
    RegExp(r'^[a-f0-9]{32,128}$').hasMatch(token);

abstract class PublicPointRepository {
  const PublicPointRepository();
  Future<PublicPointLookup> lookup(String token);
  Future<PublicConcernReceipt> submitConcern(PublicConcernSubmission command);
}

/// An interactive exercise uses the same incident guard as the event engine.
/// Free text and contact details stay in this session, outside public records.
class SimulationPublicPointRepository extends PublicPointRepository {
  SimulationPublicPointRepository({required this.engine});
  final SimulationEngine engine;
  final _receipts = <String, (PublicConcernSubmission, PublicConcernReceipt)>{};

  @override
  Future<PublicPointLookup> lookup(String token) async {
    if (!isPublicToken(token)) return const PublicPointLookup.missing();
    final qr = engine.qrs.where((qr) => qr.token == token).firstOrNull;
    if (qr == null) return const PublicPointLookup.missing();
    if (qr.isRevoked) return const PublicPointLookup.revoked();
    return PublicPointLookup.found(
      engine.publicRecord(token)!,
      hasUnreviewedResults: engine.results.values.any(
        (result) =>
            result.sample.pointId == qr.pointId &&
            result.sample.scope.matches(qr.scope) &&
            {
              ResultState.collected,
              ResultState.received,
              ResultState.valid,
              ResultState.tested,
            }.contains(result.state),
      ),
    );
  }

  @override
  Future<PublicConcernReceipt> submitConcern(
    PublicConcernSubmission command,
  ) async {
    command.validate();
    final qr = engine.qrs.where((q) => q.token == command.token).firstOrNull;
    if (qr == null || qr.isRevoked) {
      throw const PublicRequestFailure(PublicFailureKind.revoked);
    }
    final prior = _receipts[command.eventId];
    if (prior != null) {
      if (!prior.$1.sameContent(command)) {
        throw const PublicRequestFailure(PublicFailureKind.conflict);
      }
      return prior.$2;
    }
    final point = engine.points.singleWhere((p) => p.id == qr.pointId);
    final asset = engine.assets.singleWhere((a) => a.id == point.assetId);
    final incident = IncidentRecord.report(
      id: command.eventId,
      scope: point.scope,
      systemId: asset.systemId,
      pointIds: [point.id],
      source: EvidenceSource.residentReport,
      sourceId: command.eventId,
      at: engine.now,
      isSimulated: true,
    );
    engine.incidents[incident.id] = incident;
    engine.observationEvents.add(
      DomainEvent(
        id: command.eventId,
        scope: point.scope,
        aggregateId: incident.id,
        actorId: 'anonymous-simulation',
        at: engine.now,
        from: 'none',
        to: 'reported',
        reason: 'Simulated resident concern received for review.',
        isSimulated: true,
      ),
    );
    final receipt = PublicConcernReceipt(
      eventId: command.eventId,
      receivedAt: engine.now,
      isSimulated: true,
    );
    _receipts[command.eventId] = (command, receipt);
    return receipt;
  }
}
