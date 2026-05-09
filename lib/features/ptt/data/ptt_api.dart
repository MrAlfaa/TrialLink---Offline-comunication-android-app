import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/voice_note_model.dart';

class PttApi {
  PttApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<VoiceNoteModel> uploadVoiceNote({
    required String groupId,
    required String currentUserId,
    required String localVoiceId,
    required String filePath,
    required int durationMs,
    required DateTime createdAt,
  }) async {
    final data = FormData.fromMap({
      'clientVoiceId': localVoiceId,
      'durationMs': durationMs,
      'createdAt': createdAt.toIso8601String(),
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: '$localVoiceId.m4a',
      ),
    });
    final response = await _dio.post(
      '/groups/$groupId/voice-notes',
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
    final payload = response.data['data'] as Map<String, dynamic>;
    return VoiceNoteModel.fromApiJson(
      payload['voiceNote'] as Map<String, dynamic>,
      currentUserId: currentUserId,
    );
  }

  Future<List<VoiceNoteModel>> listVoiceNotes({
    required String groupId,
    required String currentUserId,
  }) async {
    final response = await _dio.get('/groups/$groupId/voice-notes');
    final payload = response.data['data'] as Map<String, dynamic>;
    return (payload['voiceNotes'] as List<dynamic>)
        .map((item) => VoiceNoteModel.fromApiJson(
              item as Map<String, dynamic>,
              currentUserId: currentUserId,
            ))
        .toList();
  }
}
