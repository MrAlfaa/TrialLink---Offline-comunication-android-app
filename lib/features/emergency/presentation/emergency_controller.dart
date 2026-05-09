import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/app_connection_mode.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/settings/settings_service.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/socket_service.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../offline_channel/data/offline_channel_repository.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../data/emergency_repository.dart';
import '../data/models/emergency_event_model.dart';

class EmergencyContextArgs {
  const EmergencyContextArgs({
    this.groupId,
    this.offlineChannelId,
  });

  final String? groupId;
  final String? offlineChannelId;

  @override
  bool operator ==(Object other) {
    return other is EmergencyContextArgs &&
        other.groupId == groupId &&
        other.offlineChannelId == offlineChannelId;
  }

  @override
  int get hashCode => Object.hash(groupId, offlineChannelId);
}

class EmergencyState {
  const EmergencyState({
    this.events = const [],
    this.latestEvent,
    this.mode = AppConnectionMode.reconnecting,
    this.isLoading = true,
    this.isSending = false,
    this.errorMessage,
    this.infoMessage,
  });

  final List<EmergencyEventModel> events;
  final EmergencyEventModel? latestEvent;
  final AppConnectionMode mode;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final String? infoMessage;

  EmergencyState copyWith({
    List<EmergencyEventModel>? events,
    EmergencyEventModel? latestEvent,
    AppConnectionMode? mode,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
  }) {
    return EmergencyState(
      events: events ?? this.events,
      latestEvent: latestEvent ?? this.latestEvent,
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearMessages ? null : infoMessage ?? this.infoMessage,
    );
  }
}

class EmergencyController extends StateNotifier<EmergencyState> {
  EmergencyController({
    required this.args,
    required UserModel? user,
    required AppConnectionMode mode,
    required EmergencyRepository repository,
    required OfflineChannelRepository channelRepository,
    required SocketService socketService,
    required SettingsService settings,
  })  : _user = user,
        _repository = repository,
        _channelRepository = channelRepository,
        _socketService = socketService,
        _settings = settings,
        super(EmergencyState(mode: mode)) {
    _init();
  }

  final EmergencyContextArgs args;
  final UserModel? _user;
  final EmergencyRepository _repository;
  final OfflineChannelRepository _channelRepository;
  final SocketService _socketService;
  final SettingsService _settings;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Future<void> _init() async {
    _subscriptions
      ..add(_socketService.emergencyStream.listen(_onOnlineEmergency))
      ..add(_socketService.emergencyAckStream.listen(_onOnlineAck));
    if (args.groupId != null) {
      unawaited(_socketService.connect().then((_) {
        _socketService.joinGroup(args.groupId!);
      }));
    }
    await refresh();
  }

  Future<void> refresh() async {
    final events = await _repository.history(
      groupId: args.groupId,
      offlineChannelId: args.offlineChannelId,
    );
    final latest = await _repository.latestEvent();
    if (!mounted) return;
    state = state.copyWith(
      events: events,
      latestEvent: latest,
      isLoading: false,
      clearMessages: true,
    );
  }

  Future<void> triggerSos(String message) async {
    final user = _user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Create your TrailLink profile before sending SOS.',
      );
      return;
    }
    final offlineSosEnabled =
        await _settings.getBool('enable_offline_sos', true) &&
            await _settings.getBool('offline_sos_enabled', true);
    if (!offlineSosEnabled) {
      state =
          state.copyWith(errorMessage: 'Offline SOS is disabled in Settings.');
      return;
    }
    final attachLocation =
        await _settings.getBool('attach_location_to_sos', true);
    final useLastKnown =
        await _settings.getBool('use_last_known_location_for_sos', true);

    state = state.copyWith(isSending: true, clearMessages: true);
    try {
      final channel = args.offlineChannelId == null
          ? await _channelRepository.getActiveChannel()
          : await _channelRepository.getChannel(args.offlineChannelId!);
      final event = await _repository.triggerSos(
        user: user,
        groupId: args.groupId,
        channel: channel,
        mode: state.mode,
        message: message,
        attachLocation: attachLocation,
        useLastKnownLocation: useLastKnown,
      );
      await refresh();
      if (!mounted) return;
      state = state.copyWith(
        latestEvent: event,
        isSending: false,
        infoMessage: attachLocation
            ? 'Emergency alert sent or queued.'
            : 'Emergency alert sent without location.',
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(isSending: false, errorMessage: error.toString());
    }
  }

  Future<void> acknowledge(EmergencyEventModel event) async {
    if (event.groupId == null || event.serverEventId == null) return;
    await _repository.acknowledgeOnline(
      groupId: event.groupId!,
      eventId: event.serverEventId!,
    );
    await refresh();
  }

  Future<void> _onOnlineEmergency(Map<String, dynamic> data) async {
    final event = EmergencyEventModel.fromApiJson(data);
    await _repository.saveRemoteEvent(event);
    await refresh();
    if (!mounted) return;
    state = state.copyWith(
      latestEvent: event,
      infoMessage: 'Emergency alert received.',
    );
  }

  Future<void> _onOnlineAck(Map<String, dynamic> data) async {
    await refresh();
    if (!mounted) return;
    state = state.copyWith(infoMessage: 'Emergency alert acknowledged.');
  }

  void onModeChanged(AppConnectionMode mode) {
    if (!mounted) return;
    state = state.copyWith(mode: mode);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return EmergencyRepository(
    nearbyRepository: ref.watch(nearbyRepositoryProvider),
  );
});

final emergencyControllerProvider = StateNotifierProvider.autoDispose
    .family<EmergencyController, EmergencyState, EmergencyContextArgs>(
  (ref, args) {
    final controller = EmergencyController(
      args: args,
      user: _currentEmergencyUser(ref),
      mode: ref.read(modeControllerProvider).compatibilityConnectionMode,
      repository: ref.read(emergencyRepositoryProvider),
      channelRepository: ref.read(offlineChannelRepositoryProvider),
      socketService: ref.read(socketServiceProvider),
      settings: ref.read(settingsServiceProvider),
    );
    ref.listen(modeControllerProvider, (_, next) {
      controller.onModeChanged(next.compatibilityConnectionMode);
    });
    return controller;
  },
);

UserModel? _currentEmergencyUser(Ref ref) {
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
