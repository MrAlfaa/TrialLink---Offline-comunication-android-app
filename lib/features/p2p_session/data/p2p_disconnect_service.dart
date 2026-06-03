import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../nearby/data/nearby_repository.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'p2p_session_service.dart';

final p2pDisconnectServiceProvider = Provider<P2PDisconnectService>((ref) {
  return P2PDisconnectService(
    sessionService: ref.read(p2pSessionServiceProvider),
  );
});

class P2PDisconnectService {
  P2PDisconnectService({
    required P2PSessionService sessionService,
    Uuid? uuid,
  })  : _sessionService = sessionService,
        _uuid = uuid ?? const Uuid();

  final P2PSessionService _sessionService;
  final Uuid _uuid;

  Future<void> stopActiveSession({
    required NearbyRepository nearbyRepository,
    String reason = 'manual_disconnect',
  }) async {
    final session = await _sessionService.getActiveSession();
    if (session == null) return;
    final peers = await _sessionService.getActiveSessionPeers();
    final leavePacket = OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'trip_session_leave',
      channelId: session.channelId,
      channelCode: session.channelCode,
      senderId: session.localUserId,
      tripId: session.tripId,
      senderLocalId: session.localUserId,
      senderName: 'TrailLink',
      targetType: 'channel',
      targetId: session.channelId,
      payload: {
        'tripId': session.tripId,
        'channelId': session.channelId,
        'channelCode': session.channelCode,
        'senderLocalId': session.localUserId,
        'reason': reason,
        'createdAt': DateTime.now().toIso8601String(),
      },
      priority: 'normal',
      ttl: 1,
      hopCount: 0,
      requiresAck: false,
      createdAt: DateTime.now(),
    );
    for (final peer in peers) {
      final endpointId = peer.endpointId;
      if ((endpointId ?? '').isEmpty) continue;
      try {
        await nearbyRepository.sendPacket(
          endpointId: endpointId!,
          packetJson: leavePacket.toJsonString(),
        );
      } catch (_) {
        // Disconnect still proceeds; this packet is best-effort courtesy.
      }
    }
    Object? disconnectError;
    try {
      await nearbyRepository.disconnectAllPeers();
    } catch (error) {
      disconnectError = error;
      if (kDebugMode) {
        debugPrint(
          '[TrailLink][P2PSession] Nearby disconnect failed; '
          'clearing app session anyway: $error',
        );
      }
    } finally {
      await _sessionService.disconnectAllPeers(reason: reason);
    }
    if (disconnectError != null && kDebugMode) {
      debugPrint(
        '[TrailLink][P2PSession] Nearby transport cleanup reported an error, '
        'but app-level P2P session is now disconnected.',
      );
    }
  }
}
