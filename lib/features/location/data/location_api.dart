import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'models/location_freshness.dart';
import 'models/location_update_model.dart';
import 'models/teammate_location_model.dart';

class LocationApi {
  LocationApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<LocationUpdateModel> shareLocation({
    required String groupId,
    required LocationUpdateModel location,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/locations',
      data: location.toApiJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return LocationUpdateModel.fromApiJson(
      data['location'] as Map<String, dynamic>,
      currentUserId: location.userId,
    );
  }

  Future<List<LocationUpdateModel>> syncLocations({
    required String groupId,
    required String currentUserId,
    required List<LocationUpdateModel> locations,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/locations/sync',
      data: {'locations': locations.map((item) => item.toApiJson()).toList()},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['locations'] as List<dynamic>)
        .map(
          (item) => LocationUpdateModel.fromApiJson(
            item as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<List<LocationUpdateModel>> syncBridgeLocations({
    required String groupId,
    required OfflinePacketModel packet,
    required Map<String, dynamic> metadata,
  }) async {
    final response = await _dio.post(
      '/groups/$groupId/locations/sync',
      data: {
        'locations': [
          {
            'clientLocationId': packet.localLocationId ?? packet.packetId,
            'latitude': packet.payload['latitude'],
            'longitude': packet.payload['longitude'],
            if (packet.payload['accuracy'] != null)
              'accuracy': packet.payload['accuracy'],
            if (packet.payload['altitude'] != null)
              'altitude': packet.payload['altitude'],
            if (packet.payload['speed'] != null)
              'speed': packet.payload['speed'],
            if (packet.payload['heading'] != null)
              'heading': packet.payload['heading'],
            'capturedAt': packet.payload['capturedAt']?.toString() ??
                packet.createdAt.toIso8601String(),
            ...metadata,
          }
        ],
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['locations'] as List<dynamic>)
        .map(
          (item) => LocationUpdateModel.fromApiJson(
            item as Map<String, dynamic>,
            currentUserId: metadata['bridgedBy']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<List<TeammateLocationModel>> latestLocations(String groupId) async {
    final response = await _dio.get('/groups/$groupId/locations/latest');
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['locations'] as List<dynamic>).map((item) {
      final json = item as Map<String, dynamic>;
      final user = json['user'] as Map<String, dynamic>? ?? {};
      return TeammateLocationModel(
        userId: user['id']?.toString() ?? '',
        userName: user['fullName']?.toString() ?? 'TrailLink User',
        groupId: groupId,
        latitude: double.parse(json['latitude'].toString()),
        longitude: double.parse(json['longitude'].toString()),
        accuracy: json['accuracy'] == null
            ? null
            : double.tryParse(json['accuracy'].toString()),
        capturedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
            DateTime.now(),
        receivedAt: DateTime.now(),
        source: 'backend',
        freshness: calculateLocationFreshness(
          DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
              DateTime.now(),
        ),
      );
    }).toList();
  }
}
