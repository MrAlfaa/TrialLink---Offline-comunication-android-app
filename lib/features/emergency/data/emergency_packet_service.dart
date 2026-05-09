import 'package:uuid/uuid.dart';

import '../../../core/identity/current_user_actor.dart';
import '../../auth/data/models/user_model.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'models/emergency_event_model.dart';

class EmergencyPacketService {
  EmergencyPacketService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  OfflinePacketModel createSosPacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required EmergencyEventModel event,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'sos',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'emergency',
      ttl: 8,
      payload: {
        'localEventId': event.localEventId,
        'originLocalId': packetActor.localUserId,
        'originBackendId': packetActor.backendUserId,
        'originDisplayName': packetActor.displayName,
        'originIdentityType': packetActor.identityType,
        'alertType': event.alertType,
        'message': event.message ?? '',
        if (event.latitude != null && event.longitude != null)
          'location': {
            'latitude': event.latitude,
            'longitude': event.longitude,
            if (event.accuracy != null) 'accuracy': event.accuracy,
            'capturedAt':
                (event.locationCapturedAt ?? event.createdAt).toIso8601String(),
          },
      },
      createdAt: DateTime.now(),
      requiresAck: true,
    );
  }

  OfflinePacketModel createSosAckPacket({
    required OfflinePacketModel receivedPacket,
    required UserModel user,
    CurrentUserActor? actor,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'sos_ack',
      channelId: receivedPacket.channelId,
      channelCode: receivedPacket.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'device',
      targetId: receivedPacket.senderLocalId ?? receivedPacket.senderId,
      priority: 'high',
      ttl: 5,
      payload: {
        'ackForPacketId': receivedPacket.packetId,
        'ackForEventId': receivedPacket.payload['localEventId'],
        'receivedAt': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
      requiresAck: false,
    );
  }
}
