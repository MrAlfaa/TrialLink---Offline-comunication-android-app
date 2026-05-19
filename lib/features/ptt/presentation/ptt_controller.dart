import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/connectivity/app_connection_mode.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../core/settings/settings_service.dart';
import '../../auth/data/models/user_model.dart';
import '../../chat/data/socket_service.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../data/models/live_radio_session_model.dart';
import '../data/models/ptt_floor_state.dart';
import '../data/models/voice_note_model.dart';
import '../data/ptt_repository.dart';

enum PttVoiceMode { voiceNote, liveRadio }

bool shouldRefreshPttForOfflineNotice(String? notice) {
  final value = (notice ?? '').toLowerCase();
  return value.contains('voice note received') ||
      value.contains('voice note delivered') ||
      value.contains('is speaking') ||
      value.contains('ptt channel is free') ||
      value.contains('another user is speaking') ||
      value.contains('live audio received') ||
      value.contains('live radio ended') ||
      value.contains('is live');
}

class PttSessionArgs {
  const PttSessionArgs({
    required this.currentUser,
    this.groupId,
    this.offlineChannel,
  });

  final UserModel currentUser;
  final String? groupId;
  final OfflineChannelModel? offlineChannel;

  bool get isOnlineGroup => groupId != null;
  String get contextType => isOnlineGroup ? 'online_group' : 'offline_channel';
  String get contextId => groupId ?? offlineChannel!.channelId;
  String get title => isOnlineGroup
      ? 'Group Walkie-Talkie'
      : offlineChannel?.channelName ?? 'Offline Walkie-Talkie';

  @override
  bool operator ==(Object other) {
    return other is PttSessionArgs &&
        other.currentUser.id == currentUser.id &&
        other.groupId == groupId &&
        other.offlineChannel?.channelId == offlineChannel?.channelId;
  }

  @override
  int get hashCode =>
      Object.hash(currentUser.id, groupId, offlineChannel?.channelId);
}

class PttState {
  const PttState({
    this.notes = const [],
    this.liveSessions = const [],
    this.floor,
    this.voiceMode = PttVoiceMode.voiceNote,
    this.isLoading = true,
    this.isRecording = false,
    this.isLiveStreaming = false,
    this.isWaitingForFloor = false,
    this.recordingSeconds = 0,
    this.errorMessage,
    this.infoMessage,
  });

  final List<VoiceNoteModel> notes;
  final List<LiveRadioSessionModel> liveSessions;
  final PttFloorState? floor;
  final PttVoiceMode voiceMode;
  final bool isLoading;
  final bool isRecording;
  final bool isLiveStreaming;
  final bool isWaitingForFloor;
  final int recordingSeconds;
  final String? errorMessage;
  final String? infoMessage;

  PttState copyWith({
    List<VoiceNoteModel>? notes,
    List<LiveRadioSessionModel>? liveSessions,
    PttFloorState? floor,
    PttVoiceMode? voiceMode,
    bool? isLoading,
    bool? isRecording,
    bool? isLiveStreaming,
    bool? isWaitingForFloor,
    int? recordingSeconds,
    String? errorMessage,
    String? infoMessage,
    bool clearMessages = false,
  }) {
    return PttState(
      notes: notes ?? this.notes,
      liveSessions: liveSessions ?? this.liveSessions,
      floor: floor ?? this.floor,
      voiceMode: voiceMode ?? this.voiceMode,
      isLoading: isLoading ?? this.isLoading,
      isRecording: isRecording ?? this.isRecording,
      isLiveStreaming: isLiveStreaming ?? this.isLiveStreaming,
      isWaitingForFloor: isWaitingForFloor ?? this.isWaitingForFloor,
      recordingSeconds: recordingSeconds ?? this.recordingSeconds,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      infoMessage: clearMessages ? null : infoMessage ?? this.infoMessage,
    );
  }
}

class PttController extends StateNotifier<PttState> {
  PttController({
    required this.args,
    required PttRepository repository,
    required SocketService socketService,
    required AppConnectionMode initialMode,
    required EffectiveMode initialEffectiveMode,
  })  : _repository = repository,
        _socketService = socketService,
        _mode = initialMode,
        _effectiveMode = initialEffectiveMode,
        super(const PttState()) {
    _init();
  }

