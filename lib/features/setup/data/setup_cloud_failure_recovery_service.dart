import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/local_identity_repository.dart';
import '../../../core/mode/mode_models.dart';
import '../../../core/settings/app_settings_defaults.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/setup/setup_progress_service.dart';

final setupCloudFailureRecoveryServiceProvider =
    Provider<SetupCloudFailureRecoveryService>((ref) {
  return SetupCloudFailureRecoveryService(
    settings: ref.read(settingsServiceProvider),
    setupProgressService: ref.read(setupProgressServiceProvider),
    identityRepository: ref.read(localIdentityRepositoryProvider),
  );
});

class SetupCloudFailureRecoveryService {
  SetupCloudFailureRecoveryService({
    required SettingsService settings,
    required SetupProgressService setupProgressService,
    required LocalIdentityRepository identityRepository,
  })  : _settings = settings,
        _setupProgressService = setupProgressService,
        _identityRepository = identityRepository;

  final SettingsService _settings;
  final SetupProgressService _setupProgressService;
  final LocalIdentityRepository _identityRepository;

  Future<void> continueOfflineAfterCloudFailure() async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity != null) {
      await _identityRepository.updateIdentity(
        identity.copyWith(
          cloudStatus: 'sync_failed',
          syncState: 'needs_cloud_create',
          cloudErrorMessage:
              identity.cloudErrorMessage ?? 'Cloud account creation failed.',
          updatedAt: DateTime.now(),
        ),
      );
    }

    await _settings.setString(
      'mode_control_type',
      ModeControlType.manual.name,
    );
    await _settings.setString(
      'manual_communication_mode',
      ManualCommunicationMode.offline.name,
    );
    await _settings.setString(
      AppSettingsDefaults.userMode,
      UserMode.offline.name,
    );
    await _settings.setString(
      AppSettingsDefaults.selectedMode,
      UserMode.offline.name,
    );
    await _settings.setString(
      'default_startup_mode',
      UserMode.offline.name,
    );
    await _settings.setString('identity_sync_state', 'needs_cloud_create');
    await _settings.setBool('cloud_blocking', false);
    await _setupProgressService.completeSetup();
  }
}
