import '../../core/config/app_config.dart';

class ApiConstants {
  static String get baseUrl => AppConfig.apiBaseUrl;

  static const String apiV1 = '/api/v1';

  static String get oktaAuthorize => '$apiV1/auth/okta/authorize';
  static String get oktaCallback => '$apiV1/auth/okta/callback';
  static String get login => '$apiV1/auth/login';
  static String get refresh => '$apiV1/auth/refresh';
  static String get authMe => '$apiV1/auth/me';

  static const String profile = '$apiV1/users/profile';
  static const String me = '$apiV1/users/me';

  static const String labResults = '$apiV1/lab-results';
  static const String labResultsSync = '$apiV1/lab-results/sync';
  static const String labResultsImportFromPortal = '$apiV1/lab-results/import-from-portal';
  static const String latestLabResult = '$apiV1/lab-results/latest';

  static const String currentDietPlan = '$apiV1/diet-plans/current';
  static const String generateDietPlan = '$apiV1/diet-plans/generate';

  static const String recipes = '$apiV1/recipes';

  static const String dailyTracking = '$apiV1/tracking/daily';
  static const String progress = '$apiV1/tracking/progress';

  static const String goals = '$apiV1/goals';
  static const String goalPriorities = '$apiV1/goals/priorities';
  static const String goalsDerive = '$apiV1/goals/derive';

  static const String chat = '$apiV1/chat';
  static const String chatHistory = '$apiV1/chat/history';

  static const int connectionTimeout = 45000;
  static const int receiveTimeout = 45000;
}
