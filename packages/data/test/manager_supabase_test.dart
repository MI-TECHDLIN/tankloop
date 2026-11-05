import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase/supabase.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';

const actorId = 'c9000000-0000-4000-8000-000000000001';
const facilityId = 'c2000000-0000-4000-8000-000000000001';
const organizationId = 'c1000000-0000-4000-8000-000000000001';

String session(String id) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return jsonEncode({
    'access_token':
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': id, 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})}.test-signature',
    'token_type': 'bearer',
    'refresh_token': 'test-refresh',
    'user': {
      'id': id,
      'aud': 'authenticated',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-11-01T00:00:00Z',
    },
  });
}

Future<SupabaseClient> clientFor(
  FutureOr<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
}) async {
  final client = SupabaseClient(
    'https://manager.test',
    'sb_publishable_test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    httpClient: MockClient((request) async {
      final result = await handler(request);
      return http.Response.bytes(
        result.bodyBytes,
        result.statusCode,
        headers: result.headers,
        request: request,
        reasonPhrase: result.reasonPhrase,
      );
    }),
  );
  addTearDown(client.dispose);
  if (signedIn) await client.auth.recoverSession(session(actorId));
  return client;
}

http.Response response(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
Matcher fails(FailureKind kind) =>
    throwsA(isA<RepositoryFailure>().having((e) => e.kind, 'kind', kind));

Map<String, Object?> workspaceJson() {
  final facility = {
    'id': facilityId,
    'organization_id': organizationId,
    'public_label': 'Contract facility',
    'timezone': 'Africa/Lagos',
    'is_simulated': true,
  };
  final sample = {
    'id': 'sample-001',
    'organization_id': organizationId,
    'facility_id': facilityId,
    'code': 'CONTRACT-001',
    'point_id': 'point-001',
    'collector_id': 'collector-001',
    'collected_at': '2026-11-10T09:00:00Z',
    'intended_method': 'Membrane filtration',
    'preservation_note': 'Recorded sealed handoff',
    'is_simulated': true,
  };
  return {
    'facility': facility,
    'facilities': [facility],
    'actor_id': actorId,
    'as_of': '2026-11-10T12:00:00Z',
    'fetched_at': '2026-11-05T09:00:00Z',
    'simulation': {'simulation_seed': 20261101, 'model_version': 1},
    for (final key in [
      'systems',
      'assets',
      'points',
      'templates',
      'inspections',
      'incidents',
      'work_orders',
      'qrs',
      'audit',
    ])
      key: [],
    'memberships': [
      {
        'id': 'membership-001',
        'user_id': actorId,
        'facility_id': facilityId,
        'role': 'manager',
        'status': 'active',
        'valid_until': null,
      },
    ],
    'samples': [
      {...sample, 'custody': []},
    ],
    'records': [
      {
        'id': 'result-001',
        'version': 4,
        'sample': sample,
        'state': 'reviewed',
        'source': 'laboratory',
        'point_label': 'Contract outlet',
        'open_incident_count': 1,
        'indicator': 'e_coli',
        'method': 'Membrane filtration',
        'value': 7.25,
        'units': 'mpn_per100ml',
        'detection_limit': 0.5,
        'received_at': '2026-11-10T10:00:00Z',
        'tested_at': '2026-11-10T11:00:00Z',
        'reviewed_at': '2026-11-10T12:00:00Z',
        'reviewed_by': 'reviewer-001',
        'report_ref': 'simulation://signed-report',
        'custody': [],
        'audit': [],
      },
    ],
  };
}

void main() {
  test('unauthenticated manager reads never send a private RPC', () async {
    var requests = 0;
    final client = await clientFor((_) {
      requests++;
      return response(null);
    }, signedIn: false);
    await expectLater(
      SupabaseManagerRepository(client).load(),
      fails(FailureKind.permission),
    );
    expect(requests, 0);
  });

  test(
    'connected projection preserves scope, provenance, units and two clocks',
    () async {
      late http.Request request;
      final client = await clientFor((value) {
        request = value;
        return response(workspaceJson());
      });
      final repository = SupabaseManagerRepository(client);
      final data = await repository.load(facilityId: facilityId);
      expect(repository.serverBacked, true);
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/manager_workspace');
      expect(jsonDecode(request.body), {'p_facility_id': facilityId});
      expect(data.facility.id, facilityId);
      expect(data.actorId, actorId);
      expect(data.asOf, DateTime.utc(2026, 11, 10, 12));
      expect(data.fetchedAt, DateTime.utc(2026, 11, 5, 9));
      expect(data.samples.single.preservationNote, 'Recorded sealed handoff');
      expect(data.results.single.version, 4);
      expect(data.results.single.measurement!.value, 7.25);
      expect(data.results.single.measurement!.detectionLimit, 0.5);
      expect(data.results.single.measurement!.unit, ResultUnit.mpnPer100ml);
      expect(data.results.single.reviewedBy, 'reviewer-001');
      expect(data.results.single.reportRef, 'simulation://signed-report');
      expect(data.results.single.isReviewed, true);
      expect(data.results.single.openIncidentCount, 1);
      expect(data.members.single.role, Role.manager);
    },
  );

  test(
    'manager mutations use existing RPCs and carry original optimistic versions',
    () async {
      final requests = <http.Request>[];
      final client = await clientFor((request) {
        requests.add(request);
        return response(8);
      });
      final repository = SupabaseManagerRepository(client);
      final payload = <String, Object?>{
        'owner_id': 'field-001',
        'due_at': '2026-11-12T00:00:00Z',
        'required_response': 'Inspect',
      };
      expect(
        await repository.transitionIncident(
          id: 'incident-001',
          target: IncidentState.assigned,
          expectedVersion: 7,
          payload: payload,
          reason: 'Assign owner',
        ),
        8,
      );
      expect(requests.last.url.path, '/rest/v1/rpc/transition_incident');
      expect(jsonDecode(requests.last.body), {
        'p_id': 'incident-001',
        'p_target': 'assigned',
        'p_expected_version': 7,
        'p_payload': payload,
        'p_reason': 'Assign owner',
      });
      await repository.transitionWorkOrder(
        id: 'work-001',
        target: WorkOrderState.accepted,
        expectedVersion: 4,
        reason: 'Evidence checked',
      );
      expect(requests.last.url.path, '/rest/v1/rpc/transition_work_order');
      expect(jsonDecode(requests.last.body), {
        'p_id': 'work-001',
        'p_target': 'accepted',
        'p_expected_version': 4,
        'p_payload': {},
        'p_reason': 'Evidence checked',
      });
      await repository.escalateIncident(
        id: 'incident-001',
        expectedVersion: 8,
        reason: 'Overdue internal response',
      );
      expect(requests.last.url.path, '/rest/v1/rpc/escalate_incident');
      expect(jsonDecode(requests.last.body), {
        'p_id': 'incident-001',
        'p_expected_version': 8,
        'p_reason': 'Overdue internal response',
      });
      await repository.publishResult(
        id: 'result-001',
        expectedVersion: 4,
        reason: 'Reviewed scope and date',
      );
      expect(requests.last.url.path, '/rest/v1/rpc/transition_result');
      expect(jsonDecode(requests.last.body), {
        'p_id': 'result-001',
        'p_target': 'published',
        'p_expected_version': 4,
        'p_payload': {},
        'p_reason': 'Reviewed scope and date',
      });
      await repository.revokeQr(
        token: 'opaque-point-token',
        reason: 'Printed code damaged',
      );
      expect(requests.last.url.path, '/rest/v1/rpc/revoke_public_record');
      expect(jsonDecode(requests.last.body), {
        'p_token': 'opaque-point-token',
        'p_reason': 'Printed code damaged',
      });
      expect(requests.length, 5);
    },
  );

  test(
    'verification sends the version returned by the separately audited plan',
    () async {
      final requests = <http.Request>[];
      final client = await clientFor((request) {
        requests.add(request);
        return response(requests.length == 1 ? 9 : 10);
      });
      final repository = SupabaseManagerRepository(client);
      final payload = <String, Object?>{
        'requirements': [
          {'kind': 'checklist', 'template_id': 'template-001'},
        ],
        'controls_reviewed': true,
        'notice_reviewed': true,
        'notice_ref': 'simulation://notice',
      };
      expect(
        await repository.transitionIncident(
          id: 'incident-001',
          target: IncidentState.verificationPending,
          expectedVersion: 8,
          payload: payload,
          reason: 'Review plan',
        ),
        10,
      );
      expect(requests.map((r) => r.url.path), [
        '/rest/v1/rpc/set_verification_plan',
        '/rest/v1/rpc/transition_incident',
      ]);
      expect(jsonDecode(requests.first.body), {
        'p_incident_id': 'incident-001',
        'p_expected_version': 8,
        'p_requirements': payload['requirements'],
        'p_reason': 'Review plan',
      });
      expect(jsonDecode(requests.last.body), {
        'p_id': 'incident-001',
        'p_expected_version': 9,
        'p_target': 'verification_pending',
        'p_payload': payload,
        'p_reason': 'Review plan',
      });
    },
  );

  test(
    'a rejected plan stops the verification flow before the second RPC',
    () async {
      var requests = 0;
      final client = await clientFor((_) {
        requests++;
        return response({'code': '22023', 'message': 'Invalid plan'}, 400);
      });
      await expectLater(
        SupabaseManagerRepository(client).transitionIncident(
          id: 'incident-001',
          target: IncidentState.verificationPending,
          expectedVersion: 8,
          reason: 'Review plan',
        ),
        fails(FailureKind.invalid),
      );
      expect(requests, 1);
    },
  );

  test(
    'partial verification failure explains the saved plan and requires refresh',
    () async {
      var requests = 0;
      final client = await clientFor(
        (_) => ++requests == 1
            ? response(9)
            : response({'code': '22023', 'message': 'Work not accepted'}, 400),
      );
      await expectLater(
        SupabaseManagerRepository(client).transitionIncident(
          id: 'incident-001',
          target: IncidentState.verificationPending,
          expectedVersion: 8,
          reason: 'Review plan',
        ),
        throwsA(
          isA<RepositoryFailure>()
              .having((e) => e.kind, 'kind', FailureKind.conflict)
              .having((e) => e.message, 'message', contains('plan was saved')),
        ),
      );
      expect(requests, 2);
    },
  );

  test(
    'account replacement between plan and transition stops the second RPC',
    () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      var requests = 0;
      final client = await clientFor((_) {
        requests++;
        started.complete();
        return pending.future;
      });
      final result = SupabaseManagerRepository(client).transitionIncident(
        id: 'incident-001',
        target: IncidentState.verificationPending,
        expectedVersion: 8,
        reason: 'Review plan',
      );
      final assertion = expectLater(result, fails(FailureKind.permission));
      await started.future;
      await client.auth.recoverSession(
        session('c9000000-0000-4000-8000-000000000002'),
      );
      pending.complete(response(9));
      await assertion;
      expect(requests, 1);
    },
  );

  for (final (code, kind) in [
    ('42501', FailureKind.permission),
    ('PGRST301', FailureKind.permission),
    ('PGRST302', FailureKind.permission),
    ('PGRST303', FailureKind.permission),
    ('40001', FailureKind.conflict),
    ('23505', FailureKind.conflict),
    ('22023', FailureKind.invalid),
    ('22P02', FailureKind.invalid),
    ('23514', FailureKind.invalid),
    ('XX000', FailureKind.transient),
  ]) {
    test(
      'RPC $code maps to ${kind.name} without exposing server details',
      () async {
        final client = await clientFor(
          (_) =>
              response({'code': code, 'message': 'private server detail'}, 400),
        );
        await expectLater(
          SupabaseManagerRepository(client).publishResult(
            id: 'result-001',
            expectedVersion: 4,
            reason: 'Review',
          ),
          throwsA(
            isA<RepositoryFailure>()
                .having((e) => e.kind, 'kind', kind)
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('private server detail')),
                ),
          ),
        );
      },
    );
  }

  for (final error in [
    http.ClientException('Disconnected'),
    TimeoutException('Connection timed out'),
  ]) {
    test(
      '${error.runtimeType} is an offline failure without automatic mutation retry',
      () async {
        var requests = 0;
        final client = await clientFor((_) {
          requests++;
          throw error;
        });
        await expectLater(
          SupabaseManagerRepository(client).publishResult(
            id: 'result-001',
            expectedVersion: 4,
            reason: 'Review',
          ),
          throwsA(isA<ManagerConnectionFailure>()),
        );
        expect(requests, 1);
      },
    );
  }
}
