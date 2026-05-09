import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/auth_response_model.dart';
import 'models/user_model.dart';

class AuthApi {
  AuthApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<AuthResponseModel> register({
    required String fullName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final trimmedPhoneNumber = phoneNumber?.trim();

    final response = await _dio.post(
      '/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (trimmedPhoneNumber != null && trimmedPhoneNumber.isNotEmpty)
          'phoneNumber': trimmedPhoneNumber,
      },
    );

    return AuthResponseModel.fromJson(
      (response.data['data'] as Map<String, dynamic>),
    );
  }

  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return AuthResponseModel.fromJson(
      (response.data['data'] as Map<String, dynamic>),
    );
  }

  Future<UserModel> me() async {
    final response = await _dio.get('/auth/me');
    final data = response.data['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthResponseModel> bootstrapIdentity({
    required String displayName,
    required String email,
    String? phoneNumber,
    String? localUserId,
  }) async {
    final response = await _dio.post(
      '/identity/bootstrap',
      data: {
        'displayName': displayName,
        'fullName': displayName,
        'email': email,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber.trim(),
        if (localUserId != null && localUserId.trim().isNotEmpty)
          'localUserId': localUserId.trim(),
      },
    );

    return AuthResponseModel.fromJson(
      (response.data['data'] as Map<String, dynamic>),
    );
  }
}
