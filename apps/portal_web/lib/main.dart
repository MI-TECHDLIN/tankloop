import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tankloop_data/data.dart';
import 'package:tankloop_design_system/design_system.dart';
import 'public_point.dart';

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
  late final SimulationRepository? simulation =
      widget.config.mode == AppMode.simulation
      ? SimulationRepository(seed: widget.config.seed, day: widget.config.day)
      : null;
  late final GoRouter router = GoRouter(
    redirect: (_, state) => state.uri.path == '/' && simulation != null
        ? '/point/${simulation!.engine.featuredToken}?seed=${widget.config.seed}&day=${widget.config.day}'
        : null,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const TokenEntry()),
      GoRoute(
        path: '/point/:token',
        builder: (context, state) {
          final seed =
              int.tryParse(state.uri.queryParameters['seed'] ?? '') ??
              widget.config.seed;
          final day =
              int.tryParse(state.uri.queryParameters['day'] ?? '') ??
              widget.config.day;
          if (day < 0 || day > 365) {
            return const RecordUnavailable(
              title: 'Exercise date unavailable',
              message: 'Use a simulation day between 0 and 365.',
            );
          }
          final repository = simulation == null
              ? SupabaseTankLoopRepository(Supabase.instance.client)
              : SimulationRepository(seed: seed, day: day);
          return PublicPointPage(
            key: ValueKey('${state.pathParameters['token']}:$seed:$day'),
            repository: repository,
            token: state.pathParameters['token']!,
            simulatedDay: simulation == null ? null : day,
            seed: seed,
            onAdvance: simulation == null || day == 365
                ? null
                : () => context.go(
                    '/point/${state.pathParameters['token']}?seed=$seed&day=${day + 1}',
                  ),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [portalConfigProvider.overrideWithValue(widget.config)],
    child: MaterialApp.router(
      title: 'TankLoop Verify',
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
