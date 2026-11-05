@TestOn('vm')
library;

import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  final env = Platform.environment;
  final configured = [
    'TANKLOOP_TEST_URL',
    'TANKLOOP_TEST_ANON_KEY',
    'TANKLOOP_TEST_EMAIL',
    'TANKLOOP_TEST_PASSWORD',
    'TANKLOOP_TEST_LAB_EMAIL',
    'TANKLOOP_TEST_LAB_PASSWORD',
  ].every((name) => env[name]?.isNotEmpty ?? false);

  test(
    'Auth to sample intake, signed review, immutable revisions and lost-ACK replay',
    () async {
      final url = env['TANKLOOP_TEST_URL']!;
      expect(Uri.parse(url).host, anyOf('localhost', '127.0.0.1'));
      final fieldClient = SupabaseClient(url, env['TANKLOOP_TEST_ANON_KEY']!);
      final labClient = SupabaseClient(url, env['TANKLOOP_TEST_ANON_KEY']!);
      final anonymous = SupabaseClient(url, env['TANKLOOP_TEST_ANON_KEY']!);
      addTearDown(fieldClient.dispose);
      addTearDown(labClient.dispose);
      addTearDown(anonymous.dispose);
      await fieldClient.auth.signInWithPassword(
        email: env['TANKLOOP_TEST_EMAIL']!,
        password: env['TANKLOOP_TEST_PASSWORD']!,
      );
      await labClient.auth.signInWithPassword(
        email: env['TANKLOOP_TEST_LAB_EMAIL']!,
        password: env['TANKLOOP_TEST_LAB_PASSWORD']!,
      );
      final lab = SupabaseLabRepository(labClient);
      final field = await SupabaseTankLoopRepository(fieldClient).today();
      final before = await lab.load(facilityId: field.facility.id);
      expect(
        before.facility.isSimulated,
        true,
        reason: 'Mutation checks use a disposable simulated facility.',
      );
      expect(before.actorId, labClient.auth.currentUser!.id);
      expect(before.asOf, field.asOf);
      await expectLater(
        SupabaseLabRepository(fieldClient).load(),
        throwsA(
          isA<RepositoryFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.permission,
          ),
        ),
      );

      Future<String> register() async =>
          await fieldClient.rpc(
                'register_sample',
                params: {
                  'p_point_id': field.points.first.id,
                  'p_collected_at': before.asOf.toIso8601String(),
                  'p_method': 'Membrane filtration (simulation)',
                  'p_preservation_note':
                      'SIMULATED SDK handoff. No physical water sample.',
                  'p_sample_id': const Uuid().v4(),
                },
              )
              as String;
      Future<LabRecord> read(String id) async =>
          (await lab.load(facilityId: before.facility.id)).record(id)!;
      LabCommand command(
        LabRecord row,
        LabAction action,
        Map<String, Object?> payload,
      ) => LabCommand(
        eventId: const Uuid().v4(),
        resultId: row.id,
        expectedVersion: row.version,
        action: action,
        payload: payload,
        reason: 'SIMULATED SDK ${action.name} exercise',
      );

      final resultId = await register();
      var row = await read(resultId);
      expect(row.state, ResultState.collected);
      final intake = command(row, LabAction.accept, {
        'custody_note': 'Simulated sealed handoff checked',
      });
      final accepted = await lab.submit(intake);
      final acceptedRetry = await lab.submit(intake);
      expect(acceptedRetry.eventId, accepted.eventId);
      expect(acceptedRetry.recordedAt, accepted.recordedAt);
      row = await read(resultId);
      expect(row.state, ResultState.valid);
      expect(row.version, 2);
      expect(row.custody.length, 1);
      expect(row.custody.single.fromActor, fieldClient.auth.currentUser!.id);
      expect(row.custody.single.toActor, labClient.auth.currentUser!.id);
      expect(row.custody.single.note, 'Simulated sealed handoff checked');
      await lab.submit(
        command(
          row,
          LabAction.enterResult,
          Measurement(
            indicator: Indicator.eColi,
            method: row.sample.intendedMethod,
            value: 8,
            unit: ResultUnit.mpnPer100ml,
            detectionLimit: .5,
          ).toJson(),
        ),
      );
      row = await read(resultId);
      expect(row.state, ResultState.tested);
      expect(row.isReviewed, false);
      expect(row.measurement!.unit, ResultUnit.mpnPer100ml);
      expect(row.measurement!.detectionLimit, .5);
      await expectLater(
        lab.submit(command(row, LabAction.attest, {})),
        throwsA(
          isA<RepositoryFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.invalid,
          ),
        ),
      );
      final attestation = await lab.submit(
        command(row, LabAction.attest, {
          'report_ref': 'simulation://reports/$resultId',
        }),
      );
      final original = await read(resultId);
      expect(original.isReviewed, true);
      expect(original.reviewedBy, labClient.auth.currentUser!.id);
      expect(original.reviewedAt, attestation.recordedAt);
      expect(original.publishedAt, isNull);

      final correction = command(original, LabAction.correct, {
        'value': 0,
        'detection_limit': .25,
        'report_ref': 'simulation://reports/$resultId/corrected',
      });
      final revised = await lab.submit(correction);
      final retry = await lab.submit(correction);
      expect(retry.resultId, revised.resultId);
      expect(retry.eventId, revised.eventId);
      expect(retry.recordedAt, revised.recordedAt);
      expect(revised.previousResultId, original.id);
      var workspace = await lab.load(facilityId: before.facility.id);
      final historical = workspace.record(original.id)!;
      row = workspace.record(revised.resultId)!;
      expect(historical.state, ResultState.superseded);
      expect(historical.measurement!.toJson(), original.measurement!.toJson());
      expect(historical.reportRef, original.reportRef);
      expect(historical.reviewedBy, original.reviewedBy);
      expect(historical.reviewedAt, original.reviewedAt);
      expect(row.revisionOf, original.id);
      expect(row.correctionReason, correction.reason);
      expect(row.correctedBy, labClient.auth.currentUser!.id);
      expect(row.correctedAt, revised.recordedAt);
      expect(row.measurement!.detectionLimit, .25);
      expect(workspace.lineage(row).map((r) => r.id), [original.id, row.id]);

      final second = await lab.submit(
        command(row, LabAction.correct, {
          'value': 2,
          'detection_limit': .125,
          'report_ref': 'simulation://reports/$resultId/second-correction',
        }),
      );
      workspace = await lab.load(facilityId: before.facility.id);
      final lineage = workspace.lineage(workspace.record(second.resultId)!);
      expect(lineage.map((r) => r.id), [
        original.id,
        revised.resultId,
        second.resultId,
      ]);
      expect(
        lineage[1].correctedAt,
        lineage[2].correctedAt,
        reason: 'Lineage must handle equal simulated timestamps.',
      );
      expect(
        workspace.activeRecords
            .where((r) => r.sample.id == original.sample.id)
            .length,
        1,
      );

      final rejectedId = await register();
      row = await read(rejectedId);
      await lab.submit(
        command(row, LabAction.reject, {
          'custody_note': 'Simulated holding-time deviation',
        }),
      );
      row = await read(rejectedId);
      expect(row.state, ResultState.rejected);
      expect(row.rejectionReason, isNotEmpty);
      expect(row.isReviewed, false);
      await expectLater(
        lab.submit(
          command(row, LabAction.attest, {
            'report_ref': 'simulation://rejected',
          }),
        ),
        throwsA(
          isA<RepositoryFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.invalid,
          ),
        ),
      );
      await expectLater(
        anonymous.rpc('lab_workspace'),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
      await expectLater(
        anonymous.from('test_results').select(),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
        ),
      );
      await labClient.auth.signOut();
      await expectLater(
        lab.load(),
        throwsA(
          isA<RepositoryFailure>().having(
            (e) => e.kind,
            'kind',
            FailureKind.permission,
          ),
        ),
      );
    },
    skip: configured
        ? false
        : 'Set TANKLOOP_TEST_* and TANKLOOP_TEST_LAB_* for the local laboratory SDK journey.',
  );
}
