import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/diet_plan_model.dart';

class DietPlanHistoryResponse {
  final List<Map<String, dynamic>> plans;
  final int total;
  final String? improvementHint;

  DietPlanHistoryResponse({
    required this.plans,
    required this.total,
    this.improvementHint,
  });
}

class DietPlanRepository {
  final DioClient _dioClient;

  DietPlanRepository(this._dioClient);

  Future<DietPlan> getCurrentDietPlan() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.currentDietPlan);
      return DietPlan.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      throw Exception('Failed to fetch current diet plan: $e');
    }
  }

  Future<DietPlanHistoryResponse> getDietPlanHistory() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.dietPlanHistory);
      final data = Map<String, dynamic>.from(response.data as Map);
      final plans = (data['plans'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return DietPlanHistoryResponse(
        plans: plans,
        total: data['total'] as int? ?? plans.length,
        improvementHint: data['improvement_hint'] as String?,
      );
    } catch (e) {
      throw Exception('Failed to fetch diet plan history: $e');
    }
  }

  Future<Map<String, dynamic>> getSchedule() async {
    final response = await _dioClient.dio.get(ApiConstants.dietPlanSchedule);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<DietPlan> generateWeeklyPlan({bool nextWeek = false}) async {
    final path = nextWeek ? ApiConstants.dietPlanWeeklyNext : ApiConstants.dietPlanWeeklyGenerate;
    final response = await _dioClient.dio.post(path);
    return DietPlan.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<DietPlan> generateDietPlan({
    required int durationDays,
    required List<String> goals,
    required int targetCalories,
    required Map<String, int> macroTargets,
  }) async {
    try {
      // Prefer fixed Mon–Sun weekly generation for production cadence
      return await generateWeeklyPlan(nextWeek: false);
    } catch (e) {
      throw Exception('Failed to generate diet plan: $e');
    }
  }

  Future<List<MealPlan>> getMealsForDay(int day) async {
    try {
      final dietPlan = await getCurrentDietPlan();
      return dietPlan.meals.where((meal) => meal.day == day).toList();
    } catch (e) {
      throw Exception('Failed to fetch meals for day: $e');
    }
  }

  Future<Recipe> getRecipeById(int recipeId) async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/recipes/$recipeId',
      );
      return Recipe.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch recipe: $e');
    }
  }

  Future<DietPlan> dislikeMeal({
    required int day,
    required String mealType,
    String? reason,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.apiV1}/diet-plans/dislike-meal',
        data: {
          'day': day,
          'meal_type': mealType,
          if (reason != null) 'reason': reason,
          'add_to_dislikes': true,
        },
      );
      return DietPlan.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to swap meal: $e');
    }
  }

  Future<Map<String, dynamic>> getPreferences() async {
    final response = await _dioClient.dio.get(
      '${ApiConstants.apiV1}/diet-plans/preferences',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<DietPlan?> updatePreferences({
    required String dietaryPreference,
    required List<String> cuisinePreferences,
    required List<String> dislikes,
    bool regeneratePlan = true,
  }) async {
    final response = await _dioClient.dio.put(
      '${ApiConstants.apiV1}/diet-plans/preferences',
      data: {
        'dietary_preference': dietaryPreference,
        'cuisine_preferences': cuisinePreferences,
        'dislikes': dislikes,
        'regenerate_plan': regeneratePlan,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['plan'] != null) {
      return DietPlan.fromJson(Map<String, dynamic>.from(data['plan'] as Map));
    }
    return null;
  }
}
