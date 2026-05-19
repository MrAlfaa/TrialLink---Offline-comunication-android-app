import 'package:flutter/foundation.dart';

import '../../../core/identity/current_user_actor.dart';
import '../../connectivity_intelligence/data/connectivity_metrics_recorder.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import 'models/offline_ack_model.dart';
import 'models/offline_packet_model.dart';
import 'models/offline_text_message_model.dart';
import 'offline_message_local_data_source.dart';
import 'offline_packet_service.dart';

class OfflineChatRepository {
  OfflineChatRepository({
    required NearbyRepository nearbyRepository,
    OfflineMessageLocalDataSource? local,
    OfflinePacketService? packetService,
    ConnectivityMetricsRecorder? metricsRecorder,
  })  : _nearby = nearbyRepository,
        _local = local ?? OfflineMessageLocalDataSource(),
        _packetService = packetService ?? OfflinePacketService(),
        _metricsRecorder = metricsRecorder ?? ConnectivityMetricsRecorder();

  static const maxHopCount = 5;

  final NearbyRepository _nearby;
  final OfflineMessageLocalDataSource _local;
  final OfflinePacketService _packetService;
  final ConnectivityMetricsRecorder _metricsRecorder;

  Stream<String> get packetReceivedStream => _nearby.packetReceivedStream;

  Future<List<OfflineTextMessageModel>> loadMessages(String channelId) {
    return _local.getMessages(channelId);
  }

  Future<List<NearbyPeerModel>> connectedPeers(String channelCode) {
    return _nearby.connectedPeers(channelCode);
  }

  Future<OfflineTextMessageModel> createOutgoing({
    required OfflineChannelModel channel,
    required CurrentUserActor actor,
    required String content,
    String? chatId,
  }) async {
    if (!channel.isUsable) {
      throw StateError('This channel has ended. Chat history is read-only.');
    }
    final packet = _packetService.createTextPacket(
      channel: channel,
      actor: actor,
      content: content,
      chatId: chatId,
    );
    final message = OfflineTextMessageModel(
      messageId: packet.messageId!,
      packetId: packet.packetId,
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      chatId: chatId,
      senderId: actor.localUserId,
      senderName: actor.displayName,
      content: content,
      isMine: true,
      deliveryStatus: 'pending',
      ackStatus: 'waiting',
      ttl: packet.ttl,
      hopCount: packet.hopCount,
      createdAt: packet.createdAt,
      sourcePath: 'offline',
      originLocalId: actor.localUserId,
      originIdentityType: actor.identityType,
    );
    await _local.upsertMessage(message);
    await _local.enqueuePacket(packet);
    return message;
  }

  Future<void> sendQueuedPackets({
    required OfflineChannelModel channel,
  }) async {
    final peers = await connectedPeers(channel.channelCode);
    if (peers.isEmpty) return;
    final packets = await _local.getQueuedPackets(channel.channelId);
    for (final packet in packets) {
      await _sendPacketToPeers(packet, peers);
    }
  }

  Future<void> sendMessagePacket({
    required OfflineTextMessageModel message,
    required OfflineChannelModel channel,
  }) async {
    final peers = await connectedPeers(channel.channelCode);
    if (peers.isEmpty) return;
    final packets = await _local.getQueuedPackets(channel.channelId);
    final packet = packets
        .where((item) => item.packetId == message.packetId)
        .cast<OfflinePacketModel?>()
        .firstOrNull;
    if (packet == null) return;
    await _sendPacketToPeers(packet, peers);
  }

  Future<void> markAckTimeout(String messageId) {
    return _local.updateMessageStatus(
      messageId: messageId,
      deliveryStatus: 'sent',
      ackStatus: 'timeout',
    );
  }

  Future<void> markAckTimeoutIfStillWaiting(String messageId) async {
    final message = await _local.getMessage(messageId);
    if (message == null || message.ackStatus == 'acknowledged') {
      _debugOfflineChat(
        'ack_timeout_skip',
        messageId: messageId,
        reason: message == null ? 'missing-message' : 'already-acknowledged',
      );
      return;
    }
    if (await _local.ackExistsForMessage(
      messageId: message.messageId,
      packetId: message.packetId,
    )) {
      await _local.updateMessageStatus(
        messageId: message.messageId,
        deliveryStatus: 'delivered',
        ackStatus: 'acknowledged',
      );
      _debugOfflineChat(
        'ack_timeout_skip',
        packetId: message.packetId,
        messageId: message.messageId,
        reason: 'ack-already-saved',
      );
      return;
    }
    _debugOfflineChat('ack_timeout_mark', messageId: messageId);
    await markAckTimeout(messageId);
  }

