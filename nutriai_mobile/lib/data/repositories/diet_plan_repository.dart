import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/diet_plan_model.dart';

class DietPlanRepository {
  final DioClient _dioClient;

  DietPlanRepository(this._dioClient);

  Future<DietPlan> getCurrentDietPlan() async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/diet-plans/current',
      );
      return DietPlan.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch current diet plan: $e');
    }
  }

  Future<List<DietPlan>> getDietPlanHistory() async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/diet-plans/history',
      );
      return (response.data as List)
          .map((json) => DietPlan.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch diet plan history: $e');
    }
  }

  Future<DietPlan> generateDietPlan({
    required int durationDays,
    required List<String> goals,
    required int targetCalories,
    required Map<String, int> macroTargets,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.apiV1}/diet-plans/generate',
        data: {
          'duration_days': durationDays,
          'goals': goals,
          'target_calories': targetCalories,
          'macro_targets': macroTargets,
        },
      );
      return DietPlan.fromJson(response.data);
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
