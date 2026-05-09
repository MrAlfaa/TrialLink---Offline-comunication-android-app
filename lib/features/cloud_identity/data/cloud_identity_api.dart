import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/data/models/auth_response_model.dart';

class CloudIdentityApi {
  CloudIdentityApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<AuthResponseModel> bootstrapIdentity({
    required String localUserId,
    required String displayName,
    String? email,
    String? phoneNumber,
    String? emergencyNote,
    String? deviceId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/identity/bootstrap',
      data: {
        'localUserId': localUserId,
        'displayName': displayName,
        if (_notBlank(email)) 'email': email!.trim(),
        if (_notBlank(phoneNumber)) 'phoneNumber': phoneNumber!.trim(),
        if (_notBlank(emergencyNote)) 'emergencyNote': emergencyNote!.trim(),
        if (_notBlank(deviceId)) 'deviceId': deviceId!.trim(),
      },
    );

    final body = response.data ?? <String, dynamic>{};
    return AuthResponseModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  bool _notBlank(String? value) => value != null && value.trim().isNotEmpty;
}
