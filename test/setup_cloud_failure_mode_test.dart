import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/connectivity/app_connection_mode.dart';
import 'package:traillink/core/connectivity/connection_mode_controller.dart';
import 'package:traillink/core/database/local_database.dart';
import 'package:traillink/core/identity/local_identity_model.dart';
import 'package:traillink/core/identity/local_identity_repository.dart';
import 'package:traillink/core/mode/mode_controller.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/core/settings/app_settings_defaults.dart';
import 'package:traillink/core/settings/settings_service.dart';
import 'package:traillink/core/setup/setup_progress_service.dart';
import 'package:traillink/features/chat/data/chat_api.dart';
import 'package:traillink/features/chat/data/message_sync_service.dart';
import 'package:traillink/features/chat/data/message_dao.dart';
import 'package:traillink/features/chat/data/socket_service.dart';
import 'package:traillink/features/cloud_identity/data/cloud_identity_repository.dart';
import 'package:traillink/features/cloud_identity/data/cloud_identity_status_model.dart';
import 'package:traillink/features/emergency/data/emergency_api.dart';
import 'package:traillink/features/emergency/data/emergency_repository.dart';
import 'package:traillink/features/location/data/location_api.dart';
import 'package:traillink/features/location/data/location_repository.dart';
import 'package:traillink/features/location/data/location_sync_service.dart';
import 'package:traillink/features/setup/data/setup_cloud_failure_recovery_service.dart';

