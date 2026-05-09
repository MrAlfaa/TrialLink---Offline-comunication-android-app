import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/settings/feature_flag_service.dart';
import '../../chat/data/chat_api.dart';
import '../../chat/data/models/chat_message_model.dart';
import '../../emergency/data/emergency_api.dart';
import '../../location/data/location_api.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import '../../trip/data/trip_session_repository.dart';
import 'bridge_local_data_source.dart';
import 'bridge_policy.dart';
import 'bridge_repository.dart';
import 'models/bridge_direction.dart';
import 'models/bridge_record_model.dart';
import 'models/bridge_source_path.dart';
import 'models/bridge_status.dart';

final bridgeEngineProvider = Provider<BridgeEngine>((ref) {
  return BridgeEngine(
    ref: ref,
    bridgeRepository: ref.read(bridgeRepositoryProvider),
    nearbyRepository: ref.read(nearbyRepositoryProvider),
    chatApi: ChatApi(),
    emergencyApi: EmergencyApi(),
    locationApi: LocationApi(),
  );
});

class BridgeEngine {
  BridgeEngine({
    required Ref ref,
    required BridgeRepository bridgeRepository,
    required NearbyRepository nearbyRepository,
    required ChatApi chatApi,
    required EmergencyApi emergencyApi,
    required LocationApi locationApi,
    BridgePolicy? policy,
    Uuid? uuid,
  })  : _ref = ref,
        _bridgeRepository = bridgeRepository,
        _nearbyRepository = nearbyRepository,
        _chatApi = chatApi,
        _emergencyApi = emergencyApi,
        _locationApi = locationApi,
        _policy = policy ?? BridgePolicy(),
        _uuid = uuid ?? const Uuid();

  final Ref _ref;
  final BridgeRepository _bridgeRepository;
  final NearbyRepository _nearbyRepository;
  final ChatApi _chatApi;
  final EmergencyApi _emergencyApi;
  final LocationApi _locationApi;
  final BridgePolicy _policy;
  final Uuid _uuid;

  Future<String> bridgeOnlineMessageToOffline(ChatMessageModel message) async {
    if (message.sourcePath == BridgeSourcePath.bridge.value) {
      return 'Already a bridged message.';
    }
    if (message.messageType != 'text') {
      return 'Media messages are cloud-only and are not bridged offline.';
    }
    final activeTrip =
        await _ref.read(tripSessionRepositoryProvider).getActiveTrip();
    final settings = await _bridgeRepository.getSettings();
    final featureEnabled = await _ref
        .read(featureFlagServiceProvider)
        .isFeatureEnabled('bridge_mode');
    final channelCode = activeTrip?.channelCode;
    if (channelCode == null || channelCode.isEmpty) {
      return 'Missing offline channel code.';
    }
    final peers = await BridgeLocalDataSource().connectedPeers(channelCode);
    final uniqueItemId = uniqueMessageId(
      message.originLocalId ?? message.senderId,
      message.clientMessageId,
    );
    final duplicate = await _bridgeRepository.isProcessed(uniqueItemId);
    final decision = _policy.canBridgeOnlineToOffline(
      featureEnabled: featureEnabled,
      settings: settings,
      activeTrip: activeTrip,
      groupId: message.groupId,
      duplicate: duplicate,
      connectedPeerCount: peers.length,
    );
    final actor = _currentActorOrNull();
    if (actor == null) return 'Bridge actor identity unavailable.';

    if (!decision.allowed) {
      await _saveRecord(
        status: duplicate ? BridgeStatus.duplicateIgnored : BridgeStatus.failed,
        direction: BridgeDirection.onlineToOffline,
        sourcePath: BridgeSourcePath.online,
        channelCode: channelCode,
        actor: actor,
        activeTripId: activeTrip?.tripId,
        groupId: message.groupId,
        channelId: activeTrip?.offlineChannelId,
        clientMessageId: message.clientMessageId,
        originSenderId: message.senderId,
        originSenderLocalId: message.originLocalId ?? message.senderId,
        originDisplayName: message.senderName,
        payload: message.toSyncJson(),
        errorMessage: decision.reason,
      );
      return decision.reason ?? 'Bridge skipped.';
    }

    final packet = OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'text',
      tripId: activeTrip!.tripId,
      channelId: activeTrip.offlineChannelId!,
      channelCode: channelCode,
      senderId: actor.backendUserId ?? actor.localUserId,
      senderLocalId: actor.localUserId,
      senderBackendId: actor.backendUserId,
      senderName: actor.displayName,
      identityType: actor.identityType,
      sourcePath: BridgeSourcePath.bridge.value,
      targetType: 'channel',
      targetId: activeTrip.offlineChannelId!,
      priority: 'normal',
      ttl: 5,
      hopCount: 0,
      createdAt: message.createdAt,
      requiresAck: true,
      payload: {
        'messageId': message.clientMessageId,
        'clientMessageId': message.clientMessageId,
        'content': message.content,
        'originLocalId': message.originLocalId ?? message.senderId,
        'originBackendId': message.senderId,
        'originDisplayName': message.senderName,
        'originIdentityType': message.originIdentityType ?? 'verified',
        'bridgedByLocalId': actor.localUserId,
        'bridgedByBackendId': actor.backendUserId,
        'bridgedByName': actor.displayName,
        'bridgedAt': DateTime.now().toIso8601String(),
      },
    );

