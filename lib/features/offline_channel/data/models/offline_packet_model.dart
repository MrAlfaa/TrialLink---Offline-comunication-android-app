class OfflinePacketModel {
  const OfflinePacketModel({
    required this.packetId,
    required this.channelId,
    required this.channelCode,
    required this.packetType,
    required this.senderId,
    required this.payloadJson,
    required this.createdAt,
    this.priority = 'normal',
    this.ttl = 5,
    this.hopCount = 0,
    this.packetStatus = 'local_created',
  });

  final String packetId;
  final String channelId;
  final String channelCode;
  final String packetType;
  final String senderId;
  final String payloadJson;
  final String priority;
  final int ttl;
  final int hopCount;
  final String packetStatus;
  final DateTime createdAt;

  factory OfflinePacketModel.fromDb(Map<String, Object?> row) {
    return OfflinePacketModel(
      packetId: row['packet_id'].toString(),
      channelId: row['channel_id'].toString(),
      channelCode: row['channel_code'].toString(),
      packetType: row['packet_type'].toString(),
      senderId: row['sender_id'].toString(),
      payloadJson: row['payload_json'].toString(),
      priority: row['priority']?.toString() ?? 'normal',
      ttl: int.tryParse(row['ttl']?.toString() ?? '') ?? 5,
      hopCount: int.tryParse(row['hop_count']?.toString() ?? '') ?? 0,
      packetStatus: row['packet_status']?.toString() ?? 'local_created',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'packet_id': packetId,
      'channel_id': channelId,
      'channel_code': channelCode,
      'packet_type': packetType,
      'sender_id': senderId,
      'payload_json': payloadJson,
      'priority': priority,
      'ttl': ttl,
      'hop_count': hopCount,
      'packet_status': packetStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
