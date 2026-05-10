import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_identity_bootstrap_service.dart';
import 'cloud_identity_status_model.dart';

final cloudSyncControllerProvider =
    StateNotifierProvider<CloudSyncController, CloudSyncState>((ref) {
  return CloudSyncController(
    service: ref.read(cloudIdentityBootstrapServiceProvider),
  );
});

class CloudSyncController extends StateNotifier<CloudSyncState> {
  CloudSyncController({required CloudIdentityBootstrapService service})
      : _service = service,
        super(const CloudSyncState());

  final CloudIdentityBootstrapService _service;
  Future<CloudBootstrapResult>? _activeRequest;

  Future<CloudBootstrapResult> ensureCloudReadyBeforeOnlineMode() async {
    final active = _activeRequest;
    if (active != null) return active;

    final request = _ensureCloudReady();
    _activeRequest = request;
    try {
      return await request;
    } finally {
      _activeRequest = null;
    }
  }

  Future<CloudBootstrapResult> retryCloudBootstrap() {
    clear();
    return ensureCloudReadyBeforeOnlineMode();
  }

  void clear() {
    state = const CloudSyncState();
  }

  Future<CloudBootstrapResult> _ensureCloudReady() async {
    state = CloudSyncState.creatingAccount(
      progressPercent: 15,
      currentStep: 'Local profile found',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    state = CloudSyncState.creatingAccount(
      progressPercent: 45,
      currentStep: 'Creating your TrailLink cloud account...',
    );

    final result = await _service.ensureCloudReadyBeforeOnlineMode();
    if (!result.success) {
      state = CloudSyncState.error(
        result.errorMessage ?? 'Cloud account creation failed.',
        emailConflict: result.emailConflict,
      );
      return result;
    }

    state = CloudSyncState.syncing(
      progressPercent: 82,
      currentStep: 'Syncing offline data...',
      publicUserId: result.publicUserId,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));

    state = CloudSyncState.success(
      result.publicUserId ?? 'Cloud profile',
      successMessage: result.skipped ? 'Sync complete' : 'Cloud account ready',
    );
    return result;
  }
}
