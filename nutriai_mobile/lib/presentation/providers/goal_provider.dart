import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/goal_model.dart';
import '../../data/repositories/goal_repository.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(dioClientProvider));
});

final healthGoalsProvider = FutureProvider<List<HealthGoal>>((ref) async {
  final repository = ref.watch(goalRepositoryProvider);
  try {
    return await repository.getGoals();
  } catch (e) {
    return [];
  }
});

final goalNotifierProvider =
    StateNotifierProvider<GoalNotifier, AsyncValue<List<HealthGoal>>>((ref) {
  return GoalNotifier(ref.watch(goalRepositoryProvider));
});

class GoalNotifier extends StateNotifier<AsyncValue<List<HealthGoal>>> {
  final GoalRepository _repository;

  GoalNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    state = const AsyncValue.loading();
    try {
      final goals = await _repository.getGoals();
      state = AsyncValue.data(goals);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reorderGoals(List<HealthGoal> reordered) async {
    final types = reordered.map((g) => g.goalType).toList();
    try {
      final updated = await _repository.updatePriorities(types);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Map<String, dynamic>> addGoal({
    String? text,
    String? goalType,
    bool makePrimary = true,
  }) async {
    final result = await _repository.addGoal(
      text: text,
      goalType: goalType,
      makePrimary: makePrimary,
    );
    final goals = (result['goals'] as List)
        .map((g) => HealthGoal.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList();
    state = AsyncValue.data(goals);
    return result;
  }

  Future<void> removeGoal(String goalType) async {
    final updated = await _repository.removeGoal(goalType);
    state = AsyncValue.data(updated);
  }
}
