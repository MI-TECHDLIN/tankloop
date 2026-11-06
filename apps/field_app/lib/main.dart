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
import 'sign_in.dart';
import 'water_point.dart';
import 'work_order.dart';

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
        home: const SignInScreen(),
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

class _FieldAppState extends State<FieldApp> with WidgetsBindingObserver {
  Timer? syncTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.runtime.resume());
    if (widget.runtime.config.mode == AppMode.supabase) {
      syncTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(widget.runtime.sync()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.runtime.resume());
  }

  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const FieldHome()),
      GoRoute(
        path: '/inspection/:id',
        builder: (_, state) =>
            InspectionPage(taskId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/point/:id',
        builder: (_, state) =>
            WaterPointScreen(pointId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/work/:id',
        builder: (_, state) =>
            WorkOrderScreen(orderId: state.pathParameters['id']!),
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
    syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
