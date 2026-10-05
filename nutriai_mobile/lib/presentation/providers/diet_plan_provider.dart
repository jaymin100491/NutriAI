import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/diet_plan_model.dart';
import '../../data/repositories/diet_plan_repository.dart';

final dietPlanRepositoryProvider = Provider<DietPlanRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return DietPlanRepository(dioClient);
});

final currentDietPlanProvider = FutureProvider<DietPlan?>((ref) async {
  final repository = ref.watch(dietPlanRepositoryProvider);
  try {
    return await repository.getCurrentDietPlan();
  } catch (e) {
    return null;
  }
});

final dietPlanHistoryProvider = FutureProvider<List<DietPlan>>((ref) async {
  final repository = ref.watch(dietPlanRepositoryProvider);
  try {
    return await repository.getDietPlanHistory();
  } catch (e) {
    return [];
  }
});

final dailyMealsProvider = FutureProvider.family<List<MealPlan>, int>((ref, day) async {
  final repository = ref.watch(dietPlanRepositoryProvider);
  try {
    return await repository.getMealsForDay(day);
  } catch (e) {
    return [];
  }
});

final recipeDetailProvider = FutureProvider.family<Recipe?, int>((ref, recipeId) async {
  final repository = ref.watch(dietPlanRepositoryProvider);
  try {
    return await repository.getRecipeById(recipeId);
  } catch (e) {
    return null;
  }
});

class DietPlanState {
  final DietPlan? currentPlan;
  final List<DietPlan> history;
  final bool isLoading;
  final String? error;
  final int selectedDay;

  DietPlanState({
    this.currentPlan,
    this.history = const [],
    this.isLoading = false,
    this.error,
    this.selectedDay = 1,
  });

  DietPlanState copyWith({
    DietPlan? currentPlan,
    List<DietPlan>? history,
    bool? isLoading,
    String? error,
    int? selectedDay,
  }) {
    return DietPlanState(
      currentPlan: currentPlan ?? this.currentPlan,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      selectedDay: selectedDay ?? this.selectedDay,
    );
  }
}

class DietPlanNotifier extends StateNotifier<DietPlanState> {
  final DietPlanRepository _repository;

  DietPlanNotifier(this._repository) : super(DietPlanState());

  Future<void> loadCurrentDietPlan() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plan = await _repository.getCurrentDietPlan();
      state = state.copyWith(currentPlan: plan, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load diet plan',
        isLoading: false,
      );
    }
  }

  Future<void> loadHistory() async {
    try {
      final history = await _repository.getDietPlanHistory();
      state = state.copyWith(history: history);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load history');
    }
  }

  Future<void> generateNewPlan({
    required int durationDays,
    required List<String> goals,
    required int targetCalories,
    required Map<String, int> macroTargets,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plan = await _repository.generateDietPlan(
        durationDays: durationDays,
        goals: goals,
        targetCalories: targetCalories,
        macroTargets: macroTargets,
      );
      state = state.copyWith(currentPlan: plan, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to generate diet plan',
        isLoading: false,
      );
    }
  }

  void selectDay(int day) {
    state = state.copyWith(selectedDay: day);
  }

  Future<void> dislikeMeal({
    required int day,
    required String mealType,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plan = await _repository.dislikeMeal(
        day: day,
        mealType: mealType,
        reason: reason,
      );
      state = state.copyWith(currentPlan: plan, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to swap meal',
        isLoading: false,
      );
      rethrow;
    }
  }

  Future<void> updatePreferences({
    required String dietaryPreference,
    required List<String> cuisinePreferences,
    required List<String> dislikes,
    bool regeneratePlan = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final plan = await _repository.updatePreferences(
        dietaryPreference: dietaryPreference,
        cuisinePreferences: cuisinePreferences,
        dislikes: dislikes,
        regeneratePlan: regeneratePlan,
      );
      if (plan != null) {
        state = state.copyWith(currentPlan: plan, isLoading: false);
      } else {
        await loadCurrentDietPlan();
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to update preferences',
        isLoading: false,
      );
      rethrow;
    }
  }
}

final dietPlanNotifierProvider =
    StateNotifierProvider<DietPlanNotifier, DietPlanState>((ref) {
  final repository = ref.watch(dietPlanRepositoryProvider);
  return DietPlanNotifier(repository);
});