  final PttSessionArgs args;
  final PttRepository _repository;
  final SocketService _socketService;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Uuid _uuid = const Uuid();
  AppConnectionMode _mode;
  EffectiveMode _effectiveMode;
  Timer? _recordingTimer;

  int get _maxRecordingSeconds => args.isOnlineGroup ? 30 : 15;

  Future<void> _init() async {
    _subscriptions
      ..add(_socketService.pttGrantedStream.listen(_onPttGranted))
      ..add(_socketService.pttDeniedStream.listen(_onPttDenied))
      ..add(_socketService.pttSpeakerChangedStream.listen(_onSpeakerChanged))
      ..add(_socketService.pttSpeakerReleasedStream.listen(_onSpeakerReleased))
      ..add(_socketService.voiceNoteStream.listen(_onVoiceNoteReceived))
      ..add(_repository.liveRadioFailureStream.listen(_onLiveRadioFailure));

    if (args.isOnlineGroup && _mode == AppConnectionMode.online) {
      await _socketService.connect();
      _socketService.joinGroup(args.groupId!);
    }
    await refresh();
  }

  Future<void> refresh() async {
    await _repository.configureFloorTimeout();
    final notes = await _repository.loadNotes(
      groupId: args.groupId,
      offlineChannelId: args.offlineChannel?.channelId,
    );
    final liveSessions = args.offlineChannel == null
        ? const <LiveRadioSessionModel>[]
        : await _repository.loadLiveRadioSessions(
            offlineChannelId: args.offlineChannel!.channelId,
          );
    if (!mounted) return;
    state = state.copyWith(
      notes: notes,
      liveSessions: liveSessions,
      isLoading: false,
      floor: _repository.floorController.stateFor(
        contextType: args.contextType,
        contextId: args.contextId,
        currentUserId: args.currentUser.id,
      ),
    );
  }

  Future<void> selectVoiceMode(PttVoiceMode mode) async {
    if (args.isOnlineGroup && mode == PttVoiceMode.liveRadio) {
      state = state.copyWith(
        voiceMode: PttVoiceMode.liveRadio,
        errorMessage: 'Live Radio is offline-only.',
      );
      return;
    }
    if (state.isRecording || state.isLiveStreaming || state.isWaitingForFloor) {
      return;
    }
    state = state.copyWith(voiceMode: mode, clearMessages: true);
    if (mode == PttVoiceMode.liveRadio) {
      final result = await _repository.evaluateLiveRadio(
        effectiveMode: _effectiveMode,
        channel: args.offlineChannel,
      );
      if (!result.allowed) {
        state = state.copyWith(
          voiceMode: PttVoiceMode.liveRadio,
          infoMessage: result.reason,
        );
      }
    }
  }

  Future<void> pressToTalk() async {
    if (state.isRecording || state.isLiveStreaming || state.isWaitingForFloor) {
      return;
    }
    if (state.voiceMode == PttVoiceMode.liveRadio) {
      await _pressLiveRadio();
      return;
    }
    state = state.copyWith(isWaitingForFloor: true, clearMessages: true);
    try {
      if (args.isOnlineGroup) {
        if (!_socketService.isConnected) {
          await _socketService.connect();
          _socketService.joinGroup(args.groupId!);
        }
        _socketService.requestPttFloor(
          groupId: args.groupId!,
          clientRequestId: _uuid.v4(),
        );
      } else {
        final channel = args.offlineChannel;
        if (channel == null) {
          throw StateError('Select an offline channel first.');
        }
        final granted = await _repository.requestOfflineFloor(
          channel: channel,
          user: args.currentUser,
        );
        if (!granted) {
          state = state.copyWith(
            isWaitingForFloor: false,
            errorMessage: 'Another user is speaking.',
          );
          return;
        }
        await _startRecording();
      }
    } catch (error) {
      state = state.copyWith(
        isWaitingForFloor: false,
        errorMessage: _friendlyPttError(error),
      );
    }
  }