  Future<void> _sendPacketToPeers(
    OfflinePacketModel packet,
    List<NearbyPeerModel> peers,
  ) async {
    var sent = false;
    if (peers.isEmpty && packet.packetType == 'ack') {
      _debugOfflineChat(
        'ack_tx_no_peers',
        packetId: packet.packetId,
        messageId: packet.ackForMessageId,
      );
    }
    for (final peer in peers) {
      try {
        await _nearby.sendPacket(
          endpointId: peer.endpointId,
          packetJson: packet.toJsonString(),
        );
        await _metricsRecorder.recordPacketResult(
          endpointId: peer.endpointId,
          userId: peer.userId,
          displayName: peer.displayName,
          channelId: packet.channelId,
          channelCode: packet.channelCode,
          success: true,
        );
        sent = true;
      } catch (error) {
        await _metricsRecorder.recordPacketResult(
          endpointId: peer.endpointId,
          userId: peer.userId,
          displayName: peer.displayName,
          channelId: packet.channelId,
          channelCode: packet.channelCode,
          success: false,
          retryCount: 1,
        );
        await _local.markQueueStatus(
          packet.packetId,
          'failed',
          lastError: error.toString(),
        );
      }
    }

    if (sent) {
      await _local.markQueueStatus(packet.packetId, 'sent');
      if (packet.messageId != null) {
        await _local.markMessageSentAfterTransfer(
          messageId: packet.messageId!,
          packetId: packet.packetId,
          requiresAck: packet.requiresAck,
        );
      }
    }
  }

  Future<OfflinePacketHandleResult> handleIncomingPacket({
    required String packetJson,
    required OfflineChannelModel activeChannel,
    required CurrentUserActor currentUser,
  }) async {
    OfflinePacketModel packet;
    try {
      packet = OfflinePacketModel.fromJsonString(packetJson);
    } catch (_) {
      return const OfflinePacketHandleResult(
        action: 'ignored_malformed',
        message: 'Invalid offline packet ignored.',
      );
    }

    if (packet.channelCode != activeChannel.channelCode) {
      await _local.markProcessed(
          packet: packet, action: 'ignored_wrong_channel');
      return const OfflinePacketHandleResult(
        action: 'ignored_wrong_channel',
        message: 'Packet belongs to another channel.',
      );
    }
    if (packet.ttl <= 0 || packet.hopCount > maxHopCount) {
      await _local.markProcessed(packet: packet, action: 'ignored_expired');
      return const OfflinePacketHandleResult(
        action: 'ignored_expired',
        message: 'Expired offline packet ignored.',
      );
    }
    if (await _local.processedPacketExists(packet.packetId)) {
      await _local.markProcessed(
        packet: packet,
        action: 'ignored_duplicate',
      );
      return const OfflinePacketHandleResult(
        action: 'ignored_duplicate',
        message: 'Duplicate offline packet ignored.',
      );
    }

    if (packet.packetType == 'ack') {
      await _handleAck(packet);
      await _local.markProcessed(packet: packet, action: 'accepted');
      return const OfflinePacketHandleResult(
        action: 'accepted',
        message: 'Message delivery acknowledged.',
      );
    }

    if (packet.packetType != 'text' || (packet.content ?? '').trim().isEmpty) {
      await _local.markProcessed(packet: packet, action: 'ignored_invalid');
      return const OfflinePacketHandleResult(
        action: 'ignored_invalid',
        message: 'Unsupported offline packet ignored.',
      );
    }

    if (!await _local.messageExists(packet.messageId!)) {
      await _local.upsertMessage(
        OfflineTextMessageModel(
          messageId: packet.messageId!,
          packetId: packet.packetId,
          channelId: activeChannel.channelId,
          channelCode: activeChannel.channelCode,
          chatId: packet.chatId,
          senderId: packet.senderId,
          senderName: packet.senderName,
          content: packet.content!,
          isMine: packet.originLocalId == currentUser.localUserId ||
              packet.senderId == currentUser.id,
          deliveryStatus: packet.originLocalId == currentUser.localUserId ||
                  packet.senderId == currentUser.id
              ? 'delivered'
              : 'received',
          ackStatus: packet.requiresAck ? 'acknowledged' : 'none',
          ttl: packet.ttl,
          hopCount: packet.hopCount,
          createdAt: packet.createdAt,
          sourcePath: packet.sourcePath,
          originLocalId: packet.originLocalId,
          originIdentityType: packet.identityType,
          bridgedByName: packet.payload['bridgedByName']?.toString(),
        ),
      );
    }

    await _local.markProcessed(packet: packet, action: 'accepted');
    if (packet.originLocalId != currentUser.localUserId && packet.requiresAck) {
      final ack = _packetService.createAckPacket(
        receivedPacket: packet,
        actor: currentUser,
      );
      await _sendPacketToPeers(
        ack,
        await connectedPeers(activeChannel.channelCode),
      );
    }

    if (packet.ttl > 1 && packet.hopCount < maxHopCount) {
      await _sendPacketToPeers(
        packet.relayCopy(),
        await connectedPeers(activeChannel.channelCode),
      );
      await _local.markProcessed(packet: packet, action: 'relayed');
    }

    return const OfflinePacketHandleResult(
      action: 'accepted',
      message: 'Offline message received.',
    );
  }

