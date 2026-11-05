import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';
import 'lab_models.dart';
import 'lab_repository.dart';
import 'repository.dart';

class SupabaseLabRepository implements LabRepository {
  const SupabaseLabRepository(this.client);
  final SupabaseClient client;
  @override
  bool get serverBacked => true;

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, Object?> params,
  ) async {
    if (client.auth.currentUser == null) {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Sign in with an authorized laboratory reviewer account.',
      );
    }
    try {
      final response = await client
          .rpc(name, params: params)
          .timeout(const Duration(seconds: 20));
      return response as Map<String, dynamic>;
    } on PostgrestException catch (error) {
      throw switch (error.code) {
        '42501' ||
        'PGRST301' ||
        'PGRST302' ||
        'PGRST303' => const RepositoryFailure(
          FailureKind.permission,
          'Active laboratory reviewer access is required for this facility. Renew your session or contact the organization administrator.',
        ),
        '40001' || '23505' => const RepositoryFailure(
          FailureKind.conflict,
          'This record changed. Refresh and compare the latest record before submitting again.',
        ),
        '22023' || '22P02' || '23514' => const RepositoryFailure(
          FailureKind.invalid,
          'Review the sample stage, reported value, units, detection limit, signed report and reason.',
        ),
        _ => const RepositoryFailure(
          FailureKind.transient,
          'The lab service could not complete this request. Retry after checking the service.',
        ),
      };
    } on AuthException {
      throw const RepositoryFailure(
        FailureKind.permission,
        'Renew your laboratory session.',
      );
    } on http.ClientException {
      throw const LabConnectionFailure();
    } on TimeoutException {
      throw const LabConnectionFailure();
    }
  }

  @override
  Future<LabWorkspace> load({String? facilityId}) async =>
      LabWorkspace.fromJson(
        await _rpc('lab_workspace', {'p_facility_id': facilityId}),
      );

  @override
  Future<LabReceipt> submit(LabCommand command) async =>
      LabReceipt.fromJson(await _rpc('lab_command', command.toParams()));
}