  Future<void> releaseToSend() async {
    if (state.isLiveStreaming) {
      await _releaseLiveRadio();
      return;
    }
    if (!state.isRecording) {
      state = state.copyWith(isWaitingForFloor: false);
      return;
    }
    _recordingTimer?.cancel();
    state = state.copyWith(isRecording: false, isWaitingForFloor: false);
    try {
      if (args.isOnlineGroup) {
        _socketService.releasePttFloor(groupId: args.groupId!);
      } else if (args.offlineChannel != null) {
        await _repository.releaseOfflineFloor(
          channel: args.offlineChannel!,
          user: args.currentUser,
        );
      }

      final note = await _repository.stopAndCreateNote(
        user: args.currentUser,
        groupId: args.groupId,
        channel: args.offlineChannel,
        deliveryMode: args.isOnlineGroup ? 'online' : 'offline',
      );
      if (note == null) {
        state = state.copyWith(infoMessage: 'Recording was not saved.');
        return;
      }
      await refresh();
      if (args.isOnlineGroup) {
        await _repository.sendOnline(
          groupId: args.groupId!,
          user: args.currentUser,
          note: note,
        );
      } else {
        await _repository.sendOffline(
          channel: args.offlineChannel!,
          user: args.currentUser,
          note: note,
        );
      }
      await refresh();
      state = state.copyWith(infoMessage: 'Voice note sent.');
    } catch (error) {
      await refresh();
      state = state.copyWith(errorMessage: _friendlyPttError(error));
    }
  }

  Future<void> play(VoiceNoteModel note) async {
    try {
      await _repository.play(note);
    } catch (error) {
      state = state.copyWith(errorMessage: _friendlyPttError(error));
    }
  }

  void onConnectionModeChanged(AppConnectionMode mode) {
    _mode = mode;
  }

  void onEffectiveModeChanged(EffectiveMode mode) {
    _effectiveMode = mode;
    if (mode != EffectiveMode.offline && state.isLiveStreaming) {
      unawaited(_releaseLiveRadio(status: 'interrupted'));
    }
  }

  Future<void> interruptForEmergency() async {
    if (state.isLiveStreaming && args.offlineChannel != null) {
      await _releaseLiveRadio(status: 'interrupted');
    }
  }

