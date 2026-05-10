import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/local_database.dart';
import '../../../core/config/env_config.dart';
import '../../../core/identity/local_identity_model.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/data/models/auth_response_model.dart';
import 'cloud_identity_api.dart';
import 'cloud_identity_status_model.dart';

final cloudIdentityRepositoryProvider =
    Provider<CloudIdentityRepository>((ref) {
  return CloudIdentityRepository(
    identityRepository: ref.read(localIdentityRepositoryProvider),
    api: CloudIdentityApi(),
    storage: SecureStorageService.instance,
    settings: ref.read(settingsServiceProvider),
    database: LocalDatabase.instance,
  );
});

class CloudIdentityRepository {
  CloudIdentityRepository({
    required LocalIdentityRepository identityRepository,
    required CloudIdentityApi api,
    required SecureStorageService storage,
    required SettingsService settings,
    required LocalDatabase database,
  })  : _identityRepository = identityRepository,
        _api = api,
        _storage = storage,
        _settings = settings,
        _database = database;

  final LocalIdentityRepository _identityRepository;
  final CloudIdentityApi _api;
  final SecureStorageService _storage;
  final SettingsService _settings;
  final LocalDatabase _database;

  Future<LocalIdentityModel?> getLocalIdentity() {
    return _identityRepository.getCurrentIdentity();
  }

  Future<bool> needsCloudAccount() async {
    final identity = await getLocalIdentity();
    if (identity == null) return false;
    return !identity.isCloudReady;
  }

  Future<CloudBootstrapResult> createCloudAccountFromLocalIdentity() async {
    if (!EnvConfig.isConfigured) {
      const message =
          'Cloud sync is not configured. Add API_BASE_URL and try again.';
      await _identityRepository.markCloudFailure(message);
      return CloudBootstrapResult.failure(message);
    }
    final identity = await getLocalIdentity();
    if (identity == null) {
      return CloudBootstrapResult.failure(
        'Create your TrailLink profile before using Online Mode.',
      );
    }
    if (identity.isCloudReady) {
      return CloudBootstrapResult.ready(publicUserId: identity.publicUserId);
    }
    await _identityRepository.markCloudCreating();

    try {
      final session = await _database.ensureSession();
      final auth = await _api.bootstrapIdentity(
        localUserId: identity.localUserId,
        displayName: identity.displayName,
        email: identity.email,
        phoneNumber: identity.phoneNumber,
        emergencyNote: identity.emergencyNote,
        deviceId: session['session_id']?.toString(),
      );
      final savedIdentity = await saveCloudIdentityResult(auth);
      return CloudBootstrapResult(
        success: true,
        user: auth.user,
        publicUserId: savedIdentity.publicUserId,
        message: 'Cloud account ready.',
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      final message = cloudSetupFailureMessageForDio(error);
      await _identityRepository.markCloudFailure(message);
      return CloudBootstrapResult.failure(
        message,
        emailConflict: statusCode == 409,
      );
    } catch (error) {
      final message =
          'Cloud account creation failed. Check backend connection and try again.';
      await _identityRepository.markCloudFailure(message);
      return CloudBootstrapResult.failure(message);
    }
  }

  Future<LocalIdentityModel> saveCloudIdentityResult(
    AuthResponseModel auth,
  ) async {
    await _storage.saveToken(auth.token);
    final saved =
        await _identityRepository.saveAuthenticatedIdentity(auth.user);
    await _settings.setString('identity_sync_state', saved.syncState);
    await _settings.setString(
      'identity_bootstrap_synced_at',
      DateTime.now().toIso8601String(),
    );
    return saved;
  }

  Future<void> markSyncComplete() async {
    final identity = await getLocalIdentity();
    if (identity == null) return;
    await _identityRepository.updateIdentity(
      identity.copyWith(
        syncState: 'synced',
        lastCloudSyncAt: DateTime.now(),
        clearCloudErrorMessage: true,
      ),
    );
  }

  static String cloudSetupFailureMessageForDio(
    DioException error, {
    bool hasNetworkInterface = true,
  }) {
    if (!hasNetworkInterface) {
      return 'No internet connection.';
    }
    if (error.response?.statusCode == 409) {
      return 'This email is already linked to another TrailLink profile.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Cloud setup timed out.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'TrailLink cloud server is unreachable.';
    }
    return 'Cloud account creation failed.';
  }
}
