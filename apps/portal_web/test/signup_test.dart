import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_portal/signup.dart';

Map<String, Object?> _authSession(String id) {
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
      'created_at': '2026-11-14T00:00:00Z',
    },
  };
}

Future<SupabaseClient> _authClient(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = (await tester.runAsync(
    () async => SupabaseClient(
      'https://signup.test',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response(
          response.body,
          response.statusCode,
          request: request,
          headers: response.headers,
          reasonPhrase: response.reasonPhrase,
        );
      }),
    ),
  ))!;
  addTearDown(() async {
    await tester.runAsync(client.dispose);
  });
  return client;
}

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: const {'content-type': 'application/json'},
);

Future<void> _enterText(WidgetTester tester, String label, String value) {
  return tester.enterText(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    ),
    value,
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading uses an accessible design-system skeleton', (
    tester,
  ) async {
    final facilities = Completer<http.Response>();
    final client = await _authClient(tester, (request) {
      if (request.url.path.endsWith('/rest/v1/rpc/list_joinable_facilities')) {
        return facilities.future;
      }
      if (request.url.path.endsWith('/rest/v1/access_requests')) {
        return Future.value(_json(const []));
      }
      return Future.value(_json(const {}));
    });
    await client.auth.recoverSession(jsonEncode(_authSession('user-1')));
    await tester.pumpWidget(
      MaterialApp(
        theme: tankLoopTheme(),
        home: AccessSignupScreen(client: client),
      ),
    );
    await tester.pump();
    expect(find.byType(FrostedSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading access options'), findsOneWidget);
    facilities.complete(_json(const []));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('email confirmation shows the next sign-in step', (tester) async {
    Map<String, dynamic>? signupBody;
    final client = await _authClient(tester, (request) {
      if (request.url.path.endsWith('/signup')) {
        signupBody = jsonDecode(request.body) as Map<String, dynamic>;
        return Future.value(
          _json({
            'user': {
              'id': 'new-user',
              'aud': 'authenticated',
              'email': 'new@example.com',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-11-14T00:00:00Z',
            },
          }),
        );
      }
      return Future.value(_json(const {}));
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: tankLoopTheme(),
        home: AccessSignupScreen(client: client),
      ),
    );
    await _settle(tester);
    await _enterText(tester, 'Email', 'new@example.com');
    await _enterText(tester, 'Password', 'correct horse battery');
    await _enterText(tester, 'Confirm password', 'correct horse battery');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await _settle(tester);
    expect(signupBody?['email'], 'new@example.com');
    expect(find.text('Confirm your email'), findsOneWidget);
    expect(
      find.textContaining('confirmation link to new@example.com'),
      findsOneWidget,
    );
    expect(find.text('Confirm password'), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('approved request names the facility and next workspace', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    var sequence = 0;
    final client = await _authClient(tester, (request) {
      final path = request.url.path;
      if (path.endsWith('/rest/v1/rpc/list_joinable_facilities')) {
        return Future.value(
          _json([
            {
              'facility_id': 'facility-1',
              'label': 'Demo court',
              'organization': 'Demo cooperative',
              'timezone': 'Africa/Lagos',
            },
          ]),
        );
      }
      if (path.endsWith('/rest/v1/access_requests')) {
        return Future.value(_json(requests));
      }
      if (path.endsWith('/rest/v1/rpc/request_access')) {
        sequence += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final id = 'request-$sequence';
        requests.add({
          'id': id,
          'facility_id': body['p_facility_id'],
          'user_id': 'signup-user',
          'email': 'new@example.com',
          'requested_role': body['p_role'],
          'status': 'approved',
          'created_at': '2026-11-14T00:00:00Z',
        });
        return Future.value(_json(id));
      }
      return Future.value(_json(const {}));
    });
    await client.auth.recoverSession(jsonEncode(_authSession('signup-user')));
    await tester.pumpWidget(
      MaterialApp(
        theme: tankLoopTheme(),
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AccessSignupScreen(client: client),
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.ensureVisible(find.text('Request access'));
    await _settle(tester);
    await tester.tap(find.text('Request access'));
    await _settle(tester);
    expect(
      find.textContaining('Demo cooperative - Demo court - Field - Approved'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Access approved. Open the matching workspace below or return to the Field app and sign in.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Field access is active. Return to the Field app and sign in with the same account.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
