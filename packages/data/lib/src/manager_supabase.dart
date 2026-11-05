import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'package:tankloop_domain/domain.dart';
import 'manager_models.dart';
import 'manager_repository.dart';
import 'repository.dart';

class SupabaseManagerRepository implements ManagerWorkspaceRepository {
  const SupabaseManagerRepository(this.client);
  final SupabaseClient client;
  @override
  bool get serverBacked => true;

  Future<Object?> _rpc(String name, Map<String, Object?> params) async {
    if (client.auth.currentUser == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Sign in with an active manager or administrator membership.',
      );
    }
    try {
      return await client
          .rpc(name, params: params)
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' ||
        'PGRST301' ||
        'PGRST302' ||
        'PGRST303' => const RepositoryFailure(
          FailureKind.permission,
          'Active scoped manager access is required. Renew your session or contact the administrator.',
        ),
        '40001' || '23505' => const RepositoryFailure(
          FailureKind.conflict,
          'This record changed. Refresh and compare its latest version.',
        ),
        '22023' || '22P02' || '23514' => const RepositoryFailure(
          FailureKind.invalid,
          'Review the required evidence, active assignment, deadline and reason.',
        ),
        _ => const RepositoryFailure(
          FailureKind.transient,
          'The manager service could not complete the request. Please retry.',
        ),
      };
    } on AuthException {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Renew your manager session.',
      );
    } on http.ClientException {
      throw const ManagerConnectionFailure();
    } on TimeoutException {
      throw const ManagerConnectionFailure();
    }
  }

  @override
  Future<ManagerWorkspace> load({String? facilityId}) async =>
      ManagerWorkspace.fromJson(
        await _rpc('manager_workspace', {'p_facility_id': facilityId})
            as Map<String, dynamic>,
      );

  @override
  Future<int> transitionIncident({
    required String id,
    required IncidentState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) async {
    var version = expectedVersion;
    if (target == IncidentState.verificationPending) {
      // The existing service saves the plan separately. A failed second step
      // leaves the audited plan in place and requires a fresh version to retry.
      final actorId = client.auth.currentUser?.id;
      version =
          await _rpc('set_verification_plan', {
                'p_incident_id': id,
                'p_expected_version': version,
                'p_requirements': payload['requirements'],
                'p_reason': reason,
              })
              as int;
      if (client.auth.currentUser?.id != actorId) {
        throw const RepositoryFailure(
          FailureKind.permission,
          'The manager session changed. Sign in and reload the workspace.',
        );
      }
    }
    try {
      return await _rpc('transition_incident', {
            'p_id': id,
            'p_target': wireName(target),
            'p_expected_version': version,
            'p_payload': payload,
            'p_reason': reason,
          })
          as int;
    } on RepositoryFailure catch (error) {
      if (target == IncidentState.verificationPending &&
          error.kind != FailureKind.permission) {
        if (error is ManagerConnectionFailure) rethrow;
        throw RepositoryFailure(
          FailureKind.conflict,
          'The verification plan was saved, but the incident transition was not confirmed. Refresh to review the current state before retrying.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<int> transitionWorkOrder({
    required String id,
    required WorkOrderState target,
    required int expectedVersion,
    Map<String, Object?> payload = const {},
    required String reason,
  }) async =>
      await _rpc('transition_work_order', {
            'p_id': id,
            'p_target': wireName(target),
            'p_expected_version': expectedVersion,
            'p_payload': payload,
            'p_reason': reason,
          })
          as int;

  @override
  Future<int> escalateIncident({
    required String id,
    required int expectedVersion,
    required String reason,
  }) async =>
      await _rpc('escalate_incident', {
            'p_id': id,
            'p_expected_version': expectedVersion,
            'p_reason': reason,
          })
          as int;

  @override
  Future<int> publishResult({
    required String id,
    required int expectedVersion,
    required String reason,
  }) async =>
      await _rpc('transition_result', {
            'p_id': id,
            'p_target': 'published',
            'p_expected_version': expectedVersion,
            'p_payload': <String, Object?>{},
            'p_reason': reason,
          })
          as int;

  @override
  Future<void> revokeQr({required String token, required String reason}) async {
    await _rpc('revoke_public_record', {'p_token': token, 'p_reason': reason});
  }
}
