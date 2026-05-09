import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_service.dart';
import '../../chat/data/message_sync_service.dart';
import '../../emergency/data/emergency_repository.dart';
import '../../location/data/location_sync_service.dart';
import 'cloud_identity_repository.dart';
import 'cloud_identity_status_model.dart';

final cloudIdentityBootstrapServiceProvider =
    Provider<CloudIdentityBootstrapService>((ref) {
  return CloudIdentityBootstrapService(
    repository: ref.read(cloudIdentityRepositoryProvider),
    settings: ref.read(settingsServiceProvider),
    messageSyncService: MessageSyncService(),
    emergencyRepository: EmergencyRepository(),
    locationSyncService: LocationSyncService(),
  );
});

class CloudIdentityBootstrapService {
  CloudIdentityBootstrapService({
    required CloudIdentityRepository repository,
    required SettingsService settings,
    required MessageSyncService messageSyncService,
    required EmergencyRepository emergencyRepository,
    required LocationSyncService locationSyncService,
  })  : _repository = repository,
        _settings = settings,
        _messageSyncService = messageSyncService,
        _emergencyRepository = emergencyRepository,
        _locationSyncService = locationSyncService;

  final CloudIdentityRepository _repository;
  final SettingsService _settings;
  final MessageSyncService _messageSyncService;
  final EmergencyRepository _emergencyRepository;
  final LocationSyncService _locationSyncService;

  Future<bool> needsCloudAccount() {
    return _repository.needsCloudAccount();
  }

  Future<CloudBootstrapResult> ensureCloudReadyBeforeOnlineMode() async {
    final identity = await _repository.getLocalIdentity();
    if (identity == null) {
      return CloudBootstrapResult.failure(
        'Create your TrailLink profile before using Online Mode.',
      );
    }
    final result = identity.isCloudReady
        ? CloudBootstrapResult.ready(publicUserId: identity.publicUserId)
        : await createCloudAccountFromLocalIdentity();
    if (!result.success) return result;

    await syncPendingData();
    return result;
  }

  Future<CloudBootstrapResult> createCloudAccountFromLocalIdentity() {
    return _repository.createCloudAccountFromLocalIdentity();
  }

  Future<void> saveCloudIdentityResult(CloudBootstrapResult result) async {
    if (!result.success) return;
    await _settings.setString('identity_sync_state', 'needs_sync');
  }

  Future<CloudBootstrapResult> retryCloudBootstrap() {
    return ensureCloudReadyBeforeOnlineMode();
  }

  Future<void> syncPendingData() async {
    if (!await _settings.getBool('auto_sync_when_online', true)) {
      return;
    }
    if (await _settings.getBool('sync_offline_messages', true)) {
      await _messageSyncService.syncPendingMessages();
    }
    if (await _settings.getBool('sync_sos_history', true)) {
      await _emergencyRepository.syncPendingEmergencies();
    }
    if (await _settings.getBool('sync_location_history', true)) {
      await _locationSyncService.syncPendingLocations();
    }
    // SOS, voice, trip, channel, and bridge category sync stay local-safe until
    // their existing repositories expose complete idempotent sync entrypoints.
    await _repository.markSyncComplete();
  }
}
