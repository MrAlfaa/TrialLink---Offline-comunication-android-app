import 'package:flutter/foundation.dart';

import '../../features/nearby/data/models/nearby_peer_model.dart';
import '../../features/nearby/data/nearby_repository.dart';
import '../../features/offline_chat/data/models/offline_packet_model.dart';
import '../identity/current_user_actor.dart';

class OfflineRelayService {
  OfflineRelayService({
    required NearbyRepository nearbyRepository,
    this.maxHopCount = 5,
  }) : _nearbyRepository = nearbyRepository;

  static const relayablePacketTypes = {
    'ack',
    'sos',
    'sos_ack',
    'location',
    'heartbeat',
  };

  final NearbyRepository _nearbyRepository;
  final int maxHopCount;

  Future<OfflineRelayResult> relayIfNeeded({
    required OfflinePacketModel packet,
    required String activeChannelCode,
    required CurrentUserActor currentActor,
  }) async {
    if (!relayablePacketTypes.contains(packet.packetType)) {
      return const OfflineRelayResult.skipped('not-relayable');
    }
    if (packet.channelCode != activeChannelCode) {
      return const OfflineRelayResult.skipped('wrong-channel');
    }
    if (packet.ttl <= 1 || packet.hopCount >= maxHopCount) {
      return const OfflineRelayResult.skipped('expired');
    }
    if (_isFromCurrentActor(packet, currentActor)) {
      return const OfflineRelayResult.skipped('own-packet');
    }

    final peers = await _nearbyRepository.connectedPeers(activeChannelCode);
    final relayPacket = packet.relayCopy();
    var sentCount = 0;
    var failedCount = 0;
    for (final peer in peers) {
      if (_shouldSkipPeer(peer, packet, currentActor)) continue;
      try {
        await _nearbyRepository.sendPacket(
          endpointId: peer.endpointId,
          packetJson: relayPacket.toJsonString(),
        );
        sentCount += 1;
      } catch (error) {
        failedCount += 1;
        _debugRelay(
          'send_failed',
          packet: packet,
          endpointId: peer.endpointId,
          reason: error.toString(),
        );
      }
    }

    final result = OfflineRelayResult(
      action: sentCount > 0 ? 'relayed' : 'no-targets',
      sentCount: sentCount,
      failedCount: failedCount,
    );
    _debugRelay(
      result.action,
      packet: relayPacket,
      reason: 'sent=$sentCount failed=$failedCount',
    );
    return result;
  }

  bool _shouldSkipPeer(
    NearbyPeerModel peer,
    OfflinePacketModel packet,
    CurrentUserActor currentActor,
  ) {
    if (peer.matchesLocalIdentity(
      localUserId: currentActor.localUserId,
      actorId: currentActor.id,
      backendUserId: currentActor.backendUserId,
      publicUserId: currentActor.publicUserId,
      displayName: currentActor.displayName,
    )) {
      return true;
    }
    final packetIds = {
      packet.senderId,
      if (packet.senderLocalId != null) packet.senderLocalId!,
      if (packet.senderBackendId != null) packet.senderBackendId!,
      packet.originLocalId,
    }.map((value) => value.trim()).where((value) => value.isNotEmpty).toSet();
    return packetIds.contains(peer.userId.trim());
  }

  bool _isFromCurrentActor(
    OfflinePacketModel packet,
    CurrentUserActor currentActor,
  ) {
    return packet.senderId == currentActor.id ||
        packet.senderId == currentActor.localUserId ||
        packet.senderLocalId == currentActor.localUserId ||
        (packet.senderBackendId != null &&
            packet.senderBackendId == currentActor.backendUserId) ||
        packet.originLocalId == currentActor.localUserId;
  }
}

class OfflineRelayResult {
  const OfflineRelayResult({
    required this.action,
    required this.sentCount,
    required this.failedCount,
  });

  const OfflineRelayResult.skipped(String reason)
      : action = reason,
        sentCount = 0,
        failedCount = 0;

  final String action;
  final int sentCount;
  final int failedCount;
}

void _debugRelay(
  String event, {
  required OfflinePacketModel packet,
  String? endpointId,
  String? reason,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[TrailLink][OfflineRelay] event=$event '
    'type=${packet.packetType} '
    'packet=${packet.packetId} '
    'channel=${packet.channelCode} '
    'hop=${packet.hopCount} '
    'ttl=${packet.ttl} '
    'endpoint=${endpointId ?? '-'} '
    'reason=${reason ?? '-'}',
  );
}
