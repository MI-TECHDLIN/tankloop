@TestOn('vm')
library;

import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final env = Platform.environment;
  final configured = [
    'TANKLOOP_TEST_URL',
    'TANKLOOP_TEST_ANON_KEY',
    'TANKLOOP_TEST_EMAIL',
    'TANKLOOP_TEST_PASSWORD',
  ].every((name) => env[name]?.isNotEmpty ?? false);

  test(
    'authenticated inspection, retry receipt and anonymous projection share one backend',
    () async {
      final url = env['TANKLOOP_TEST_URL']!;
      expect(
        Uri.parse(url).host,
        anyOf('localhost', '127.0.0.1'),
        reason: 'This mutation test runs only on a disposable local stack.',
      );
      final fieldClient = SupabaseClient(url, env['TANKLOOP_TEST_ANON_KEY']!);
      final publicClient = SupabaseClient(url, env['TANKLOOP_TEST_ANON_KEY']!);
      addTearDown(fieldClient.dispose);
      addTearDown(publicClient.dispose);
      await fieldClient.auth.signInWithPassword(
        email: env['TANKLOOP_TEST_EMAIL']!,
        password: env['TANKLOOP_TEST_PASSWORD']!,
      );
      final field = SupabaseTankLoopRepository(fieldClient);
      final public = SupabaseTankLoopRepository(publicClient);
      final dashboard = await field.today();
      expect(dashboard.facility.isSimulated, isTrue);
      expect(dashboard.actorId, fieldClient.auth.currentUser!.id);
      expect(dashboard.assets, isNotEmpty);
      final task = dashboard.inspections.firstWhere(
        (task) => !task.isSubmitted,
      );
      final template = dashboard.templateFor(task);
      final point = dashboard.points.firstWhere(
        (point) => point.assetId == task.assetId,
        orElse: () => dashboard.points.first,
      );
      final token = dashboard.publicTokens[point.id]!;
      final before = (await public.publicRecord(token))!;
      expect(before.facilityLabel, dashboard.facility.label);
      expect(before.isSimulated, isTrue);
      expect(
        dashboard.asOf,
        before.updatedAt,
        reason: 'Both apps must use the same seeded exercise clock.',
      );

      final command = InspectionSubmission(
        clientEventId: task.id,
        taskId: task.id,
        scope: dashboard.scope,
        templateId: template.id,
        expectedVersion: task.version,
        observedAt: dashboard.asOf,
        answers: {
          for (final question in template.questions)
            question.id: InspectionAnswer(
              question == template.questions.first
                  ? AnswerChoice.yes
                  : AnswerChoice.no,
            ),
        },
        notes: 'SIMULATED integration visit. No measured water evidence.',
        isSimulated: true,
      );
      final receipt = await field.submitInspection(command);
      expect(receipt.version, task.version + 1);
      final retry = await field.submitInspection(command);
      expect(retry.toJson(), receipt.toJson());
      final updated = await field.today();
      expect(
        updated.inspections
            .singleWhere((item) => item.id == task.id)
            .isSubmitted,
        isTrue,
      );
      expect(updated.cases.length, dashboard.cases.length + 1);
      final after = (await public.publicRecord(token))!;
      expect(after.concerns.length, before.concerns.length + 1);
      expect(
        after.concerns.any(
          (concern) => concern.source == EvidenceSource.inspection,
        ),
        isTrue,
      );
      expect(
        after.tests.map((test) => test.toJson()).toList(),
        before.tests.map((test) => test.toJson()).toList(),
      );

      await expectLater(
        field.submitInspection(
          InspectionSubmission(
            clientEventId: command.clientEventId,
            taskId: task.id,
            scope: dashboard.scope,
            templateId: template.id,
            expectedVersion: task.version,
            observedAt: command.observedAt,
            answers: command.answers,
            notes: 'Different content cannot reuse a receipt.',
            isSimulated: true,
          ),
        ),
        throwsA(
          isA<RepositoryFailure>().having(
            (failure) => failure.kind,
            'kind',
            FailureKind.conflict,
          ),
        ),
      );
      await expectLater(
        publicClient.from('inspections').select(),
        throwsA(
          isA<PostgrestException>().having(
            (failure) => failure.code,
            'code',
            '42501',
          ),
        ),
      );
      expect(
        await public.publicRecord('00000000000000000000000000000000'),
        isNull,
      );
      expect(publicClient.auth.currentSession, isNull);
    },
    skip: configured
        ? false
        : 'Set TANKLOOP_TEST_* for the local Supabase integration check. See docs/development.md.',
  );
}
