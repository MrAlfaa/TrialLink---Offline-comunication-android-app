import 'models/offline_packet_model.dart';

bool shouldProcessPacket({
  required OfflinePacketModel packet,
  required String activeChannelId,
  required String activeChannelCode,
  bool isDuplicate = false,
  int maxHopCount = 5,
}) {
  final matchesChannel = packet.channelId == activeChannelId ||
      packet.channelCode.toUpperCase() == activeChannelCode.toUpperCase();
  if (!matchesChannel) return false;
  if (packet.ttl <= 0) return false;
  if (packet.hopCount > maxHopCount) return false;
  if (isDuplicate) return false;
  return true;
}