  Future<void> _handleAck(OfflinePacketModel packet) async {
    await _local.saveAck(
      OfflineAckModel(
        ackId: packet.packetId,
        ackForPacketId: packet.ackForPacketId ?? '',
        ackForMessageId: packet.ackForMessageId,
        channelId: packet.channelId,
        receivedFromUserId: packet.senderId,
        receivedAt: DateTime.now(),
      ),
    );
    await _markMessageAcknowledged(packet);
    try {
      await _recordAckMetric(packet);
    } catch (error) {
      _debugOfflineChat(
        'ack_metric_failed',
        packetId: packet.packetId,
        messageId: packet.ackForMessageId,
        reason: error.toString(),
      );
    }
  }

  Future<void> _recordAckMetric(OfflinePacketModel packet) async {
    final peers = await connectedPeers(packet.channelCode);
    final matchingPeer = peers.where((peer) => peer.userId == packet.senderId);
    await _metricsRecorder.recordAck(
      endpointId: matchingPeer.isEmpty
          ? packet.senderId
          : matchingPeer.first.endpointId,
      userId: packet.senderId,
      displayName: packet.senderName,
      channelId: packet.channelId,
      channelCode: packet.channelCode,
      ackRttMs:
          DateTime.now().difference(packet.createdAt).inMilliseconds.abs(),
    );
  }

  Future<void> _markMessageAcknowledged(OfflinePacketModel packet) async {
    final messageId = packet.ackForMessageId;
    if (messageId != null && messageId.isNotEmpty) {
      final updated = await _local.updateMessageStatus(
        messageId: messageId,
        deliveryStatus: 'delivered',
        ackStatus: 'acknowledged',
      );
      _debugOfflineChat(
        'ack_rx',
        packetId: packet.packetId,
        messageId: messageId,
        reason: updated > 0 ? 'by-message-id' : 'message-id-not-found',
      );
      if (updated > 0) return;
    }
    final packetId = packet.ackForPacketId;
    if (packetId != null && packetId.isNotEmpty) {
      final updated = await _local.updateMessageStatusByPacket(
        packetId: packetId,
        deliveryStatus: 'delivered',
        ackStatus: 'acknowledged',
      );
      _debugOfflineChat(
        'ack_rx',
        packetId: packet.packetId,
        reason: updated > 0 ? 'by-packet-id' : 'packet-id-not-found',
      );
      return;
    }
    _debugOfflineChat(
      'ack_rx',
      packetId: packet.packetId,
      reason: 'missing-target',
    );
  }
}

void _debugOfflineChat(
  String event, {
  String? packetId,
  String? messageId,
  String? reason,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[TrailLink][OfflineChat] event=$event '
    'packet=${packetId ?? '-'} '
    'message=${messageId ?? '-'} '
    'reason=${reason ?? '-'}',
  );
}

class OfflinePacketHandleResult {
  const OfflinePacketHandleResult({
    required this.action,
    required this.message,
  });

  final String action;
  final String message;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
