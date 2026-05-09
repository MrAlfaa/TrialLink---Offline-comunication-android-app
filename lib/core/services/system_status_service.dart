import 'package:dio/dio.dart';

import '../config/env_config.dart';
import '../database/local_database.dart';
import '../network/dio_client.dart';

enum SystemCheckState {
  idle,
  loading,
  success,
  warning,
  error,
}

class SystemCheckResult {
  const SystemCheckResult({
    required this.title,
    required this.message,
    required this.state,
    this.detail,
  });

  final String title;
  final String message;
  final SystemCheckState state;
  final String? detail;
}

class SystemStatusService {
  Future<SystemCheckResult> checkBackend() async {
    if (!EnvConfig.isConfigured) {
      return const SystemCheckResult(
        title: 'Backend API',
        message: 'API_BASE_URL is not configured.',
        state: SystemCheckState.warning,
      );
    }

    try {
      final response = await DioClient.instance.get('/health');
      final data = response.data as Map<String, dynamic>;

      return SystemCheckResult(
        title: 'Backend API',
        message: data['message']?.toString() ?? 'Backend API connected',
        state: SystemCheckState.success,
        detail: 'Environment: ${data['environment'] ?? EnvConfig.appEnv}',
      );
    } on DioException catch (error) {
      return SystemCheckResult(
        title: 'Backend API',
        message: 'Backend connection failed.',
        state: SystemCheckState.error,
        detail: error.message,
      );
    } catch (error) {
      return SystemCheckResult(
        title: 'Backend API',
        message: 'Backend connection failed.',
        state: SystemCheckState.error,
        detail: error.toString(),
      );
    }
  }

  Future<SystemCheckResult> checkMongoDb() async {
    if (!EnvConfig.isConfigured) {
      return const SystemCheckResult(
        title: 'MongoDB Atlas',
        message: 'API_BASE_URL is not configured.',
        state: SystemCheckState.warning,
      );
    }

    try {
      final response = await DioClient.instance.get('/health/db');
      final data = response.data as Map<String, dynamic>;

      return SystemCheckResult(
        title: 'MongoDB Atlas',
        message: data['message']?.toString() ?? 'MongoDB Atlas connected',
        state: SystemCheckState.success,
        detail: 'State: ${data['dbState'] ?? 'connected'}',
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map<String, dynamic>
          ? 'State: ${data['dbState'] ?? 'unknown'}'
          : error.message;

      return SystemCheckResult(
        title: 'MongoDB Atlas',
        message: 'MongoDB Atlas failed or is not configured.',
        state: SystemCheckState.error,
        detail: detail,
      );
    } catch (error) {
      return SystemCheckResult(
        title: 'MongoDB Atlas',
        message: 'MongoDB Atlas failed or is not configured.',
        state: SystemCheckState.error,
        detail: error.toString(),
      );
    }
  }

  Future<SystemCheckResult> checkSQLite() async {
    try {
      final message = await LocalDatabase.instance.testSQLite();

      return SystemCheckResult(
        title: 'Local SQLite',
        message: message,
        state: SystemCheckState.success,
      );
    } catch (error) {
      return SystemCheckResult(
        title: 'Local SQLite',
        message: 'SQLite initialization failed.',
        state: SystemCheckState.error,
        detail: error.toString(),
      );
    }
  }

  Future<SystemCheckResult> checkEnvironment() async {
    if (EnvConfig.isLoaded && EnvConfig.isConfigured) {
      return SystemCheckResult(
        title: 'Environment Config',
        message: 'Environment configuration loaded.',
        state: SystemCheckState.success,
        detail: EnvConfig.apiBaseUrl,
      );
    }

    return SystemCheckResult(
      title: 'Environment Config',
      message: 'Environment file missing or incomplete.',
      state: SystemCheckState.warning,
      detail: EnvConfig.loadError ?? 'Copy .env.example to .env.',
    );
  }

  Future<SystemCheckResult> checkSession() async {
    try {
      final session = await LocalDatabase.instance.ensureSession();
      return SystemCheckResult(
        title: 'Local Session',
        message: 'Anonymous local session ready.',
        state: SystemCheckState.success,
        detail: session['session_id']?.toString(),
      );
    } catch (error) {
      return SystemCheckResult(
        title: 'Local Session',
        message: 'Local session could not be created.',
        state: SystemCheckState.error,
        detail: error.toString(),
      );
    }
  }
}
