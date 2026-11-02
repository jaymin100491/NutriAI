/// Runtime configuration — override via --dart-define for staging/production.
class AppConfig {
  // Default to the live pitch API so Firebase Hosting builds keep working
  // even if --dart-define is forgotten. Local runs should still pass
  // --dart-define=API_BASE_URL=http://127.0.0.1:8000 via scripts/run-web-local.sh.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nutriai-api-sqnm.onrender.com',
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
