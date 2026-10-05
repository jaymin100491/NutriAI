import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/diet_plan_model.dart';
import '../../data/repositories/recipe_repository.dart';

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return RecipeRepository(dioClient);
});

final allRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repository = ref.watch(recipeRepositoryProvider);
  try {
    return await repository.getAllRecipes();
  } catch (e) {
    return [];
  }
});

final favoriteRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final repository = ref.watch(recipeRepositoryProvider);
  try {
    return await repository.getFavoriteRecipes();
  } catch (e) {
    return [];
  }
});

class RecipeFilters {
  final String? search;
  final String? cuisineType;
  final String? mealType;
  final List<String> dietaryTags;
  final int? maxCalories;

  const RecipeFilters({
    this.search,
    this.cuisineType,
    this.mealType,
    this.dietaryTags = const [],
    this.maxCalories,
  });

  RecipeFilters copyWith({
    String? search,
    String? cuisineType,
    String? mealType,
    List<String>? dietaryTags,
    int? maxCalories,
  }) {
    return RecipeFilters(
      search: search ?? this.search,
      cuisineType: cuisineType ?? this.cuisineType,
      mealType: mealType ?? this.mealType,
      dietaryTags: dietaryTags ?? this.dietaryTags,
      maxCalories: maxCalories ?? this.maxCalories,
    );
  }

  bool get hasActiveFilters =>
      search != null ||
      cuisineType != null ||
      mealType != null ||
      dietaryTags.isNotEmpty ||
      maxCalories != null;
}

class RecipeState {
  final List<Recipe> recipes;
  final List<Recipe> filteredRecipes;
  final RecipeFilters filters;
  final bool isLoading;
  final String? error;
  final Set<int> favoriteIds;

  RecipeState({
    this.recipes = const [],
    this.filteredRecipes = const [],
    this.filters = const RecipeFilters(),
    this.isLoading = false,
    this.error,
    this.favoriteIds = const {},
  });

  RecipeState copyWith({
    List<Recipe>? recipes,
    List<Recipe>? filteredRecipes,
    RecipeFilters? filters,
    bool? isLoading,
    String? error,
    Set<int>? favoriteIds,
  }) {
    return RecipeState(
      recipes: recipes ?? this.recipes,
      filteredRecipes: filteredRecipes ?? this.filteredRecipes,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      favoriteIds: favoriteIds ?? this.favoriteIds,
    );
  }
}

class RecipeNotifier extends StateNotifier<RecipeState> {
  final RecipeRepository _repository;

  RecipeNotifier(this._repository) : super(RecipeState());

  Future<void> loadRecipes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final recipes = await _repository.getAllRecipes(
        search: state.filters.search,
        cuisineType: state.filters.cuisineType,
        mealType: state.filters.mealType,
        dietaryTags: state.filters.dietaryTags,
        maxCalories: state.filters.maxCalories,
      );
      state = state.copyWith(
        recipes: recipes,
        filteredRecipes: recipes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load recipes',
        isLoading: false,
      );
    }
  }

  Future<void> loadFavorites() async {
    try {
      final favorites = await _repository.getFavoriteRecipes();
      final favoriteIds = favorites.map((r) => r.id).toSet();
      state = state.copyWith(favoriteIds: favoriteIds);
    } catch (e) {
      // Silently fail
    }
  }

  void setSearch(String? search) {
    state = state.copyWith(
      filters: state.filters.copyWith(search: search),
    );
    _applyFilters();
  }

  void setCuisineType(String? cuisineType) {
    state = state.copyWith(
      filters: state.filters.copyWith(cuisineType: cuisineType),
    );
    _applyFilters();
  }

  void setMealType(String? mealType) {
    state = state.copyWith(
      filters: state.filters.copyWith(mealType: mealType),
    );
    _applyFilters();
  }

  void toggleDietaryTag(String tag) {
    final tags = List<String>.from(state.filters.dietaryTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(
      filters: state.filters.copyWith(dietaryTags: tags),
    );
    _applyFilters();
  }

  void setMaxCalories(int? maxCalories) {
    state = state.copyWith(
      filters: state.filters.copyWith(maxCalories: maxCalories),
    );
    _applyFilters();
  }

  void clearFilters() {
    state = state.copyWith(
      filters: const RecipeFilters(),
      filteredRecipes: state.recipes,
    );
  }

  void _applyFilters() {
    var filtered = state.recipes;

    if (state.filters.search != null && state.filters.search!.isNotEmpty) {
      final searchLower = state.filters.search!.toLowerCase();
      filtered = filtered.where((recipe) {
        return recipe.name.toLowerCase().contains(searchLower) ||
            recipe.description.toLowerCase().contains(searchLower);
      }).toList();
    }

    if (state.filters.cuisineType != null) {
      filtered = filtered.where((recipe) {
        return recipe.cuisineType == state.filters.cuisineType;
      }).toList();
    }

    if (state.filters.mealType != null) {
      filtered = filtered.where((recipe) {
        return recipe.mealType.contains(state.filters.mealType);
      }).toList();
    }

    if (state.filters.dietaryTags.isNotEmpty) {
      filtered = filtered.where((recipe) {
        return state.filters.dietaryTags.every(
          (tag) => recipe.dietaryTags.contains(tag),
        );
      }).toList();
    }

    if (state.filters.maxCalories != null) {
      filtered = filtered.where((recipe) {
        return recipe.nutrition.calories <= state.filters.maxCalories!;
      }).toList();
    }

    state = state.copyWith(filteredRecipes: filtered);
  }

  Future<void> toggleFavorite(int recipeId) async {
    try {
      await _repository.toggleFavorite(recipeId);
      final favoriteIds = Set<int>.from(state.favoriteIds);
      if (favoriteIds.contains(recipeId)) {
        favoriteIds.remove(recipeId);
      } else {
        favoriteIds.add(recipeId);
      }
      state = state.copyWith(favoriteIds: favoriteIds);
    } catch (e) {
      // Silently fail
    }
  }
}

final recipeNotifierProvider =
    StateNotifierProvider<RecipeNotifier, RecipeState>((ref) {
  final repository = ref.watch(recipeRepositoryProvider);
  return RecipeNotifier(repository);
});
