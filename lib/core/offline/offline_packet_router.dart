import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/bridge/data/bridge_engine.dart';
import '../../features/connectivity_intelligence/data/connectivity_metrics_recorder.dart';
import '../../features/emergency/data/emergency_repository.dart';
import '../../features/emergency/data/models/emergency_event_model.dart';
import '../../features/location/data/location_repository.dart';
import '../../features/nearby/presentation/nearby_controller.dart';
import '../../features/offline_channel/data/offline_channel_repository.dart';
import '../../features/offline_channel/presentation/offline_channel_controller.dart';
import '../../features/offline_chat/data/models/offline_packet_model.dart';
import '../../features/offline_chat/data/offline_chat_repository.dart';
import '../../features/ptt/data/ptt_repository.dart';
import '../identity/auth_access_controller.dart';
import '../identity/current_user_actor.dart';
import '../identity/local_identity_repository.dart';

class OfflinePacketRouterState {
  const OfflinePacketRouterState({
    this.lastNotice,
    this.lastEmergencyNotice,
    this.lastEmergencyAlert,
    this.lastHandledAt,
  });

  final String? lastNotice;
  final String? lastEmergencyNotice;
  final ReceivedSosAlert? lastEmergencyAlert;
  final DateTime? lastHandledAt;

  OfflinePacketRouterState copyWith({
    String? lastNotice,
    String? lastEmergencyNotice,
    ReceivedSosAlert? lastEmergencyAlert,
    bool clearEmergency = false,
  }) {
    return OfflinePacketRouterState(
      lastNotice: lastNotice ?? this.lastNotice,
      lastEmergencyNotice: clearEmergency
          ? null
          : lastEmergencyNotice ?? this.lastEmergencyNotice,
      lastEmergencyAlert:
          clearEmergency ? null : lastEmergencyAlert ?? this.lastEmergencyAlert,
      lastHandledAt: DateTime.now(),
    );
  }
}

class ReceivedSosAlert {
  const ReceivedSosAlert({
    required this.event,
    required this.packet,
    required this.senderName,
    required this.channelCode,
    required this.receivedAt,
  });

  final EmergencyEventModel event;
  final OfflinePacketModel packet;
  final String senderName;
  final String channelCode;
  final DateTime receivedAt;
}

class OfflinePacketRouter extends StateNotifier<OfflinePacketRouterState> {
  static const channelEndedNotice =
      'This channel was ended by the owner. Chat history is read-only.';

  OfflinePacketRouter({
    required OfflineChannelRepository channelRepository,
    required OfflineChatRepository chatRepository,
    required EmergencyRepository emergencyRepository,
    required LocationRepository locationRepository,
    required PttRepository pttRepository,
    ConnectivityMetricsRecorder? metricsRecorder,
    required Stream<String> packetStream,
    CurrentUserActor? currentActor,
    BridgeEngine? bridgeEngine,
  })  : _channelRepository = channelRepository,
        _chatRepository = chatRepository,
        _emergencyRepository = emergencyRepository,
        _locationRepository = locationRepository,
        _pttRepository = pttRepository,
        _metricsRecorder = metricsRecorder ?? ConnectivityMetricsRecorder(),
        _currentActor = currentActor,
        _bridgeEngine = bridgeEngine,
        super(const OfflinePacketRouterState()) {
    _subscription = packetStream.listen(_handlePacket);
  }

  final OfflineChannelRepository _channelRepository;
  final OfflineChatRepository _chatRepository;
  final EmergencyRepository _emergencyRepository;
  final LocationRepository _locationRepository;
  final PttRepository _pttRepository;
  final ConnectivityMetricsRecorder _metricsRecorder;
  final BridgeEngine? _bridgeEngine;
  CurrentUserActor? _currentActor;
  late final StreamSubscription<String> _subscription;

  void setCurrentUser(UserModel? user) {
    _currentActor = user == null ? null : CurrentUserActor.fromUserModel(user);
  }

  void setCurrentActor(CurrentUserActor? actor) {
    _currentActor = actor;
    _debugRouter(
      'actor_update',
      reason: actor == null ? 'no-current-actor' : actor.identityType,
    );
  }

