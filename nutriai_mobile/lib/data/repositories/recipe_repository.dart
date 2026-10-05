import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/diet_plan_model.dart';

class RecipeRepository {
  final DioClient _dioClient;

  RecipeRepository(this._dioClient);

  Future<List<Recipe>> getAllRecipes({
    String? search,
    String? cuisineType,
    String? mealType,
    List<String>? dietaryTags,
    int? maxCalories,
  }) async {
    try {
      print('Fetching recipes...');
      final queryParams = <String, dynamic>{};
      if (mealType != null) queryParams['meal_type'] = mealType;
      if (dietaryTags != null && dietaryTags.isNotEmpty) {
        queryParams['dietary_type'] = dietaryTags.first;
      }

      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/recipes',
        queryParameters: queryParams,
      );

      print('Recipes response: ${response.data}');

      // Backend returns {"recipes": [...], "total": ..., "page": ..., "limit": ...}
      if (response.data is Map && response.data['recipes'] != null) {
        return (response.data['recipes'] as List)
            .map((json) => Recipe.fromJson(json))
            .toList();
      }

      return (response.data as List)
          .map((json) => Recipe.fromJson(json))
          .toList();
    } catch (e) {
      print('Failed to fetch recipes: $e');
      throw Exception('Failed to fetch recipes: $e');
    }
  }

  Future<Recipe> getRecipeById(int id) async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/recipes/$id',
      );
      return Recipe.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch recipe: $e');
    }
  }

  Future<List<Recipe>> getFavoriteRecipes() async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/recipes/favorites',
      );
      return (response.data as List)
          .map((json) => Recipe.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch favorite recipes: $e');
    }
  }

  Future<void> toggleFavorite(int recipeId) async {
    try {
      await _dioClient.dio.post(
        '${ApiConstants.apiV1}/recipes/$recipeId/favorite',
      );
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  Future<List<String>> getCuisineTypes() async {
    return [
      'Italian',
      'Chinese',
      'Indian',
      'Mexican',
      'Japanese',
      'Mediterranean',
      'Thai',
      'American',
      'French',
      'Greek',
    ];
  }

  Future<List<String>> getDietaryTags() async {
    return [
      'Vegetarian',
      'Vegan',
      'Gluten-Free',
      'Dairy-Free',
      'Nut-Free',
      'Low-Carb',
      'Keto',
      'Paleo',
      'High-Protein',
    ];
  }
}
