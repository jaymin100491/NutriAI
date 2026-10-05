/// Runtime configuration — override via --dart-define for staging/production.
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  /// Labcorp patient portal QA — browser calls this directly (withCredentials).
  static const String labcorpPortalApiUrl = String.fromEnvironment(
    'LABCORP_PORTAL_API_URL',
    defaultValue: 'https://portal-api.patient-qa.dev.cws.labcorp.com',
  );

  static const bool demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  /// Must match patient-website-ui QA Okta redirect (port 4200).
  static const String webHost = String.fromEnvironment(
    'WEB_HOST',
    defaultValue: 'patient-local.labcorp.com',
  );

  static const int webPort = int.fromEnvironment('WEB_PORT', defaultValue: 4200);

  static String get callbackUrl =>
      'https://$webHost:$webPort/callback';
}