  void clearEmergencyNotice() {
    state = state.copyWith(clearEmergency: true);
  }

  Future<void> acknowledgeLatestSos() async {
    final actor = _currentActor;
    final alert = state.lastEmergencyAlert;
    if (actor == null || alert == null) return;
    final activeChannel = await _channelRepository.getActiveChannel();
    if (activeChannel == null) return;
    await _emergencyRepository.sendOfflineSosAck(
      receivedPacket: alert.packet,
      activeChannel: activeChannel,
      currentUser: actor.toUserModel(),
    );
    state = state.copyWith(
      lastNotice: 'Emergency alert acknowledged.',
      clearEmergency: true,
    );
  }

  Future<void> _handlePacket(String packetJson) async {
    final actor = _currentActor;
    if (actor == null) {
      _debugRouter(
        'drop',
        packetJson: packetJson,
        reason: 'no-current-actor',
      );
      state = state.copyWith(
        lastNotice: 'Offline packet ignored. No local identity.',
      );
      return;
    }

    OfflinePacketModel packet;
    try {
      packet = OfflinePacketModel.fromJsonString(packetJson);
      _debugRouter('rx', packet: packet, bytes: packetJson.length);
    } catch (error) {
      _debugRouter(
        'drop',
        packetJson: packetJson,
        reason: 'invalid-json: $error',
      );
      state = state.copyWith(lastNotice: 'Invalid offline packet ignored.');
      return;
    }

    if (packet.packetType == 'channel_status_update') {
      final result = await _channelRepository.handleChannelStatusPacket(
        packet: packet,
        currentUser: actor,
      );
      state = state.copyWith(lastNotice: result);
      return;
    }

    final activeChannel = await _channelRepository.getActiveChannel();
    if (activeChannel == null) {
      _debugRouter(
        'drop',
        packet: packet,
        bytes: packetJson.length,
        reason: 'no-active-channel',
      );
      state = state.copyWith(
          lastNotice: 'Offline packet ignored. No active channel.');
      return;
    }

    String result;
    switch (packet.packetType) {
      case 'text':
      case 'ack':
        result = (await _chatRepository.handleIncomingPacket(
          packetJson: packetJson,
          activeChannel: activeChannel,
          currentUser: actor,
        ))
            .message;
        if (packet.packetType == 'text') {
          await _tryBridge(packet);
        }
        break;
      case 'sos':
      case 'sos_ack':
        final emergencyResult =
            await _emergencyRepository.handleIncomingSosPacket(
          packet: packet,
          activeChannel: activeChannel,
          currentUser: actor.toUserModel(),
        );
        await _tryBridge(packet);
        result = emergencyResult.message;
        state = state.copyWith(
          lastNotice: result,
          lastEmergencyNotice:
              packet.packetType == 'sos' ? 'Emergency alert received.' : null,
          lastEmergencyAlert: packet.packetType == 'sos' &&
                  emergencyResult.event != null &&
                  emergencyResult.receivedPacket != null
              ? ReceivedSosAlert(
                  event: emergencyResult.event!,
                  packet: emergencyResult.receivedPacket!,
                  senderName: emergencyResult.senderName ?? packet.senderName,
                  channelCode: activeChannel.channelCode,
                  receivedAt: DateTime.now(),
                )
              : null,
        );
        return;
      case 'location':
        result = await _locationRepository.handleIncomingPacket(
          packet: packet,
          activeChannel: activeChannel,
          currentUser: actor.toUserModel(),
        );
        await _tryBridge(packet);
        break;
      case 'heartbeat':
        await _metricsRecorder.recordHeartbeat(
          endpointId: packet.senderId,
          userId: packet.senderId,
          displayName: packet.senderName,
          channelId: packet.channelId,
          channelCode: packet.channelCode,
        );
        result = 'Heartbeat received.';
        break;
      case 'channel_status_update':
        result = await _channelRepository.handleChannelStatusPacket(
          packet: packet,
          currentUser: actor,
        );
        break;
      case 'ptt_request':
      case 'ptt_release':
      case 'voice_note':
      case 'voice_ack':
      case 'live_audio_start':
      case 'live_audio_chunk':
      case 'live_audio_end':
        result = await _pttRepository.handleIncomingPacket(
          packet: packet,
          activeChannel: activeChannel,
          currentUser: actor.toUserModel(),
        );
        if (!packet.packetType.startsWith('live_audio_')) {
          await _tryBridge(packet);
        }
        break;
      default:
        result = 'Unsupported offline packet ignored.';
        break;
    }

    state = state.copyWith(lastNotice: result);
    _debugRouter(
      'handled',
      packet: packet,
      bytes: packetJson.length,
      reason: result,
    );
  }

