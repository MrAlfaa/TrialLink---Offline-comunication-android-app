import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/app_connection_mode.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/settings/settings_service.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_channel/data/offline_channel_repository.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../data/location_repository.dart';
import '../data/models/location_update_model.dart';
import '../data/models/teammate_location_model.dart';

class LocationContextArgs {
  const LocationContextArgs({
    this.groupId,
    this.offlineChannelId,
  });

  final String? groupId;
  final String? offlineChannelId;

  @override
  bool operator ==(Object other) {
    return other is LocationContextArgs &&
        other.groupId == groupId &&
        other.offlineChannelId == offlineChannelId;
  }

  @override
  int get hashCode => Object.hash(groupId, offlineChannelId);
}

class LocationState {
  const LocationState({
    this.currentLocation,
    this.teammates = const [],
    this.isLoading = true,
    this.isSharing = false,
    this.errorMessage,
    this.infoMessage,
  });

  final LocationUpdateModel? currentLocation;
  final List<TeammateLocationModel> teammates;
  final bool isLoading;
  final bool isSharing;
  final String? errorMessage;
  final String? infoMessage;

  LocationState copyWith({
    LocationUpdateModel? currentLocation,
    List<TeammateLocationModel>? teammates,
    bool? isLoading,
    bool? isSharing,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
  }) {
    return LocationState(
      currentLocation: currentLocation ?? this.currentLocation,
      teammates: teammates ?? this.teammates,
      isLoading: isLoading ?? this.isLoading,
      isSharing: isSharing ?? this.isSharing,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearMessages ? null : infoMessage ?? this.infoMessage,
    );
  }
}

class LocationController extends StateNotifier<LocationState> {
  LocationController({
    required this.args,
    required UserModel? user,
    required AppConnectionMode mode,
    required LocationRepository repository,
    required OfflineChannelRepository channelRepository,
    required SettingsService settings,
  })  : _user = user,
        _mode = mode,
        _repository = repository,
        _channelRepository = channelRepository,
        _settings = settings,
        super(const LocationState()) {
    refresh();
  }

  final LocationContextArgs args;
  final UserModel? _user;
  AppConnectionMode _mode;
  final LocationRepository _repository;
  final OfflineChannelRepository _channelRepository;
  final SettingsService _settings;

  Future<void> refresh() async {
    final user = _user;
    if (user == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Create your TrailLink profile before using location.',
      );
      return;
    }

    final own = await _repository.latestOwnLocation(user.id);
    var teammates = await _repository.loadTeammates(
      groupId: args.groupId,
      offlineChannelId: args.offlineChannelId,
    );
    if (_mode == AppConnectionMode.online && args.groupId != null) {
      try {
        teammates = await _repository.refreshBackendTeammates(args.groupId!);
      } catch (_) {
        // Cached teammate locations remain available offline.
      }
    }
    if (!mounted) return;
    state = state.copyWith(
      currentLocation: own,
      teammates: teammates,
      isLoading: false,
      clearMessages: true,
    );
  }

  Future<void> getCurrentLocation() async {
    final user = _user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Create your TrailLink profile before sharing.',
      );
      return;
    }
    state = state.copyWith(isSharing: true, clearMessages: true);
    try {
      final location = await _repository.shareLocation(
        user: user,
        groupId: null,
        channel: null,
        online: false,
      );
      if (!mounted) return;
      state = state.copyWith(
        currentLocation: location,
        isSharing: false,
        infoMessage: 'Current GPS location captured.',
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isSharing: false, errorMessage: error.toString());
    }
  }

  Future<void> shareLocation() async {
    final user = _user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Create your TrailLink profile before sharing.',
      );
      return;
    }
    final sharingEnabled =
        await _settings.getBool('enable_offline_location_share', true) &&
            await _settings.getBool('offline_location_share_enabled', true);
    if (!sharingEnabled) {
      state = state.copyWith(
        infoMessage:
            'Location sharing is disabled. Cached locations may still be visible.',
      );
      return;
    }
    state = state.copyWith(isSharing: true, clearMessages: true);
    try {
      final resolvedChannel = await _resolveOfflineChannelForShare();
      final location = await _repository.shareLocation(
        user: user,
        groupId: args.groupId,
        channel: resolvedChannel,
        online: _mode == AppConnectionMode.online,
      );
      final teammates = await _repository.loadTeammates(
        groupId: args.groupId,
        offlineChannelId: args.offlineChannelId ?? resolvedChannel?.channelId,
      );
      if (!mounted) return;
      state = state.copyWith(
        currentLocation: location,
        teammates: teammates,
        isSharing: false,
        infoMessage: 'Location saved and shared when a path is available.',
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isSharing: false, errorMessage: error.toString());
    }
  }

  void onModeChanged(AppConnectionMode mode) {
    _mode = mode;
  }

  Future<OfflineChannelModel?> _resolveOfflineChannelForShare() async {
    if (args.offlineChannelId != null) {
      return _channelRepository.getChannel(args.offlineChannelId!);
    }
    if (args.groupId != null && _mode == AppConnectionMode.online) {
      return null;
    }
    return await _channelRepository.getActiveChannel();
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(
    nearbyRepository: ref.watch(nearbyRepositoryProvider),
  );
});

final locationControllerProvider = StateNotifierProvider.autoDispose
    .family<LocationController, LocationState, LocationContextArgs>(
  (ref, args) {
    final controller = LocationController(
      args: args,
      user: _currentLocationUser(ref),
      mode: ref.read(modeControllerProvider).compatibilityConnectionMode,
      repository: ref.read(locationRepositoryProvider),
      channelRepository: ref.read(offlineChannelRepositoryProvider),
      settings: ref.read(settingsServiceProvider),
    );
    ref.listen(modeControllerProvider, (_, next) {
      controller.onModeChanged(next.compatibilityConnectionMode);
    });
    return controller;
  },
);

UserModel? _currentLocationUser(Ref ref) {
  final authUser = ref.read(authControllerProvider).user;
  if (authUser != null) return authUser;
  try {
    return CurrentUserActor.fromAuthAccess(
      ref.read(authAccessControllerProvider),
    ).toUserModel();
  } catch (_) {
    return null;
  }
}
