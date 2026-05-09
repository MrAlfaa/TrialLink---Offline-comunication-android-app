import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/models/user_model.dart';
import '../settings/settings_service.dart';
import 'local_identity_model.dart';
import 'local_identity_repository.dart';

final identityBootstrapServiceProvider =
    Provider<IdentityBootstrapService>((ref) {
  return IdentityBootstrapService(
    identityRepository: ref.read(localIdentityRepositoryProvider),
    settings: ref.read(settingsServiceProvider),
  );
});

class IdentityBootstrapResult {
  const IdentityBootstrapResult({
    required this.identity,
    this.user,
    required this.synced,
    this.message,
  });

  final LocalIdentityModel identity;
  final UserModel? user;
  final bool synced;
  final String? message;
}

class IdentityBootstrapService {
  IdentityBootstrapService({
    required LocalIdentityRepository identityRepository,
    required SettingsService settings,
  })  : _identityRepository = identityRepository,
        _settings = settings;

  final LocalIdentityRepository _identityRepository;
  final SettingsService _settings;

  Future<IdentityBootstrapResult> createIdentity({
    required String displayName,
    String? email,
    String? phoneNumber,
    String? emergencyNote,
  }) async {
    final identity = await _identityRepository.createLocalIdentity(
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      emergencyNote: emergencyNote,
    );

    await _settings.setString('identity_sync_state', 'needs_cloud_create');
    return IdentityBootstrapResult(
      identity: identity,
      synced: false,
      message:
          'TrailLink profile saved locally. Cloud setup will run when you go online.',
    );
  }
}
