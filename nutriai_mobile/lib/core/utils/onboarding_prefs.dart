import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPrefs {
  static String _key(int? userId) => 'intent_onboarding_done_v1_${userId ?? 'anon'}';

  static Future<bool> hasCompletedIntent(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId)) ?? false;
  }

  static Future<void> markIntentComplete(int? userId, {String? intentId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId), true);
    if (intentId != null) {
      await prefs.setString('primary_intent_v1_${userId ?? 'anon'}', intentId);
    }
  }

  static Future<String?> getPrimaryIntent(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('primary_intent_v1_${userId ?? 'anon'}');
  }

  static Future<void> resetIntent(int? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }
}
