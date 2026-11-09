import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_field/handover/handover.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';

void main() {
  final deno = Platform.environment['TANKLOOP_DENO_BIN'];
  final serverPath = Platform.environment['TANKLOOP_HANDOVER_TEST_SERVER'];
  test(
    'real Flutter SDK and controller traverse local function and upstream HTTP doubles',
    () async {
      final process = await Process.start(deno!, [
        'run',
        '--allow-net=127.0.0.1',
        serverPath!,
      ]);
      final errors = StringBuffer();
      final stderr = process.stderr
          .transform(utf8.decoder)
          .listen(errors.write);
      addTearDown(() async {
        process.kill();
        await process.exitCode.timeout(const Duration(seconds: 10));
        await stderr.cancel();
      });
      final url = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((line) => line.startsWith('http://127.0.0.1:'))
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw StateError('Fixture did not start: $errors'),
          );
      final client = SupabaseClient(
        url,
        'fixture-anon',
        accessToken: () async => 'fixture-user-token',
      );
      addTearDown(client.dispose);
      final store = MemoryKeyValueStore();
      final controller = HandoverController(
        service: SupabaseHandoverService(client),
        store: store,
        storageKey: 'transport-fixture',
        actorId: '90000000-0000-4000-8000-000000000001',
        kind: 'point',
        id: '50000000-0000-4000-8000-000000000001',
        canConnect: () => true,
        hasAccess: () => true,
      );
      addTearDown(controller.dispose);
      await controller.generate();
      expect(controller.failure, isNull);
      expect(controller.draft!.model, 'openai/gpt-oss-120b');
      expect(controller.draft!.sources, hasLength(5));
      await controller.save();
      expect(store.values, isEmpty);
      controller.edit(
        'Human reviewed wording: work needs separate verification.',
      );
      controller.confirmReview(true);
      await controller.save();
      expect(controller.failure, isNull);
      final originalSaved = store.values['transport-fixture'];
      expect(originalSaved, contains('Human reviewed wording'));
      final http = HttpClient();
      final change = await http.postUrl(Uri.parse('$url/change-source'));
      await (await change.close()).drain<void>();
      http.close();
      controller.confirmReview(true);
      await controller.save();
      expect(controller.failure!.code, 'stale_sources');
      expect(controller.mustRegenerate, isTrue);
      expect(store.values['transport-fixture'], originalSaved);
      final unauthorized = SupabaseClient(
        url,
        'fixture-anon',
        accessToken: () async => 'wrong-user-token',
      );
      addTearDown(unauthorized.dispose);
      await expectLater(
        SupabaseHandoverService(unauthorized).generate('point', controller.id),
        throwsA(
          isA<HandoverFailure>().having(
            (failure) => failure.code,
            'code',
            'unauthorized',
          ),
        ),
      );
    },
    skip: deno == null || serverPath == null
        ? 'Set TANKLOOP_DENO_BIN and TANKLOOP_HANDOVER_TEST_SERVER for HTTP integration with explicit provider doubles.'
        : false,
  );
}
