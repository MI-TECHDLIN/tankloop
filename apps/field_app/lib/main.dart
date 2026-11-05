import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'package:tankloop_offline_sync/offline_sync.dart';
import 'home.dart';
import 'inspection.dart';
import 'qr_scan.dart';
import 'runtime.dart';
import 'loading.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.environment();
    if (config.mode == AppMode.supabase) {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.anonKey,
      );
    }
    final store = await openLocalStore();
    runApp(
      ProviderScope(
        child: FieldBootstrap(config: config, store: store),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        theme: tankLoopTheme(),
        home: TankBackdrop(
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: NoticeCard(
                  title: 'Setup needs attention',
                  message: error is FormatException
                      ? error.message
                      : 'Local storage or the configured service could not initialize. Check your configuration and reload.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FieldBootstrap extends StatefulWidget {
  const FieldBootstrap({super.key, required this.config, required this.store});
  final AppConfig config;
  final KeyValueStore store;
  @override
  State<FieldBootstrap> createState() => _FieldBootstrapState();
}

class _FieldBootstrapState extends State<FieldBootstrap> {
  Future<FieldRuntime>? _runtime;
  StreamSubscription<AuthState>? _auth;
  String? _userId;
  @override
  void initState() {
    super.initState();
    if (widget.config.mode == AppMode.supabase) {
      _userId = Supabase.instance.client.auth.currentUser?.id;
      _auth = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
        final next = event.session?.user.id;
        if (next == _userId || !mounted) return;
        setState(() {
          _userId = next;
          _runtime = next == null
              ? null
              : FieldRuntime.create(widget.config, widget.store);
        });
      });
    }
    if (widget.config.mode == AppMode.simulation || _userId != null) {
      _runtime = FieldRuntime.create(widget.config, widget.store);
    }
  }

  @override
  void dispose() {
    unawaited(_auth?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_runtime == null) {
      return MaterialApp(
        title: 'TankLoop Field',
        debugShowCheckedModeBanner: false,
        theme: tankLoopTheme(),
        home: const _SignIn(),
      );
    }
    return FutureBuilder(
      future: _runtime,
      builder: (context, snapshot) {
        if (snapshot.hasData) return FieldApp(runtime: snapshot.data!);
        return MaterialApp(
          title: 'TankLoop Field',
          debugShowCheckedModeBanner: false,
          theme: tankLoopTheme(),
          home: TankBackdrop(
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: snapshot.hasError
                      ? NoticeCard(
                          title: 'Assignments unavailable',
                          message: snapshot.error is RepositoryFailure
                              ? snapshot.error.toString()
                              : 'Connect to load your first assignments. Your existing device records have been retained.',
                          action: TextButton(
                            onPressed: () => setState(() {
                              _runtime = FieldRuntime.create(
                                widget.config,
                                widget.store,
                              );
                            }),
                            child: const Text('Retry'),
                          ),
                        )
                      : const FieldLoadingSkeleton(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FieldApp extends StatefulWidget {
  const FieldApp({super.key, required this.runtime});
  final FieldRuntime runtime;
  @override
  State<FieldApp> createState() => _FieldAppState();
}

class _FieldAppState extends State<FieldApp> {
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const FieldHome()),
      GoRoute(
        path: '/inspection/:id',
        builder: (_, state) =>
            InspectionPage(taskId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/scan', builder: (_, _) => const QrScanPage()),
    ],
    errorBuilder: (context, _) => TankBackdrop(
      child: Scaffold(
        body: Center(
          child: NoticeCard(
            title: 'Page unavailable',
            message: 'Return to your assigned checks.',
            action: TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Today'),
            ),
          ),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [runtimeProvider.overrideWithValue(widget.runtime)],
    child: MaterialApp.router(
      title: 'TankLoop Field',
      debugShowCheckedModeBanner: false,
      theme: tankLoopTheme(),
      routerConfig: router,
    ),
  );
}

class _SignIn extends StatefulWidget {
  const _SignIn();
  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on AuthException {
      if (mounted) {
        setState(
          () => error =
              'Sign-in could not be completed. Check your credentials and active invitation.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not reach the sign-in service. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TankBrand(),
                  const SizedBox(height: 32),
                  Text(
                    'Keep the loop\nmoving.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  const Text('Sign in with your assigned facility account.'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) {
                      if (!busy) unawaited(submit());
                    },
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: TankColors.amber),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(busy ? 'Signing in…' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
