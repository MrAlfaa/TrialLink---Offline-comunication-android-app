import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/chat/data/message_sync_service.dart';
import '../../features/chat/data/socket_service.dart';
import '../../features/cloud_identity/data/cloud_identity_status_model.dart';
import '../../features/cloud_identity/data/cloud_sync_controller.dart';
import '../../features/emergency/data/emergency_repository.dart';
import '../../features/location/data/location_sync_service.dart';
import '../connectivity/app_connection_mode.dart';
import '../connectivity/connection_mode_controller.dart';
import '../connectivity/connection_mode_provider.dart';
import '../identity/auth_access_controller.dart';
import '../identity/auth_access_state.dart';
import '../identity/local_identity_repository.dart';
import '../settings/app_settings_defaults.dart';
import '../settings/settings_service.dart';
import 'mode_models.dart';

final modeControllerProvider =
    StateNotifierProvider<ModeController, ModeState>((ref) {
  final controller = ModeController(
    settings: ref.read(settingsServiceProvider),
    socketService: ref.read(socketServiceProvider),
    messageSyncService: MessageSyncService(),
    emergencyRepository: EmergencyRepository(),
    locationSyncService: LocationSyncService(),
    ensureCloudReadyBeforeOnlineMode: () async {
      final result = await ref
          .read(cloudSyncControllerProvider.notifier)
          .ensureCloudReadyBeforeOnlineMode();
      final user = result.user;
      if (result.success && user != null) {
        final identity = await ref
            .read(localIdentityRepositoryProvider)
            .getCurrentIdentity();
        if (identity != null) {
          ref
              .read(authAccessControllerProvider.notifier)
              .setAuthenticatedOnline(
                identity: identity,
                user: user,
              );
        }
      }
      return result;
    },
    clearCloudSetupOverlay: () {
      ref.read(cloudSyncControllerProvider.notifier).clear();
    },
  );

  ref.listen(connectionModeProvider, (_, next) {
    controller.updateDetectedConnection(next);
  });
  ref.listen(authAccessControllerProvider, (_, next) {
    controller.updateAuthAccess(next.accessState, next.user);
  });

  unawaited(controller.initializeMode(
    connection: ref.read(connectionModeProvider),
    authAccess: ref.read(authAccessControllerProvider),
  ));
  return controller;
});

final modeStateProvider = Provider<ModeState>((ref) {
  return ref.watch(modeControllerProvider);
});

final effectiveModeProvider = Provider<EffectiveMode>((ref) {
  return ref.watch(modeControllerProvider).effectiveMode;
});

class ModeController extends StateNotifier<ModeState> {
  ModeController({
    required SettingsService settings,
    required SocketService socketService,
    required MessageSyncService messageSyncService,
    required EmergencyRepository emergencyRepository,
    required LocationSyncService locationSyncService,
    Future<CloudBootstrapResult> Function()? ensureCloudReadyBeforeOnlineMode,
    void Function()? clearCloudSetupOverlay,
  })  : _settings = settings,
        _socketService = socketService,
        _messageSyncService = messageSyncService,
        _emergencyRepository = emergencyRepository,
        _locationSyncService = locationSyncService,
        _ensureCloudReadyBeforeOnlineMode = ensureCloudReadyBeforeOnlineMode,
        _clearCloudSetupOverlay = clearCloudSetupOverlay,
        super(ModeState.initial());

  final SettingsService _settings;
  final SocketService _socketService;
  final MessageSyncService _messageSyncService;
  final EmergencyRepository _emergencyRepository;
  final LocationSyncService _locationSyncService;
  final Future<CloudBootstrapResult> Function()?
      _ensureCloudReadyBeforeOnlineMode;
  final void Function()? _clearCloudSetupOverlay;
  AuthAccessState _authAccessState = AuthAccessState.unauthenticated;
  UserModel? _user;
  bool _autoCloudBootstrapFailed = false;

  Future<void> initializeMode({
    ConnectionModeState? connection,
    AuthAccessStatus? authAccess,
  }) async {
    await loadModeSettings();
    if (authAccess != null) {
      _authAccessState = authAccess.accessState;
      _user = authAccess.user;
    }
    if (connection != null) {
      updateDetectedConnection(connection, runSync: false);
    } else {
      _recalculate(runSync: false);
    }
  }

