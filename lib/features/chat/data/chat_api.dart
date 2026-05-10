import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/chat_message_model.dart';

class ChatApi {
  ChatApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<ChatMessageModel>> getGroupMessages({
    required String groupId,
    required String currentUserId,
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '/groups/$groupId/messages',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>;
    return messages
        .map(
          (item) => ChatMessageModel.fromApiJson(
            item as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> syncPendingMessages({
    required String groupId,
    required List<Map<String, dynamic>> messages,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/messages/sync',
      data: {'messages': messages},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['syncedMessages'] as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<ChatMessageModel> uploadMediaMessage({
    required String groupId,
    required String currentUserId,
    required String clientMessageId,
    required String messageType,
    required String filePath,
    required String fileName,
    String? content,
    String? tripId,
    String? channelId,
    String? chatId,
    String? mimeType,
    int? durationMs,
    DateTime? createdAt,
  }) async {
    final data = FormData.fromMap({
      'clientMessageId': clientMessageId,
      'messageType': messageType,
      if (content != null && content.trim().isNotEmpty)
        'content': content.trim(),
      if (tripId != null) 'tripId': tripId,
      if (channelId != null) 'channelId': channelId,
      if (chatId != null) 'chatId': chatId,
      if (durationMs != null) 'durationMs': durationMs,
      if (createdAt != null) 'createdAt': createdAt.toIso8601String(),
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
      ),
    });
    final response = await _dio.post(
      '/groups/$groupId/messages/media',
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
    final payload = response.data['data'] as Map<String, dynamic>;
    return ChatMessageModel.fromApiJson(
      payload['message'] as Map<String, dynamic>,
      currentUserId: currentUserId,
    );
  }
}
