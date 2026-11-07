class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.anonKey = '',
    this.portalBaseUrl = 'http://localhost:8081',
  });
  final String supabaseUrl;
  final String anonKey;
  final String portalBaseUrl;

  factory AppConfig.environment() {
    final config = AppConfig(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      portalBaseUrl: const String.fromEnvironment(
        'PORTAL_BASE_URL',
        defaultValue: 'http://localhost:8081',
      ),
    );
    config.validate();
    return config;
  }
  void validate() {
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
