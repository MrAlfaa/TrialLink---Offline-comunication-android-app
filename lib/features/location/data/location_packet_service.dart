import 'package:uuid/uuid.dart';

import '../../../core/identity/current_user_actor.dart';
import '../../auth/data/models/user_model.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'models/location_update_model.dart';

class LocationPacketService {
  LocationPacketService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  OfflinePacketModel createLocationPacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required LocationUpdateModel location,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'location',
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
      payload: {
        'localLocationId': location.localLocationId,
        'originLocalId': packetActor.localUserId,
        'originBackendId': packetActor.backendUserId,
        'originDisplayName': packetActor.displayName,
        'originIdentityType': packetActor.identityType,
        'latitude': location.latitude,
        'longitude': location.longitude,
        if (location.accuracy != null) 'accuracy': location.accuracy,
        'capturedAt': location.capturedAt.toIso8601String(),
      },
      priority: 'normal',
      ttl: 5,
      createdAt: DateTime.now(),
      requiresAck: false,
    );
  }
}