void main() {
  group('setup cloud failure fallback', () {
    test('Continue Offline persists manual offline and completes setup',
        () async {
      final settings = _FakeSettingsService();
      final identityRepository = _FakeLocalIdentityRepository(
        _localIdentity(cloudStatus: 'sync_failed', syncState: 'failed'),
      );
      final service = SetupCloudFailureRecoveryService(
        settings: settings,
        setupProgressService: SetupProgressService(settings),
        identityRepository: identityRepository,
      );

      await service.continueOfflineAfterCloudFailure();

      expect(await settings.getString('mode_control_type', ''), 'manual');
      expect(
        await settings.getString('manual_communication_mode', ''),
        'offline',
      );
      expect(await settings.getString(AppSettingsDefaults.userMode, ''),
          'offline');
      expect(
        await settings.getString(AppSettingsDefaults.selectedMode, ''),
        'offline',
      );
      expect(await settings.getString('default_startup_mode', ''), 'offline');
      expect(await settings.getString('identity_sync_state', ''),
          'needs_cloud_create');
      expect(await settings.getBool(AppSettingsDefaults.setupCompleted, false),
          isTrue);
      expect(
          await settings.getBool(AppSettingsDefaults.onboardingComplete, false),
          isTrue);
      expect(await settings.getBool('cloud_blocking', true), isFalse);

      expect(identityRepository.identity?.cloudStatus, 'sync_failed');
      expect(identityRepository.identity?.syncState, 'needs_cloud_create');
      expect(identityRepository.updateCalls, 1);
    });

    test('Auto mode degrades to offline when cloud bootstrap fails', () async {
      final settings = _FakeSettingsService({
        'mode_control_type': 'auto',
        'manual_communication_mode': 'online',
        AppSettingsDefaults.userMode: 'auto',
        AppSettingsDefaults.selectedMode: 'auto',
      });
      var bootstrapCalls = 0;
      var overlayCleared = false;
      final controller = ModeController(
        settings: settings,
        socketService: SocketService(),
        messageSyncService: _messageSyncService(),
        emergencyRepository: _emergencyRepository(),
        locationSyncService: _locationSyncService(),
        ensureCloudReadyBeforeOnlineMode: () async {
          bootstrapCalls++;
          return CloudBootstrapResult.failure('Cloud account creation failed.');
        },
        clearCloudSetupOverlay: () => overlayCleared = true,
      );

      await controller.initializeMode();
      controller.updateDetectedConnection(
        const ConnectionModeState(
          mode: AppConnectionMode.online,
          hasNetworkInterface: true,
          backendReachable: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bootstrapCalls, 1);
      expect(overlayCleared, isTrue);
      expect(controller.state.modeControlType, ModeControlType.auto);
      expect(controller.state.userMode, UserMode.auto);
      expect(controller.state.effectiveMode, EffectiveMode.offline);
      expect(
        controller.state.warningMessage,
        'Cloud setup failed. Offline Mode is available. TrailLink will retry cloud setup when the server is reachable.',
      );
    });

    test('Offline mode setup does not attempt cloud bootstrap', () async {
      final settings = _FakeSettingsService({
        'mode_control_type': 'manual',
        'manual_communication_mode': 'offline',
        AppSettingsDefaults.userMode: 'offline',
        AppSettingsDefaults.selectedMode: 'offline',
      });
      var bootstrapCalls = 0;
      final controller = ModeController(
        settings: settings,
        socketService: SocketService(),
        messageSyncService: _messageSyncService(),
        emergencyRepository: _emergencyRepository(),
        locationSyncService: _locationSyncService(),
        ensureCloudReadyBeforeOnlineMode: () async {
          bootstrapCalls++;
          return CloudBootstrapResult.failure('Cloud account creation failed.');
        },
      );

      await controller.initializeMode(
        connection: const ConnectionModeState(
          mode: AppConnectionMode.online,
          hasNetworkInterface: true,
          backendReachable: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state.effectiveMode, EffectiveMode.offline);
      expect(bootstrapCalls, 0);
    });
  });

  group('cloud setup error wording', () {
    test('distinguishes no internet from backend unreachable', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/identity/bootstrap'),
        type: DioExceptionType.connectionError,
      );

      expect(
        CloudIdentityRepository.cloudSetupFailureMessageForDio(
          error,
          hasNetworkInterface: false,
        ),
        'No internet connection.',
      );
      expect(
        CloudIdentityRepository.cloudSetupFailureMessageForDio(error),
        'TrailLink cloud server is unreachable.',
      );
    });

    test('distinguishes timeout, email conflict, and bootstrap failure', () {
      final timeout = DioException(
        requestOptions: RequestOptions(path: '/identity/bootstrap'),
        type: DioExceptionType.connectionTimeout,
      );
      final conflict = DioException(
        requestOptions: RequestOptions(path: '/identity/bootstrap'),
        response: Response(
          requestOptions: RequestOptions(path: '/identity/bootstrap'),
          statusCode: 409,
        ),
        type: DioExceptionType.badResponse,
      );
      final failed = DioException(
        requestOptions: RequestOptions(path: '/identity/bootstrap'),
        response: Response(
          requestOptions: RequestOptions(path: '/identity/bootstrap'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        CloudIdentityRepository.cloudSetupFailureMessageForDio(timeout),
        'Cloud setup timed out.',
      );
      expect(
        CloudIdentityRepository.cloudSetupFailureMessageForDio(conflict),
        'This email is already linked to another TrailLink profile.',
      );
      expect(
        CloudIdentityRepository.cloudSetupFailureMessageForDio(failed),
        'Cloud account creation failed.',
      );
    });
  });
}

LocalIdentityModel _localIdentity({
  String cloudStatus = 'local_only',
  String syncState = 'needs_cloud_create',
}) {
  return LocalIdentityModel(
    localUserId: 'local-1',
    displayName: 'Trail User',
    email: 'trail@example.com',
    identityType: 'local_only',
    createdOffline: true,
    cloudStatus: cloudStatus,
    syncState: syncState,
    createdAt: DateTime.utc(2026, 5, 9),
  );
}

MessageSyncService _messageSyncService() {
  return MessageSyncService(
    api: ChatApi(dio: Dio()),
    dao: MessageDao(),
  );
}

EmergencyRepository _emergencyRepository() {
  return EmergencyRepository(
    api: EmergencyApi(dio: Dio()),
    locationRepository: LocationRepository(api: LocationApi(dio: Dio())),
  );
}

LocationSyncService _locationSyncService() {
  return LocationSyncService(
    repository: LocationRepository(api: LocationApi(dio: Dio())),
  );
}

class _FakeLocalIdentityRepository extends LocalIdentityRepository {
  _FakeLocalIdentityRepository(this.identity);

  LocalIdentityModel? identity;
  int updateCalls = 0;

  @override
  Future<LocalIdentityModel?> getCurrentIdentity() async => identity;

  @override
  Future<void> updateIdentity(LocalIdentityModel identity) async {
    this.identity = identity;
    updateCalls++;
  }
}

class _FakeSettingsService extends SettingsService {
  _FakeSettingsService([Map<String, String>? values])
      : _values = {...?values},
        super(LocalDatabase.instance);

  final Map<String, String> _values;

  @override
  Future<bool> getBool(String key, bool defaultValue) async {
    return (_values[key] ?? (defaultValue ? 'true' : 'false')) == 'true';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    _values[key] = value ? 'true' : 'false';
  }

  @override
  Future<String> getString(String key, String defaultValue) async {
    return _values[key] ?? defaultValue;
  }

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }
}
