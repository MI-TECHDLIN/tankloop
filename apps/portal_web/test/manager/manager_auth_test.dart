import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_portal/manager_dashboard.dart';
import 'manager_test_support.dart';

Map<String, Object?> authSession(String id) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
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
  };
}

Future<SupabaseClient> authClient(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  // Supabase starts a JSON isolate. Its initialization and disposal need the
  // real async zone, rather than the widget test's virtual clock.
  final client = (await tester.runAsync(
    () async => SupabaseClient(
      'https://manager.test',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(handler),
    ),
  ))!;
  addTearDown(() async {
    await tester.runAsync(client.dispose);
  });
  return client;
}

void main() {
  testWidgets(
    'connected sign-in validates, reports rejection, then reloads on authentication',
    (tester) async {
      var accepted = false;
      final attempts = <Map<String, dynamic>>[];
      final client = await authClient(tester, (request) async {
        attempts.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(
            accepted
                ? authSession('manager-account-001')
                : {
                    'msg': 'Invalid login credentials',
                    'code': 'invalid_credentials',
                  },
          ),
          accepted ? 200 : 400,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = TestManagerRepository(clock: DateTime.now);
      final data = await repository.load();
      repository.onLoad = (_) async {
        if (client.auth.currentUser == null) {
          throw const RepositoryFailure(
            FailureKind.permission,
            'Sign in to continue',
          );
        }
        return data;
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: tankLoopTheme(),
          home: ManagerDashboard(repository: repository, authClient: client),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in to TankLoop Manage'), findsOneWidget);
      await managerTap(tester, find.text('Sign in'));
      expect(find.text('Required'), findsNWidgets(2));
      expect(attempts, isEmpty);
      await tester.enterText(
        managerField('Email'),
        ' manager@tankloop.invalid ',
      );
      await tester.enterText(
        managerField('Password'),
        'synthetic-test-password',
      );
      await managerTap(tester, find.text('Sign in'));
      expect(find.textContaining('Sign-in was not accepted'), findsOneWidget);
      expect(attempts.single['email'], 'manager@tankloop.invalid');
      accepted = true;
      await managerTap(tester, find.text('Sign in'));
      expect(find.text('Sign in to TankLoop Manage'), findsNothing);
      expect(find.text('Evidence completeness'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(client.auth.currentUser!.id, 'manager-account-001');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('sign-out discards the private workspace immediately', (
    tester,
  ) async {
    final logout = Completer<http.Response>();
    final client = await authClient(tester, (_) => logout.future);
    await client.auth.recoverSession(
      jsonEncode(authSession('manager-account-001')),
    );
    final repository = TestManagerRepository(clock: DateTime.now);
    await tester.pumpWidget(
      MaterialApp(
        theme: tankLoopTheme(),
        home: ManagerDashboard(repository: repository, authClient: client),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Evidence completeness'), findsOneWidget);
    await managerTap(tester, find.text('Sign out'));
    expect(find.text('Evidence completeness'), findsNothing);
    expect(find.text('Sign in to TankLoop Manage'), findsOneWidget);
    logout.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'account replacement dismisses private dialogs and ignores old reads',
    (tester) async {
      final client = await authClient(
        tester,
        (_) async => http.Response('{}', 200),
      );
      await client.auth.recoverSession(
        jsonEncode(authSession('manager-account-001')),
      );
      final repository = TestManagerRepository(clock: DateTime.now);
      final data = await repository.load();
      final newRead = Completer<ManagerWorkspace>();
      repository.onLoad = (_) =>
          client.auth.currentUser!.id == 'manager-account-001'
          ? Future.value(data)
          : newRead.future;
      await tester.pumpWidget(
        MaterialApp(
          theme: tankLoopTheme(),
          home: ManagerDashboard(repository: repository, authClient: client),
        ),
      );
      await tester.pumpAndSettle();
      await managerTap(tester, find.byType(DropdownButtonFormField<int>));
      await managerTap(tester, find.text('Facilities').last);
      final qr = data.qrs.firstWhere((q) => q.revokedAt == null);
      final point = data.point(qr.pointId)!;
      await managerTap(tester, find.byKey(ValueKey('asset-${point.assetId}')));
      await managerTap(tester, find.text('Revoke QR').first);
      await tester.enterText(
        managerField('Reason'),
        'Private draft for previous account',
      );
      await client.auth.recoverSession(
        jsonEncode(authSession('manager-account-002')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Private draft for previous account'), findsNothing);
      expect(find.text(qr.token), findsNothing);
      expect(repository.commands, isEmpty);
      newRead.completeError(
        const RepositoryFailure(
          FailureKind.permission,
          'No active manager assignment',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Manager assignment required'), findsOneWidget);
      expect(find.text(qr.token), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