    for (final peer in peers) {
      await _nearbyRepository.sendPacket(
        endpointId: peer.endpointId,
        packetJson: packet.toJsonString(),
      );
    }
    await _bridgeRepository.markProcessed(
      uniqueItemId: uniqueItemId,
      itemType: 'message',
      sourcePath: BridgeSourcePath.online.value,
    );
    await _saveRecord(
      status: BridgeStatus.bridged,
      direction: BridgeDirection.onlineToOffline,
      sourcePath: BridgeSourcePath.online,
      channelCode: channelCode,
      actor: actor,
      activeTripId: activeTrip.tripId,
      groupId: message.groupId,
      channelId: activeTrip.offlineChannelId,
      clientMessageId: message.clientMessageId,
      originalPacketId: packet.packetId,
      originSenderId: message.senderId,
      originSenderLocalId: message.originLocalId ?? message.senderId,
      originDisplayName: message.senderName,
      payload: packet.toJson(),
    );
    return 'Message bridged to nearby peers.';
  }

  Future<String> bridgeOfflinePacketToOnline(OfflinePacketModel packet) async {
    return switch (packet.packetType) {
      'text' => _bridgeOfflineText(packet),
      'sos' => _bridgeOfflineSos(packet),
      'location' => _bridgeOfflineLocation(packet),
      'voice_note' => _bridgeOfflineVoice(packet),
      _ => 'Unsupported bridge packet.',
    };
  }

  Future<String> _bridgeOfflineText(OfflinePacketModel packet) async {
    final decisionContext = await _offlineDecision(packet, 'message');
    if (!decisionContext.allowed) return decisionContext.message;
    final groupId = decisionContext.groupId!;
    await _chatApi.syncPendingMessages(groupId: groupId, messages: [
      {
        'clientMessageId': packet.clientMessageId ?? packet.packetId,
        'content': packet.content ?? '',
        'messageType': 'text',
        'createdAt': packet.createdAt.toIso8601String(),
        ..._bridgeMetadata(packet, decisionContext.actor!),
      }
    ]);
    await _markOfflineBridgeSuccess(packet, decisionContext, 'message');
    return 'Offline message bridged to online group.';
  }

  Future<String> _bridgeOfflineSos(OfflinePacketModel packet) async {
    final decisionContext = await _offlineDecision(packet, 'sos');
    if (!decisionContext.allowed) return decisionContext.message;
    await _emergencyApi.createBridgeEmergency(
      groupId: decisionContext.groupId!,
      packet: packet,
      metadata: _bridgeMetadata(packet, decisionContext.actor!),
    );
    await _markOfflineBridgeSuccess(packet, decisionContext, 'sos');
    return 'SOS bridged to online group.';
  }

  Future<String> _bridgeOfflineLocation(OfflinePacketModel packet) async {
    final decisionContext = await _offlineDecision(packet, 'location');
    if (!decisionContext.allowed) return decisionContext.message;
    await _locationApi.syncBridgeLocations(
      groupId: decisionContext.groupId!,
      packet: packet,
      metadata: _bridgeMetadata(packet, decisionContext.actor!),
    );
    await _markOfflineBridgeSuccess(packet, decisionContext, 'location');
    return 'Location bridged to online group.';
  }

  Future<String> _bridgeOfflineVoice(OfflinePacketModel packet) async {
    final size =
        int.tryParse(packet.payload['fileSizeBytes']?.toString() ?? '') ?? 0;
    if (size > 250 * 1024) {
      final context = await _offlineDecision(packet, 'voice');
      await _saveRecord(
        status: BridgeStatus.failed,
        direction: BridgeDirection.offlineToOnline,
        sourcePath: BridgeSourcePath.offline,
        channelCode: packet.channelCode,
        actor: context.actor ?? _currentActorOrNull(),
        activeTripId: context.activeTripId,
        groupId: context.groupId,
        channelId: packet.channelId,
        originalPacketId: packet.packetId,
        originSenderId: packet.senderBackendId ?? packet.senderId,
        originSenderLocalId: packet.originLocalId,
        originDisplayName: packet.originDisplayName,
        payload: packet.toJson(),
        errorMessage: 'Voice note too large to bridge.',
      );
      return 'Voice note too large to bridge.';
    }
    return 'Voice bridge policy recorded. Upload is limited to existing voice endpoint support.';
  }

  Future<_OfflineBridgeDecision> _offlineDecision(
    OfflinePacketModel packet,
    String itemType,
  ) async {
    final activeTrip =
        await _ref.read(tripSessionRepositoryProvider).getActiveTrip();
    final settings = await _bridgeRepository.getSettings();
    final featureEnabled = await _ref
        .read(featureFlagServiceProvider)
        .isFeatureEnabled('bridge_mode');
    final authAccess = _ref.read(authAccessControllerProvider);
    final modeState = _ref.read(modeControllerProvider);
    final uniqueItemId = uniqueItemIdForPacket(packet);
    final duplicate = await _bridgeRepository.isProcessed(uniqueItemId);
    final actor = _currentActorOrNull();
    final decision = _policy.canBridgeOfflineToOnline(
      featureEnabled: featureEnabled,
      settings: settings,
      activeTrip: activeTrip,
      packet: packet,
      authAccessState: authAccess.accessState,
      modeState: modeState,
      duplicate: duplicate,
    );
    if (!decision.allowed) {
      await _saveRecord(
        status: duplicate ? BridgeStatus.duplicateIgnored : BridgeStatus.failed,
        direction: BridgeDirection.offlineToOnline,
        sourcePath: BridgeSourcePath.offline,
        channelCode: packet.channelCode,
        actor: actor,
        activeTripId: activeTrip?.tripId,
        groupId: activeTrip?.cloudGroupId,
        channelId: packet.channelId,
        originalPacketId: packet.packetId,
        clientMessageId: packet.clientMessageId,
        originSenderId: packet.senderBackendId ?? packet.senderId,
        originSenderLocalId: packet.originLocalId,
        originDisplayName: packet.originDisplayName,
        payload: packet.toJson(),
        errorMessage: decision.reason,
      );
      if (duplicate) {
        await _bridgeRepository.markProcessed(
          uniqueItemId: uniqueItemId,
          itemType: itemType,
          sourcePath: BridgeSourcePath.offline.value,
        );
      }
      return _OfflineBridgeDecision.denied(
        message: decision.reason ?? 'Bridge skipped.',
        actor: actor,
        groupId: activeTrip?.cloudGroupId,
        activeTripId: activeTrip?.tripId,
      );
    }
    return _OfflineBridgeDecision.allowed(
      actor: actor!,
      groupId: activeTrip!.cloudGroupId!,
      activeTripId: activeTrip.tripId,
      uniqueItemId: uniqueItemId,
      itemType: itemType,
    );
  }

  Future<void> _markOfflineBridgeSuccess(
    OfflinePacketModel packet,
    _OfflineBridgeDecision context,
    String itemType,
  ) async {
    await _bridgeRepository.markProcessed(
      uniqueItemId: context.uniqueItemId!,
      itemType: itemType,
      sourcePath: BridgeSourcePath.offline.value,
    );
    await _saveRecord(
      status: BridgeStatus.bridged,
      direction: BridgeDirection.offlineToOnline,
      sourcePath: BridgeSourcePath.offline,
      channelCode: packet.channelCode,
      actor: context.actor,
      activeTripId: context.activeTripId,
      groupId: context.groupId,
      channelId: packet.channelId,
      originalPacketId: packet.packetId,
      clientMessageId: packet.clientMessageId,
      originSenderId: packet.senderBackendId ?? packet.senderId,
      originSenderLocalId: packet.originLocalId,
      originDisplayName: packet.originDisplayName,
      payload: packet.toJson(),
    );
  }

  Map<String, dynamic> _bridgeMetadata(
    OfflinePacketModel packet,
    CurrentUserActor actor,
  ) {
    return {
      'sourcePath': BridgeSourcePath.bridge.value,
      'originLocalId': packet.originLocalId,
      'originDisplayName': packet.originDisplayName,
      'originBackendId': packet.senderBackendId,
      'originIdentityType': packet.identityType,
      'bridgedBy': actor.backendUserId,
      'bridgedByLocalId': actor.localUserId,
      'bridgedByName': actor.displayName,
      'bridgedAt': DateTime.now().toIso8601String(),
      'originalPacketId': packet.packetId,
      'channelCode': packet.channelCode,
    };
  }

  Future<void> _saveRecord({
    required BridgeStatus status,
    required BridgeDirection direction,
    required BridgeSourcePath sourcePath,
    required String channelCode,
    required CurrentUserActor? actor,
    required Map<String, dynamic> payload,
    String? activeTripId,
    String? groupId,
    String? channelId,
    String? originalPacketId,
    String? clientMessageId,
    String? originSenderId,
    String? originSenderLocalId,
    String? originDisplayName,
    String? errorMessage,
  }) async {
    final now = DateTime.now();
    await _bridgeRepository.saveRecord(
      BridgeRecordModel(
        bridgeRecordId: _uuid.v4(),
        originalPacketId: originalPacketId,
        clientMessageId: clientMessageId,
        sourcePath: sourcePath.value,
        direction: direction.value,
        tripId: activeTripId,
        groupId: groupId,
        channelId: channelId,
        channelCode: channelCode,
        originSenderId: originSenderId,
        originSenderLocalId: originSenderLocalId,
        originDisplayName: originDisplayName,
        bridgedByLocalId: actor?.localUserId ?? 'unknown',
        bridgedByBackendId: actor?.backendUserId,
        bridgedByName: actor?.displayName,
        bridgedAt: now,
        status: status.value,
        payloadJson: jsonEncode(payload),
        errorMessage: errorMessage,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  CurrentUserActor? _currentActorOrNull() {
    try {
      return CurrentUserActor.fromAuthAccess(
        _ref.read(authAccessControllerProvider),
      );
    } catch (_) {
      return null;
    }
  }

  static String uniqueItemIdForPacket(OfflinePacketModel packet) {
    final origin = packet.originLocalId;
    return switch (packet.packetType) {
      'text' when (packet.clientMessageId ?? '').isNotEmpty =>
        uniqueMessageId(origin, packet.clientMessageId!),
      'sos' when (packet.localEventId ?? '').isNotEmpty =>
        'sos:$origin:${packet.localEventId}',
      'location' when (packet.localLocationId ?? '').isNotEmpty =>
        'location:$origin:${packet.localLocationId}',
      'voice_note' when (packet.localVoiceId ?? '').isNotEmpty =>
        'voice:$origin:${packet.localVoiceId}',
      _ => 'packet:${packet.packetId}',
    };
  }

  static String uniqueMessageId(String originLocalId, String clientMessageId) {
    return 'message:$originLocalId:$clientMessageId';
  }
}

class _OfflineBridgeDecision {
  const _OfflineBridgeDecision._({
    required this.allowed,
    required this.message,
    this.actor,
    this.groupId,
    this.activeTripId,
    this.uniqueItemId,
    this.itemType,
  });

  factory _OfflineBridgeDecision.allowed({
    required CurrentUserActor actor,
    required String groupId,
    required String activeTripId,
    required String uniqueItemId,
    required String itemType,
  }) {
    return _OfflineBridgeDecision._(
      allowed: true,
      message: 'Allowed',
      actor: actor,
      groupId: groupId,
      activeTripId: activeTripId,
      uniqueItemId: uniqueItemId,
      itemType: itemType,
    );
  }

  factory _OfflineBridgeDecision.denied({
    required String message,
    CurrentUserActor? actor,
    String? groupId,
    String? activeTripId,
  }) {
    return _OfflineBridgeDecision._(
      allowed: false,
      message: message,
      actor: actor,
      groupId: groupId,
      activeTripId: activeTripId,
    );
  }

  final bool allowed;
  final String message;
  final CurrentUserActor? actor;
  final String? groupId;
  final String? activeTripId;
  final String? uniqueItemId;
  final String? itemType;
}
