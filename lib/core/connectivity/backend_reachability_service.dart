import 'package:dio/dio.dart';

import '../config/env_config.dart';

class BackendReachabilityService {
  BackendReachabilityService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: EnvConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 3),
                receiveTimeout: const Duration(seconds: 3),
                sendTimeout: const Duration(seconds: 3),
                headers: {
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<bool> checkBackendReachable() async {
    if (EnvConfig.apiBaseUrl.trim().isEmpty) return false;

    try {
      final response = await _dio.get('/health/ping');
      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return data['success'] == true;
      }
      return false;
    } catch (_) {
      try {
        final fallback = await _dio.get('/health');
        final data = fallback.data;
        return fallback.statusCode == 200 &&
            data is Map<String, dynamic> &&
            data['success'] == true;
      } catch (_) {
        return false;
      }
    }
  }
}
