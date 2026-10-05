/// Runtime configuration — override via --dart-define for staging/production.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Legacy optional portal URL — unused for open-market paste demo.
  static const String labcorpPortalApiUrl = String.fromEnvironment(
    'LABCORP_PORTAL_API_URL',
    defaultValue: '',
  );

  static const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  static const String webHost = String.fromEnvironment(
    'WEB_HOST',
    defaultValue: 'localhost',
  );

  static const int webPort = int.fromEnvironment('WEB_PORT', defaultValue: 8080);

  static String get callbackUrl => 'http://$webHost:$webPort/callback';
}
