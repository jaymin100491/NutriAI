import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  final int id;
  final String role;
  final String content;
  final String timestamp;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  @override
  List<Object?> get props => [id, role, content];
}

class ChatResponse extends Equatable {
  final String response;
  final bool planModified;
  final bool goalsUpdated;
  final List<String> suggestions;
  final int? updatedPlanId;

  const ChatResponse({
    required this.response,
    this.planModified = false,
    this.goalsUpdated = false,
    this.suggestions = const [],
    this.updatedPlanId,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'] as String,
      planModified: json['plan_modified'] as bool? ?? false,
      goalsUpdated: json['goals_updated'] as bool? ?? false,
      suggestions: json['suggestions'] != null
          ? (json['suggestions'] as List<dynamic>).map((e) => e.toString()).toList()
          : [],
      updatedPlanId: json['updated_plan_id'] as int?,
    );
  }

  @override
  List<Object?> get props => [response, planModified];
}