  Future<void> loadModeSettings() async {
    final storedControl = await _settings.getString(
        'mode_control_type', ModeControlType.auto.name);
    final controlType = _parseModeControlType(storedControl);
    final storedManual = await _settings.getString(
      'manual_communication_mode',
      ManualCommunicationMode.offline.name,
    );
    final manualMode = _parseManualMode(storedManual);
    final legacyStored = await _settings.getString(
      'user_mode',
      await _settings.getString(
        AppSettingsDefaults.selectedMode,
        UserMode.auto.name,
      ),
    );
    final legacyUserMode = _parseUserMode(legacyStored);
    final userMode = controlType == ModeControlType.auto
        ? UserMode.auto
        : manualMode.userMode;
    final autoSwitch = await _settings.getBool('auto_switch_enabled', true);
    state = state.copyWith(
      userMode: userMode,
      modeControlType: controlType,
      manualCommunicationMode: controlType == ModeControlType.manual
          ? manualMode
          : legacyUserMode == UserMode.online
              ? ManualCommunicationMode.online
              : ManualCommunicationMode.offline,
      autoSwitchEnabled: autoSwitch,
    );
    _recalculate(runSync: false);
  }

  Future<void> saveModeSettings() async {
    await _settings.setString('user_mode', state.userMode.name);
    await _settings.setString(
      AppSettingsDefaults.selectedMode,
      state.userMode.name,
    );
    await _settings.setString(
      'mode_control_type',
      state.modeControlType.name,
    );
    await _settings.setString(
      'manual_communication_mode',
      state.manualCommunicationMode.name,
    );
    await _settings.setBool('auto_switch_enabled', state.autoSwitchEnabled);
  }

  Future<void> setUserMode(UserMode mode) async {
    _autoCloudBootstrapFailed = false;
    state = state.copyWith(
      userMode: mode,
      modeControlType:
          mode == UserMode.auto ? ModeControlType.auto : ModeControlType.manual,
      manualCommunicationMode: mode == UserMode.online
          ? ManualCommunicationMode.online
          : mode == UserMode.offline
              ? ManualCommunicationMode.offline
              : state.manualCommunicationMode,
    );
    await saveModeSettings();
    _recalculate();
  }

  Future<void> setModeControlType(ModeControlType type) async {
    _autoCloudBootstrapFailed = false;
    state = state.copyWith(
      modeControlType: type,
      userMode: type == ModeControlType.auto
          ? UserMode.auto
          : state.manualCommunicationMode.userMode,
    );
    await saveModeSettings();
    _recalculate();
  }

  Future<void> setManualCommunicationMode(ManualCommunicationMode mode) async {
    _autoCloudBootstrapFailed = false;
    state = state.copyWith(
      modeControlType: ModeControlType.manual,
      manualCommunicationMode: mode,
      userMode: mode.userMode,
    );
    await saveModeSettings();
    _recalculate();
  }

  Future<void> refreshConnectionState() async {
    // The low-level controller owns polling; this method exists as the public
    // Phase 13C API and is wired by callers through connectionModeProvider.
    _recalculate();
  }

  Future<void> handleConnectivityChanged() => refreshConnectionState();

  Future<void> handleAppResumed() => refreshConnectionState();

  void updateDetectedConnection(
    ConnectionModeState connection, {
    bool runSync = true,
  }) {
    state = state.copyWith(
      connectionState: _detectedFrom(connection.mode),
      backendReachable: connection.backendReachable,
      hasNetworkInterface: connection.hasNetworkInterface,
      lastCheckedAt: connection.lastCheckedAt,
      socketConnected: _socketService.isConnected,
    );
    _recalculate(runSync: runSync);
  }

  void updateAuthAccess(AuthAccessState accessState, UserModel? user) {
    _authAccessState = accessState;
    _user = user;
    _recalculate();
  }

  EffectiveMode calculateEffectiveMode() {
    if (state.userMode == UserMode.auto && _autoCloudBootstrapFailed) {
      return EffectiveMode.offline;
    }
    return _calculateEffectiveMode(state.userMode, state.connectionState);
  }

  String? getModeWarningMessage() {
    if (state.userMode == UserMode.offline && state.backendReachable) {
      return 'Offline Mode active. Internet is available, but TrailLink will use offline communication until you switch back or choose Auto.';
    }
    if (state.userMode == UserMode.online && !state.backendReachable) {
      return 'Online Mode selected, but the server is unreachable. Data will be queued locally.';
    }
    if (state.effectiveMode == EffectiveMode.hybridLimited) {
      return 'Connection is unstable. Data will be queued until a reliable path is available.';
    }
    return null;
  }

  bool shouldUseBackend() {
    return state.effectiveMode == EffectiveMode.online;
  }

  bool shouldUseOfflineTransport() {
    return state.effectiveMode == EffectiveMode.offline;
  }

  bool isManualOffline() => state.userMode == UserMode.offline;

  bool isManualOnline() => state.userMode == UserMode.online;

