import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'lab/lab_routes.dart';
import 'manager_dashboard.dart';
import 'public_point.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.environment();
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.anonKey,
    );
    runApp(ProviderScope(child: PortalApp(config: config)));
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
                  title: 'Record service unavailable',
                  message: error is FormatException
                      ? error.message
                      : 'The configured service could not initialize. Check the connection and reload.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final portalConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError('Portal is not initialized.'),
);

class PortalApp extends StatefulWidget {
  const PortalApp({super.key, required this.config});
  final AppConfig config;
  @override
  State<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends State<PortalApp> {
  late final LabRepository labRepository = SupabaseLabRepository(
    Supabase.instance.client,
  );
  late final ManagerWorkspaceRepository managerRepository =
      SupabaseManagerRepository(Supabase.instance.client);
  // Public scans do not inherit a staff session or an expired laboratory JWT.
  late final SupabaseClient publicClient = SupabaseClient(
    widget.config.supabaseUrl,
    widget.config.anonKey,
  );
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const TokenEntry()),
      ...labRoutes(labRepository, authClient: Supabase.instance.client),
      GoRoute(
        path: '/manager',
        builder: (_, _) => ManagerDashboard(
          repository: managerRepository,
          authClient: Supabase.instance.client,
        ),
      ),
      GoRoute(
        path: '/point/:token',
        builder: (context, state) {
          final PublicPointRepository repository =
              SupabasePublicPointRepository(publicClient);
          return PublicPointPage(
            key: ValueKey(state.pathParameters['token']!),
            repository: repository,
            token: state.pathParameters['token']!,
            initialTextFirst: state.uri.queryParameters['view'] == 'text',
          );
        },
      ),
    ],
    errorBuilder: (_, _) => const RecordUnavailable(
      title: 'Point link unavailable',
      message: 'Scan the printed TankLoop QR or check the point code.',
    ),
  );
  @override
  void dispose() {
    router.dispose();
    publicClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [portalConfigProvider.overrideWithValue(widget.config)],
    child: MaterialApp.router(
      title: 'TankLoop',
      debugShowCheckedModeBanner: false,
      theme: tankLoopTheme(),
      routerConfig: router,
    ),
  );
}

class TokenEntry extends StatefulWidget {
  const TokenEntry({super.key});
  @override
  State<TokenEntry> createState() => _TokenEntryState();
}

class _TokenEntryState extends State<TokenEntry> {
  final controller = TextEditingController();
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void open() {
    final token = controller.text.trim();
    if (!RegExp(r'^[a-f0-9]{32,128}$').hasMatch(token)) {
      setState(
        () => error = 'Enter the opaque point code printed with the QR.',
      );
      return;
    }
    context.go('/point/$token');
  }

  @override
  Widget build(BuildContext context) => TankBackdrop(
    child: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TankBrand(surface: 'VERIFY'),
                  const SizedBox(height: 32),
                  Text(
                    'A clearer water record.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan the TankLoop QR at your water point, or enter its point code. No sign-in is needed.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Water point code',
                      errorText: error,
                    ),
                    onSubmitted: (_) => open(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: open,
                    child: const Text('Open point record'),
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
