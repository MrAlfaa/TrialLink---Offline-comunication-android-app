class OfflineAckModel {
  const OfflineAckModel({
    required this.ackId,
    required this.ackForPacketId,
    this.ackForMessageId,
    required this.channelId,
    required this.receivedFromUserId,
    required this.receivedAt,
  });

  final String ackId;
  final String ackForPacketId;
  final String? ackForMessageId;
  final String channelId;
  final String receivedFromUserId;
  final DateTime receivedAt;

  Map<String, Object?> toDbMap() {
    return {
      'ack_id': ackId,
      'ack_for_packet_id': ackForPacketId,
      'ack_for_message_id': ackForMessageId,
      'channel_id': channelId,
      'received_from_user_id': receivedFromUserId,
      'received_at': receivedAt.toIso8601String(),
    };
  }
}
