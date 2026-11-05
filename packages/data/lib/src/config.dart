enum AppMode { simulation, supabase }

class AppConfig {
  const AppConfig({
    required this.mode,
    this.supabaseUrl = '',
    this.anonKey = '',
    this.seed = 20261101,
    this.day = 10,
    this.portalBaseUrl = 'http://localhost:8081',
  });
  final AppMode mode;
  final String supabaseUrl;
  final String anonKey;
  final int seed;
  final int day;
  final String portalBaseUrl;

  factory AppConfig.environment() {
    const mode = String.fromEnvironment(
      'TANKLOOP_MODE',
      defaultValue: 'simulation',
    );
    if (mode != 'simulation' && mode != 'supabase') {
      throw const FormatException(
        'TANKLOOP_MODE must be simulation or supabase.',
      );
    }
    final config = AppConfig(
      mode: AppMode.values.byName(mode),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      seed: const int.fromEnvironment(
        'SIMULATION_SEED',
        defaultValue: 20261101,
      ),
      day: const int.fromEnvironment('SIMULATION_DAY', defaultValue: 10),
      portalBaseUrl: const String.fromEnvironment(
        'PORTAL_BASE_URL',
        defaultValue: 'http://localhost:8081',
      ),
    );
    config.validate();
    return config;
  }
  void validate() {
    if (day < 0 || day > 365) {
      throw const FormatException('SIMULATION_DAY must be between 0 and 365.');
    }
    if (mode == AppMode.supabase) {
      final uri = Uri.tryParse(supabaseUrl);
      if (uri == null ||
          !uri.hasAuthority ||
          !{'http', 'https'}.contains(uri.scheme) ||
          anonKey.trim().isEmpty) {
        throw const FormatException(
          'Set SUPABASE_URL and SUPABASE_ANON_KEY in your untracked .env.',
        );
      }
      if (anonKey.startsWith('sb_secret_')) {
        throw const FormatException(
          'Use a client-safe publishable/anon key, never a secret key.',
        );
      }
    }
  }
}
