import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class NetworkProbeResult {
  const NetworkProbeResult({
    required this.backendReachable,
    this.pingMs,
    this.downloadMbps,
    this.uploadMbps,
    this.errorMessage,
  });

  final bool backendReachable;
  final int? pingMs;
  final double? downloadMbps;
  final double? uploadMbps;
  final String? errorMessage;
}

class NetworkSpeedProbeService {
  NetworkSpeedProbeService({
    Dio? dio,
    this.downloadBytes = 262144,
    this.uploadBytes = 32768,
  }) : _dio = dio ?? DioClient.instance;

  final Dio _dio;
  final int downloadBytes;
  final int uploadBytes;

  Future<NetworkProbeResult> measure({bool includeUpload = false}) async {
    try {
      final pingWatch = Stopwatch()..start();
      await _dio.get('/network/probe/ping');
      pingWatch.stop();

      final downloadWatch = Stopwatch()..start();
      final response = await _dio.get<List<int>>(
        '/network/probe/download',
        queryParameters: {'bytes': downloadBytes},
        options: Options(responseType: ResponseType.bytes),
      );
      downloadWatch.stop();
      final byteCount = response.data?.length ?? downloadBytes;
      final downloadMbps = calculateMbps(
        bytes: byteCount,
        elapsed: downloadWatch.elapsed,
      );

      double? uploadMbps;
      if (includeUpload) {
        final uploadPayload = 'u' * min(uploadBytes, 32768);
        final uploadWatch = Stopwatch()..start();
        await _dio.post(
          '/network/probe/upload',
          data: {'payload': uploadPayload},
        );
        uploadWatch.stop();
        uploadMbps = calculateMbps(
          bytes: uploadPayload.length,
          elapsed: uploadWatch.elapsed,
        );
      }

      return NetworkProbeResult(
        backendReachable: true,
        pingMs: pingWatch.elapsedMilliseconds,
        downloadMbps: downloadMbps,
        uploadMbps: uploadMbps,
      );
    } catch (error) {
      return NetworkProbeResult(
        backendReachable: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  static double calculateMbps({
    required int bytes,
    required Duration elapsed,
  }) {
    final seconds = max(elapsed.inMicroseconds / 1000000, 0.001);
    return (bytes * 8) / seconds / 1000000;
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      return error.message ?? 'Network check failed.';
    }
    return error.toString();
  }
}