  void _recalculate({bool runSync = true}) {
    final previousEffectiveMode = state.effectiveMode;
    final effectiveMode = calculateEffectiveMode();
    final warning = _autoCloudBootstrapFailed
        ? 'Cloud setup failed. Offline Mode is available. TrailLink will retry cloud setup when the server is reachable.'
        : getModeWarningMessageFor(
            userMode: state.userMode,
            connectionState: state.connectionState,
            effectiveMode: effectiveMode,
            backendReachable: state.backendReachable,
          );
    state = state.copyWith(
      effectiveMode: effectiveMode,
      socketConnected: _socketService.isConnected,
      warningMessage: warning,
      clearWarning: warning == null,
      statusMessage: _statusFor(effectiveMode),
    );

    if (runSync &&
        previousEffectiveMode != EffectiveMode.online &&
        effectiveMode == EffectiveMode.online) {
      unawaited(_startOnlineServicesIfAllowed());
    }
  }

  Future<void> _startOnlineServicesIfAllowed() async {
    if (state.userMode == UserMode.offline) return;
    final ensureCloudReady = _ensureCloudReadyBeforeOnlineMode;
    if (_authAccessState != AuthAccessState.authenticatedOnline &&
        ensureCloudReady != null) {
      final result = await ensureCloudReady();
      if (!result.success) {
        if (state.userMode == UserMode.auto) {
          _autoCloudBootstrapFailed = true;
          _clearCloudSetupOverlay?.call();
          _recalculate(runSync: false);
        }
        return;
      }
      _autoCloudBootstrapFailed = false;
      if (result.user != null) {
        _authAccessState = AuthAccessState.authenticatedOnline;
        _user = result.user;
      }
    }

    if (_authAccessState != AuthAccessState.authenticatedOnline) return;
    if (!await _settings.getBool('auto_sync_when_online', true)) return;

    final user = _user;
    if (user != null) {
      unawaited(_socketService.connect());
    }
    if (await _settings.getBool('sync_offline_messages', true)) {
      unawaited(_messageSyncService.syncPendingMessages());
    }
    if (await _settings.getBool('sync_sos_history', true)) {
      unawaited(_emergencyRepository.syncPendingEmergencies());
    }
    if (await _settings.getBool('sync_location_history', true)) {
      unawaited(_locationSyncService.syncPendingLocations());
    }
  }

  static EffectiveMode decideEffectiveMode({
    required UserMode userMode,
    required DetectedConnectionState connectionState,
  }) {
    return _calculateEffectiveMode(userMode, connectionState);
  }

  static String? getModeWarningMessageFor({
    required UserMode userMode,
    required DetectedConnectionState connectionState,
    required EffectiveMode effectiveMode,
    required bool backendReachable,
  }) {
    if (userMode == UserMode.offline && backendReachable) {
      return 'Offline Mode active. Internet is available, but TrailLink will use offline communication until you switch back or choose Auto.';
    }
    if (userMode == UserMode.online && !backendReachable) {
      return 'Online Mode selected, but the server is unreachable. Data will be queued locally.';
    }
    if (effectiveMode == EffectiveMode.hybridLimited ||
        connectionState == DetectedConnectionState.unstable) {
      return 'Connection is unstable. Data will be queued until a reliable path is available.';
    }
    return null;
  }

  static EffectiveMode _calculateEffectiveMode(
    UserMode userMode,
    DetectedConnectionState connectionState,
  ) {
    return switch (userMode) {
      UserMode.auto => switch (connectionState) {
          DetectedConnectionState.backendOnline => EffectiveMode.online,
          DetectedConnectionState.backendOffline => EffectiveMode.offline,
          DetectedConnectionState.reconnecting => EffectiveMode.hybridLimited,
          DetectedConnectionState.unstable => EffectiveMode.hybridLimited,
        },
      UserMode.online => EffectiveMode.online,
      UserMode.offline => EffectiveMode.offline,
    };
  }

  DetectedConnectionState _detectedFrom(AppConnectionMode mode) {
    return switch (mode) {
      AppConnectionMode.online => DetectedConnectionState.backendOnline,
      AppConnectionMode.offline => DetectedConnectionState.backendOffline,
      AppConnectionMode.reconnecting => DetectedConnectionState.reconnecting,
      AppConnectionMode.unstable => DetectedConnectionState.unstable,
    };
  }

  String _statusFor(EffectiveMode mode) {
    return switch (mode) {
      EffectiveMode.online => 'Online Mode - Cloud communication available.',
      EffectiveMode.offline =>
        state.userMode == UserMode.offline && state.backendReachable
            ? 'Offline Mode - Internet is available, but cloud sync is paused.'
            : 'Offline Mode - Local communication active.',
      EffectiveMode.hybridLimited =>
        'Connection unstable - TrailLink will save locally first.',
    };
  }

  UserMode _parseUserMode(String value) {
    return UserMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => UserMode.auto,
    );
  }

  ModeControlType _parseModeControlType(String value) {
    return ModeControlType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ModeControlType.auto,
    );
  }

  ManualCommunicationMode _parseManualMode(String value) {
    return ManualCommunicationMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ManualCommunicationMode.offline,
    );
  }
}
