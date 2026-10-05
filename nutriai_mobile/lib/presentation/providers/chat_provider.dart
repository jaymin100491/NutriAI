import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/chat_model.dart';
import '../../data/repositories/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(dioClientProvider));
});

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final List<String> suggestions;
  final bool planModified;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.suggestions = const [],
    this.planModified = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    List<String>? suggestions,
    bool? planModified,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      suggestions: suggestions ?? this.suggestions,
      planModified: planModified ?? this.planModified,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;

  ChatNotifier(this._repository) : super(ChatState());

  Future<void> loadHistory() async {
    try {
      final messages = await _repository.getHistory();
      state = state.copyWith(messages: messages);
    } catch (_) {}
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: state.messages.length + 1,
      role: 'user',
      content: message,
      timestamp: DateTime.now().toIso8601String(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final response = await _repository.sendMessage(message);
      final assistantMsg = ChatMessage(
        id: state.messages.length + 1,
        role: 'assistant',
        content: response.response,
        timestamp: DateTime.now().toIso8601String(),
        metadata: {
          'plan_modified': response.planModified,
          'goals_updated': response.goalsUpdated,
        },
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        suggestions: response.suggestions,
        planModified: response.planModified || response.goalsUpdated,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send message. Is the backend running?',
      );
    }
  }

  void clearChat() {
    _repository.clearHistory();
    state = ChatState();
  }
}

final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider));
});
