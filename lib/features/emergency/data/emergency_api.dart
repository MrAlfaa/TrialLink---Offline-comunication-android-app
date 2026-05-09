import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'models/emergency_event_model.dart';

class EmergencyApi {
  EmergencyApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<EmergencyEventModel> createEmergency({
    required String groupId,
    required EmergencyEventModel event,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/emergency',
      data: event.toApiJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return EmergencyEventModel.fromApiJson(
      data['event'] as Map<String, dynamic>,
    );
  }

  Future<EmergencyEventModel> createBridgeEmergency({
    required String groupId,
    required OfflinePacketModel packet,
    required Map<String, dynamic> metadata,
  }) async {
    final location = packet.payload['location'] as Map<String, dynamic>?;
    final response = await _dio.post(
      '/groups/$groupId/emergency',
      data: {
        'clientEventId': packet.localEventId ?? packet.packetId,
        'alertType': packet.payload['alertType']?.toString() ?? 'sos',
        'message': packet.payload['message']?.toString() ?? '',
        if (location != null) 'location': location,
        'createdAt': packet.createdAt.toIso8601String(),
        ...metadata,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return EmergencyEventModel.fromApiJson(
      data['event'] as Map<String, dynamic>,
    );
  }

  Future<List<EmergencyEventModel>> listEmergencies({
    required String groupId,
    String? status,
  }) async {
    final response = await _dio.get(
      '/groups/$groupId/emergency',
      queryParameters: {
        if (status != null) 'status': status,
        'limit': 50,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['events'] as List<dynamic>)
        .map((item) =>
            EmergencyEventModel.fromApiJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EmergencyEventModel> acknowledge({
    required String groupId,
    required String eventId,
    String? note,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/emergency/$eventId/ack',
      data: {if (note != null) 'note': note},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return EmergencyEventModel.fromApiJson(
      data['event'] as Map<String, dynamic>,
    );
  }
}
