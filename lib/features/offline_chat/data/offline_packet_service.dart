import 'package:uuid/uuid.dart';

import '../../../core/identity/current_user_actor.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import 'models/offline_packet_model.dart';

class OfflinePacketService {
  OfflinePacketService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  OfflinePacketModel createTextPacket({
    required OfflineChannelModel channel,
    required CurrentUserActor actor,
    required String content,
    String? chatId,
  }) {
    final messageId = _uuid.v4();
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'text',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      tripId: channel.tripId,
      chatId: chatId,
      senderId: actor.backendUserId ?? actor.localUserId,
      senderLocalId: actor.localUserId,
      senderBackendId: actor.backendUserId,
      senderName: actor.displayName,
      identityType: actor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      payload: {
        'messageId': messageId,
        'clientMessageId': messageId,
        if (chatId != null) 'chatId': chatId,
        'content': content,
        'originLocalId': actor.localUserId,
        'originBackendId': actor.backendUserId,
        'originDisplayName': actor.displayName,
        'originIdentityType': actor.identityType,
      },
      createdAt: DateTime.now(),
      requiresAck: true,
    );
  }

  OfflinePacketModel createAckPacket({
    required OfflinePacketModel receivedPacket,
    required CurrentUserActor actor,
  }) {
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'ack',
      channelId: receivedPacket.channelId,
      channelCode: receivedPacket.channelCode,
      senderId: actor.backendUserId ?? actor.localUserId,
      senderLocalId: actor.localUserId,
      senderBackendId: actor.backendUserId,
      senderName: actor.displayName,
      identityType: actor.identityType,
      sourcePath: 'offline',
      targetType: 'device',
      targetId: receivedPacket.senderLocalId ?? receivedPacket.senderId,
      payload: {
        'ackForPacketId': receivedPacket.packetId,
        'ackForMessageId': receivedPacket.messageId,
        'receivedAt': DateTime.now().toIso8601String(),
      },
      ttl: 3,
      createdAt: DateTime.now(),
      requiresAck: false,
    );
  }
}
