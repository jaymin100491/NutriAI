import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/chat_model.dart';

class ChatRepository {
  final DioClient _dioClient;

  ChatRepository(this._dioClient);

  Future<ChatResponse> sendMessage(String message) async {
    final response = await _dioClient.dio.post(
      ApiConstants.chat,
      data: {'message': message},
    );
    return ChatResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> getHistory() async {
    final response = await _dioClient.dio.get(ApiConstants.chatHistory);
    final data = response.data as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>;
    return messages.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<void> clearHistory() async {
    await _dioClient.dio.delete(ApiConstants.chatHistory);
  }
}