  Future<void> _pressLiveRadio() async {
    state = state.copyWith(isWaitingForFloor: true, clearMessages: true);
    final result = await _repository.evaluateLiveRadio(
      effectiveMode: _effectiveMode,
      channel: args.offlineChannel,
    );
    if (!result.allowed) {
      state = state.copyWith(
        isWaitingForFloor: false,
        voiceMode: PttVoiceMode.liveRadio,
        infoMessage: result.reason,
      );
      return;
    }
    try {
      await _repository.startLiveRadio(
        channel: args.offlineChannel!,
        user: args.currentUser,
      );
      state = state.copyWith(
        isWaitingForFloor: false,
        isLiveStreaming: true,
        recordingSeconds: 0,
        infoMessage: 'Streaming live...',
        floor: _repository.floorController.stateFor(
          contextType: args.contextType,
          contextId: args.contextId,
          currentUserId: args.currentUser.id,
        ),
      );
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final next = state.recordingSeconds + 1;
        state = state.copyWith(recordingSeconds: next);
      });
    } catch (error) {
      state = state.copyWith(
        isWaitingForFloor: false,
        isLiveStreaming: false,
        voiceMode: PttVoiceMode.liveRadio,
        errorMessage: _friendlyPttError(error),
      );
    }
  }

  Future<void> _releaseLiveRadio({String status = 'ended'}) async {
    _recordingTimer?.cancel();
    state = state.copyWith(isLiveStreaming: false, isWaitingForFloor: false);
    try {
      if (args.offlineChannel != null) {
        await _repository.endLiveRadio(
          channel: args.offlineChannel!,
          user: args.currentUser,
          status: status,
        );
      }
      await refresh();
      state = state.copyWith(infoMessage: 'Live Radio ended.');
    } catch (error) {
      await refresh();
      state = state.copyWith(errorMessage: _friendlyPttError(error));
    }
  }

  Future<void> _startRecording() async {
    await _repository.startRecording();
    state = state.copyWith(
      isRecording: true,
      isWaitingForFloor: false,
      recordingSeconds: 0,
      floor: _repository.floorController.stateFor(
        contextType: args.contextType,
        contextId: args.contextId,
        currentUserId: args.currentUser.id,
      ),
    );
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.recordingSeconds + 1;
      state = state.copyWith(recordingSeconds: next);
      if (next >= _maxRecordingSeconds) {
        releaseToSend();
      }
    });
  }

  Future<void> _onPttGranted(Map<String, dynamic> data) async {
    if (data['groupId']?.toString() != args.groupId) return;
    await _repository.floorController.requestLocalFloor(
      contextType: args.contextType,
      contextId: args.contextId,
      user: args.currentUser,
    );
    await _startRecording();
  }

  void _onPttDenied(Map<String, dynamic> data) {
    if (data['groupId']?.toString() != args.groupId) return;
    state = state.copyWith(
      isWaitingForFloor: false,
      errorMessage: data['message']?.toString() ?? 'Another user is speaking.',
    );
  }

  Future<void> _onSpeakerChanged(Map<String, dynamic> data) async {
    if (data['groupId']?.toString() != args.groupId) return;
    final speakerId = data['speakerId']?.toString() ?? '';
    final speakerName = data['speakerName']?.toString() ?? 'A teammate';
    if (speakerId != args.currentUser.id) {
      await _repository.floorController.setRemoteSpeaker(
        contextType: args.contextType,
        contextId: args.contextId,
        speakerId: speakerId,
        speakerName: speakerName,
      );
    }
    state = state.copyWith(
      floor: _repository.floorController.stateFor(
        contextType: args.contextType,
        contextId: args.contextId,
        currentUserId: args.currentUser.id,
      ),
      infoMessage: '$speakerName is speaking.',
    );
  }

  Future<void> _onSpeakerReleased(Map<String, dynamic> data) async {
    if (data['groupId']?.toString() != args.groupId) return;
    await _repository.floorController.release(
      contextType: args.contextType,
      contextId: args.contextId,
      speakerId: data['speakerId']?.toString() ?? '',
      speakerName: data['speakerName']?.toString() ?? 'TrailLink User',
    );
    state = state.copyWith(infoMessage: 'Channel free.');
  }

  Future<void> _onVoiceNoteReceived(Map<String, dynamic> data) async {
    if (data['groupId']?.toString() != args.groupId) return;
    await _repository.upsertRemoteVoiceNote(
      data,
      currentUserId: args.currentUser.id,
    );
    await refresh();
  }

  Future<void> _onLiveRadioFailure(String message) async {
    _recordingTimer?.cancel();
    state = state.copyWith(
      isLiveStreaming: false,
      isWaitingForFloor: false,
      voiceMode: PttVoiceMode.liveRadio,
      errorMessage: message,
    );
    await refresh();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (state.isLiveStreaming && args.offlineChannel != null) {
      unawaited(
        _repository.endLiveRadio(
          channel: args.offlineChannel!,
          user: args.currentUser,
          status: 'interrupted',
        ),
      );
    } else {
      unawaited(_repository.stopAllAudio());
    }
    if (args.isOnlineGroup) _socketService.leaveGroup(args.groupId!);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

String _friendlyPttError(Object error) {
  return error
      .toString()
      .replaceFirst(RegExp(r'^(Bad state|Exception|StateError):\s*'), '')
      .trim();
}

final pttRepositoryProvider = Provider.autoDispose<PttRepository>((ref) {
  final repository = PttRepository(
    nearbyRepository: ref.watch(nearbyRepositoryProvider),
    settings: ref.read(settingsServiceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final pttControllerProvider = StateNotifierProvider.autoDispose
    .family<PttController, PttState, PttSessionArgs>(
  (ref, args) {
    final repository = ref.watch(pttRepositoryProvider);
    final controller = PttController(
      args: args,
      repository: repository,
      socketService: ref.read(socketServiceProvider),
      initialMode: ref.read(modeControllerProvider).compatibilityConnectionMode,
      initialEffectiveMode: ref.read(modeControllerProvider).effectiveMode,
    );
    ref.listen(modeControllerProvider, (_, next) {
      controller.onConnectionModeChanged(next.compatibilityConnectionMode);
      controller.onEffectiveModeChanged(next.effectiveMode);
    });
    return controller;
  },
);
