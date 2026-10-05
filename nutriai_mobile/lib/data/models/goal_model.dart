import 'package:equatable/equatable.dart';

class HealthGoal extends Equatable {
  final int id;
  final String goalType;
  final String label;
  final String description;
  final double? targetValue;
  final double? currentValue;
  final String unit;
  final String status;
  final int priority;
  final String? triggeredBy;
  final String? source;

  const HealthGoal({
    required this.id,
    required this.goalType,
    required this.label,
    required this.description,
    this.targetValue,
    this.currentValue,
    this.unit = '',
    required this.status,
    required this.priority,
    this.triggeredBy,
    this.source,
  });

  factory HealthGoal.fromJson(Map<String, dynamic> json) {
    return HealthGoal(
      id: json['id'] as int,
      goalType: json['goal_type'] as String,
      label: json['label'] as String? ?? json['goal_type'] as String,
      description: json['description'] as String? ?? '',
      targetValue: json['target_value'] != null ? (json['target_value'] as num).toDouble() : null,
      currentValue: json['current_value'] != null ? (json['current_value'] as num).toDouble() : null,
      unit: json['unit'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      priority: json['priority'] as int,
      triggeredBy: json['triggered_by'] as String?,
      source: json['source'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, goalType, priority];
}
