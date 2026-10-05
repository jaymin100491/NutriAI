import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/goal_model.dart';

class GoalRepository {
  final DioClient _dioClient;

  GoalRepository(this._dioClient);

  Future<List<HealthGoal>> getGoals() async {
    final response = await _dioClient.dio.get(ApiConstants.goals);
    final data = response.data as Map<String, dynamic>;
    final goals = data['goals'] as List<dynamic>;
    return goals.map((g) => HealthGoal.fromJson(g as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<List<Map<String, dynamic>>> getCatalog() async {
    final response = await _dioClient.dio.get('${ApiConstants.goals}/catalog');
    final data = response.data as Map<String, dynamic>;
    return (data['goals'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<HealthGoal>> updatePriorities(List<String> orderedGoalTypes) async {
    final response = await _dioClient.dio.put(
      ApiConstants.goalPriorities,
      data: {'ordered_goal_types': orderedGoalTypes},
    );
    final data = response.data as Map<String, dynamic>;
    final goals = data['goals'] as List<dynamic>;
    return goals.map((g) => HealthGoal.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<List<HealthGoal>> deriveFromLabs() async {
    final response = await _dioClient.dio.post('${ApiConstants.goals}/derive');
    final data = response.data as Map<String, dynamic>;
    final goals = data['goals'] as List<dynamic>;
    return goals.map((g) => HealthGoal.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> addGoal({
    String? text,
    String? goalType,
    bool makePrimary = true,
  }) async {
    final response = await _dioClient.dio.post(
      '${ApiConstants.goals}/add',
      data: {
        if (text != null && text.isNotEmpty) 'text': text,
        if (goalType != null) 'goal_type': goalType,
        'make_primary': makePrimary,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<HealthGoal>> removeGoal(String goalType) async {
    final response = await _dioClient.dio.delete('${ApiConstants.goals}/$goalType');
    final data = response.data as Map<String, dynamic>;
    final goals = data['goals'] as List<dynamic>;
    return goals.map((g) => HealthGoal.fromJson(g as Map<String, dynamic>)).toList();
  }
}
