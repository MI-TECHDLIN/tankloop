import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';

const eventId = 'c0000000-0000-4000-8000-000000000001';
final token = 'a' * 32;

PublicConcernSubmission concern({
  String? publicToken,
  String id = eventId,
  String description = 'A simulated smell concern for private review.',
  String? contact,
  bool consent = false,
}) => PublicConcernSubmission(
  eventId: id,
  token: publicToken ?? token,
  category: ConcernCategory.smell,
  description: description,
  contact: contact,
  contactConsent: consent,
);

Matcher failure(PublicFailureKind kind) => throwsA(
  isA<PublicRequestFailure>().having((error) => error.kind, 'kind', kind),
);

SupabasePublicPointRepository rpcRepository(
  Future<http.Response> Function(http.Request) respond,
) {
  final client = SupabaseClient(
    'http://127.0.0.1:55481',
    'unit-test-placeholder',
    httpClient: MockClient((request) async {
      final response = await respond(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  addTearDown(client.dispose);
  return SupabasePublicPointRepository(client);
}

void main() {
  test(
    'simulation reports use guarded incidents, retain evidence and replay receipts',
    () async {
      final engine = SimulationEngine();
      final repository = SimulationPublicPointRepository(engine: engine);
      final qr = engine.qrs.first;
      final before = (await repository.lookup(qr.token)).record!;
      final command = concern(
        publicToken: qr.token,
        contact: 'private@example.invalid',
        consent: true,
      );
      final receipt = await repository.submitConcern(command);
      final repeated = await repository.submitConcern(command);
      expect(repeated, same(receipt));
      expect(receipt.receivedAt, engine.now);
      expect(receipt.isSimulated, isTrue);
      final after = (await repository.lookup(qr.token)).record!;
      expect(after.state, PublicState.underInvestigation);
      expect(after.wording, 'A water-quality concern is being investigated.');
      expect(
        after.tests.map((value) => value.toJson()),
        before.tests.map((value) => value.toJson()),
      );
      expect(after.concerns.length, before.concerns.length + 1);
      expect(after.concerns.single.source, EvidenceSource.residentReport);
      expect(after.concerns.single.state, IncidentState.reported);
      expect(engine.incidents[eventId]!.scope.matches(qr.scope), isTrue);
      expect(engine.incidents[eventId]!.pointIds, [qr.pointId]);
      expect(
        engine.observationEvents.where((event) => event.id == eventId),
        hasLength(1),
      );
      final publicJson = jsonEncode(after.toJson());
      expect(publicJson, isNot(contains(command.description)));
      expect(publicJson, isNot(contains(command.contact!)));
      final other = engine.qrs.firstWhere((item) => item.pointId != qr.pointId);
      expect((await repository.lookup(other.token)).record!.concerns, isEmpty);
      await expectLater(
        repository.submitConcern(
          concern(
            publicToken: qr.token,
            description: 'Changed private description.',
          ),
        ),
        failure(PublicFailureKind.conflict),
      );
    },
  );

  test(
    'revocation removes public evidence and prevents new or replayed submissions',
    () async {
      final engine = SimulationEngine();
      final repository = SimulationPublicPointRepository(engine: engine);
      final qr = engine.qrs.first;
      final command = concern(publicToken: qr.token);
      await repository.submitConcern(command);
      engine.qrs[0] = qr.revoke(
        CommandContext(
          actor: engine.actorFor(qr.scope, Role.manager),
          at: engine.now,
          eventId: 'c0000000-0000-4000-8000-000000000002',
          serverConfirmed: true,
          reason: 'Replace simulated printed label.',
        ),
      );
      final revoked = await repository.lookup(qr.token);
      expect(revoked.status, PublicLookupStatus.revoked);
      expect(revoked.record, isNull);
      await expectLater(
        repository.submitConcern(command),
        failure(PublicFailureKind.revoked),
      );
      expect(
        (await repository.lookup('f' * 32)).status,
        PublicLookupStatus.missing,
      );
      expect(
        (await repository.lookup('point-1')).status,
        PublicLookupStatus.missing,
      );
    },
  );

  test(
    'only aggregate unreviewed metadata reaches the public projection',
    () async {
      final engine = SimulationEngine()..advance(const Duration(days: 2));
      final repository = SimulationPublicPointRepository(engine: engine);
      final unreviewed = engine.results.values.firstWhere(
        (result) => !result.isReviewed && result.state != ResultState.rejected,
      );
      final qr = engine.qrs.singleWhere(
        (item) => item.pointId == unreviewed.sample.pointId,
      );
      final lookup = await repository.lookup(qr.token);
      expect(lookup.hasUnreviewedResults, isTrue);
      expect(lookup.record!.tests, isEmpty);
      expect(
        jsonEncode(lookup.record!.toJson()),
        isNot(contains(unreviewed.id)),
      );
    },
  );

  test(
    'invalid token, event identity, description and contact consent make no HTTP request',
    () async {
      var requests = 0;
      final repository = rpcRepository((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      for (final command in [
        concern(publicToken: 'point-1'),
        concern(id: 'not-an-event'),
        concern(description: '    '),
        concern(description: 'x' * 2001),
        concern(contact: 'private@example.invalid'),
        concern(consent: true),
        concern(contact: 'x', consent: true),
        concern(contact: 'x' * 321, consent: true),
      ]) {
        await expectLater(
          repository.submitConcern(command),
          failure(PublicFailureKind.invalid),
        );
      }
      expect(
        (await repository.lookup('point-1')).status,
        PublicLookupStatus.missing,
      );
      expect(requests, 0);
    },
  );

  test(
    'SDK uses the narrow lookup envelope, including revoked and missing states',
    () async {
      final engine = SimulationEngine()..advance(const Duration(days: 10));
      final record = engine.publicRecord(engine.featuredToken)!;
      final repository = rpcRepository((request) async {
        expect(request.url.path, '/rest/v1/rpc/lookup_public_point');
        expect(jsonDecode(request.body), {'p_token': record.token});
        return http.Response(
          jsonEncode({
            'status': 'found',
            'record': record.toJson(),
            'has_unreviewed_results': true,
          }),
          200,
        );
      });
      final lookup = await repository.lookup(record.token);
      expect(lookup.record!.toJson(), record.toJson());
      expect(lookup.hasUnreviewedResults, isTrue);
      for (final status in ['missing', 'revoked']) {
        final unavailable = rpcRepository(
          (_) async => http.Response(jsonEncode({'status': status}), 200),
        );
        final result = await unavailable.lookup(token);
        expect(result.status.name, status);
        expect(result.record, isNull);
      }
    },
  );

  test(
    'anonymous SDK submits only input fields and trusts a matching server receipt',
    () async {
      final command = concern();
      final receivedAt = DateTime.utc(2026, 11, 5);
      final repository = rpcRepository((request) async {
        expect(request.url.path, '/rest/v1/rpc/submit_public_concern');
        expect(jsonDecode(request.body), {
          'p_event_id': eventId,
          'p_token': token,
          'p_category': 'smell',
          'p_description': command.description,
          'p_contact': null,
          'p_contact_consent': false,
        });
        return http.Response(
          jsonEncode({
            'event_id': eventId,
            'received_at': receivedAt.toIso8601String(),
            'is_simulated': true,
          }),
          200,
        );
      });
      final receipt = await repository.submitConcern(command);
      expect(receipt.eventId, command.eventId);
      expect(receipt.receivedAt, receivedAt);
      expect(receipt.isSimulated, isTrue);
      final mismatched = rpcRepository(
        (_) async => http.Response(
          jsonEncode({
            'event_id': 'another-command',
            'received_at': receivedAt.toIso8601String(),
            'is_simulated': true,
          }),
          200,
        ),
      );
      await expectLater(
        mismatched.submitConcern(command),
        failure(PublicFailureKind.unavailable),
      );
    },
  );

  for (final entry in {
    '42501': PublicFailureKind.permission,
    'PGRST301': PublicFailureKind.permission,
    '22023': PublicFailureKind.invalid,
    '23514': PublicFailureKind.invalid,
    '23505': PublicFailureKind.conflict,
    'PT429': PublicFailureKind.rateLimited,
    'PT410': PublicFailureKind.revoked,
    'XX000': PublicFailureKind.unavailable,
  }.entries) {
    test('public SDK maps ${entry.key} without exposing server text', () async {
      final repository = rpcRepository(
        (_) async => http.Response(
          jsonEncode({
            'code': entry.key,
            'message': 'Private server diagnostics',
          }),
          400,
        ),
      );
      await expectLater(
        repository.submitConcern(concern()),
        failure(entry.value),
      );
    });
  }

  test('HTTP failure remains unavailable, not an empty water record', () async {
    final repository = rpcRepository(
      (_) async => throw http.ClientException('Network unavailable'),
    );
    await expectLater(
      repository.lookup(token),
      failure(PublicFailureKind.unavailable),
    );
  });
}