  Future<void> _tryBridge(OfflinePacketModel packet) async {
    try {
      await _bridgeEngine?.bridgeOfflinePacketToOnline(packet);
    } catch (_) {
      // Bridge errors are persisted by the bridge layer when policy is reached.
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final offlinePacketRouterProvider =
    StateNotifierProvider<OfflinePacketRouter, OfflinePacketRouterState>((ref) {
  final nearbyRepository = ref.watch(nearbyRepositoryProvider);
  final router = OfflinePacketRouter(
    channelRepository: ref.read(offlineChannelRepositoryProvider),
    chatRepository: OfflineChatRepository(nearbyRepository: nearbyRepository),
    emergencyRepository:
        EmergencyRepository(nearbyRepository: nearbyRepository),
    locationRepository: LocationRepository(nearbyRepository: nearbyRepository),
    pttRepository: PttRepository(nearbyRepository: nearbyRepository),
    metricsRecorder: ConnectivityMetricsRecorder(),
    packetStream: nearbyRepository.packetReceivedStream,
    currentActor: _currentRouterActor(ref),
    bridgeEngine: ref.read(bridgeEngineProvider),
  );

  ref.listen(authControllerProvider, (_, next) {
    router.setCurrentUser(next.user);
    unawaited(_refreshRouterActorFromStorage(ref, router));
  });
  ref.listen(authAccessControllerProvider, (_, __) {
    router.setCurrentActor(_currentRouterActor(ref));
    unawaited(_refreshRouterActorFromStorage(ref, router));
  });

  unawaited(_refreshRouterActorFromStorage(ref, router));

  return router;
});

CurrentUserActor? _currentRouterActor(Ref ref) {
  try {
    return CurrentUserActor.fromAuthAccess(
      ref.read(authAccessControllerProvider),
    );
  } catch (_) {
    final user = ref.read(authControllerProvider).user;
    return user == null ? null : CurrentUserActor.fromUserModel(user);
  }
}

Future<void> _refreshRouterActorFromStorage(
  Ref ref,
  OfflinePacketRouter router,
) async {
  try {
    final syncActor = _currentRouterActor(ref);
    if (syncActor != null) {
      router.setCurrentActor(syncActor);
      return;
    }
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    router.setCurrentActor(
      identity == null ? null : CurrentUserActor.fromLocalIdentity(identity),
    );
  } catch (error) {
    _debugRouter('actor_update_failed', reason: error.toString());
  }
}

void _debugRouter(
  String event, {
  OfflinePacketModel? packet,
  String? packetJson,
  int? bytes,
  String? reason,
}) {
  if (!kDebugMode) return;
  final summary = packet ?? _tryParsePacket(packetJson);
  debugPrint(
    '[TrailLink][OfflinePacketRouter] event=$event '
    'type=${summary?.packetType ?? 'unknown'} '
    'packet=${summary?.packetId ?? 'unknown'} '
    'channel=${summary?.channelCode ?? 'unknown'} '
    'bytes=${bytes ?? packetJson?.length ?? 0} '
    'reason=${reason ?? '-'}',
  );
}

OfflinePacketModel? _tryParsePacket(String? packetJson) {
  if (packetJson == null || packetJson.isEmpty) return null;
  try {
    return OfflinePacketModel.fromJsonString(packetJson);
  } catch (_) {
    return null;
  }
}
