import 'package:http/http.dart' show ClientException;
import 'package:supabase/supabase.dart';
import 'public_point_repository.dart';

class SupabasePublicPointRepository extends PublicPointRepository {
  const SupabasePublicPointRepository(this.client);
  final SupabaseClient client;

  @override
  Future<PublicPointLookup> lookup(String token) async {
    if (!isPublicToken(token)) return const PublicPointLookup.missing();
    return PublicPointLookup.fromJson(
      await _request('lookup_public_point', {'p_token': token}),
    );
  }

  @override
  Future<PublicConcernReceipt> submitConcern(
    PublicConcernSubmission command,
  ) async {
    command.validate();
    final receipt = PublicConcernReceipt.fromJson(
      await _request('submit_public_concern', command.toParameters()),
    );
    if (receipt.eventId != command.eventId) {
      throw const PublicRequestFailure(PublicFailureKind.unavailable);
    }
    return receipt;
  }

  Future<Map<String, dynamic>> _request(
    String name,
    Map<String, Object?> parameters,
  ) async {
    try {
      final response = await client.rpc(name, params: parameters);
      return response as Map<String, dynamic>;
    } on PostgrestException catch (error) {
      throw PublicRequestFailure(switch (error.code) {
        '42501' ||
        'PGRST301' ||
        'PGRST302' ||
        'PGRST303' => PublicFailureKind.permission,
        '22023' || '23514' => PublicFailureKind.invalid,
        '23505' => PublicFailureKind.conflict,
        'PT429' => PublicFailureKind.rateLimited,
        'PT410' => PublicFailureKind.revoked,
        _ => PublicFailureKind.unavailable,
      });
    } on ClientException {
      throw const PublicRequestFailure(PublicFailureKind.unavailable);
    }
  }
}
