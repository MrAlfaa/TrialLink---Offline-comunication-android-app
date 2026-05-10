class OfflineTextMessageModel {
  const OfflineTextMessageModel({
    required this.messageId,
    required this.packetId,
    required this.channelId,
    required this.channelCode,
    this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.isMine,
    required this.deliveryStatus,
    required this.ackStatus,
    required this.ttl,
    required this.hopCount,
    required this.createdAt,
    this.sourcePath = 'offline',
    this.originLocalId,
    this.originIdentityType,
    this.bridgedByName,
    this.updatedAt,
  });

  final String messageId;
  final String packetId;
  final String channelId;
  final String channelCode;
  final String? chatId;
  final String senderId;
  final String senderName;
  final String content;
  final bool isMine;
  final String deliveryStatus;
  final String ackStatus;
  final int ttl;
  final int hopCount;
  final DateTime createdAt;
  final String sourcePath;
  final String? originLocalId;
  final String? originIdentityType;
  final String? bridgedByName;
  final DateTime? updatedAt;

  bool get isDelivered => deliveryStatus == 'delivered';

  OfflineTextMessageModel copyWith({
    String? deliveryStatus,
    String? ackStatus,
    DateTime? updatedAt,
  }) {
    return OfflineTextMessageModel(
      messageId: messageId,
      packetId: packetId,
      channelId: channelId,
      channelCode: channelCode,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      isMine: isMine,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      ackStatus: ackStatus ?? this.ackStatus,
      ttl: ttl,
      hopCount: hopCount,
      createdAt: createdAt,
      sourcePath: sourcePath,
      originLocalId: originLocalId,
      originIdentityType: originIdentityType,
      bridgedByName: bridgedByName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory OfflineTextMessageModel.fromDb(Map<String, Object?> row) {
    return OfflineTextMessageModel(
      messageId: row['message_id'].toString(),
      packetId: row['packet_id'].toString(),
      channelId: row['channel_id'].toString(),
      channelCode: row['channel_code'].toString(),
      chatId: row['chat_id']?.toString(),
      senderId: row['sender_id'].toString(),
      senderName: row['sender_name'].toString(),
      content: row['content'].toString(),
      isMine: row['is_mine'] == 1,
      deliveryStatus: row['delivery_status'].toString(),
      ackStatus: row['ack_status'].toString(),
      ttl: int.tryParse(row['ttl']?.toString() ?? '') ?? 5,
      hopCount: int.tryParse(row['hop_count']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      sourcePath: row['source_path']?.toString() ?? 'offline',
      originLocalId: row['origin_local_id']?.toString(),
      originIdentityType: row['origin_identity_type']?.toString(),
      bridgedByName: row['bridged_by_name']?.toString(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'message_id': messageId,
      'packet_id': packetId,
      'channel_id': channelId,
      'channel_code': channelCode,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'is_mine': isMine ? 1 : 0,
      'delivery_status': deliveryStatus,
      'ack_status': ackStatus,
      'ttl': ttl,
      'hop_count': hopCount,
      'created_at': createdAt.toIso8601String(),
      'source_path': sourcePath,
      'origin_local_id': originLocalId,
      'origin_identity_type': originIdentityType,
      'bridged_by_name': bridgedByName,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
