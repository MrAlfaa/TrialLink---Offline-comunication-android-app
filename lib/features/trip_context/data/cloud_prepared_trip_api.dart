import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/cloud_prepared_trip_metadata.dart';

class CloudPreparedTripApi {
  CloudPreparedTripApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<CloudPreparedTripMetadata> createCloudPreparedTrip({
    required String tripName,
    String? description,
    required String localUserId,
    required String appDeviceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trip-context/cloud-prepared-trips',
      data: {
        'tripName': tripName.trim(),
        if ((description ?? '').trim().isNotEmpty)
          'description': description!.trim(),
        'localUserId': localUserId,
        'appDeviceId': appDeviceId,
        'capabilities': _capabilities,
      },
    );
    return _metadataFromResponse(response);
  }

  Future<CloudPreparedTripMetadata> joinCloudPreparedTrip({
    required String tripCode,
    required String localUserId,
    required String appDeviceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/trip-context/cloud-prepared-trips/join',
      data: {
        'tripCode': tripCode.trim().toUpperCase(),
        'localUserId': localUserId,
        'appDeviceId': appDeviceId,
        'capabilities': _capabilities,
      },
    );
    return _metadataFromResponse(response);
  }

  Future<CloudPreparedTripMetadata> getCloudPreparedTripMetadata(
    String tripId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/trip-context/cloud-prepared-trips/$tripId/metadata',
    );
    return _metadataFromResponse(response);
  }

  CloudPreparedTripMetadata _metadataFromResponse(
    Response<Map<String, dynamic>> response,
  ) {
    final body = response.data ?? const <String, dynamic>{};
    return CloudPreparedTripMetadata.fromJson(
      body['data'] as Map<String, dynamic>,
    );
  }

  static const _capabilities = {
    'supportsNearby': true,
    'supportsPtt': true,
    'supportsLiveRadio': false,
  };
}
