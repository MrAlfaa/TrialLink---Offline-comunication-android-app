class ChatRoomModel {
  const ChatRoomModel({
    this.id,
    required this.chatId,
    required this.tripId,
    this.channelId,
    this.cloudGroupId,
    required this.chatName,
    required this.chatType,
    this.isDefault = false,
    this.isActive = false,
    this.chatStatus = 'active',
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String chatId;
  final String tripId;
  final String? channelId;
  final String? cloudGroupId;
  final String chatName;
  final String chatType;
  final bool isDefault;
  final bool isActive;
  final String chatStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isReadOnly => chatStatus == 'read_only' || chatStatus == 'archived';

  factory ChatRoomModel.fromDb(Map<String, Object?> row) {
    return ChatRoomModel(
      id: row['id'] as int?,
      chatId: row['chat_id'].toString(),
      tripId: row['trip_id'].toString(),
      channelId: row['channel_id']?.toString(),
      cloudGroupId: row['cloud_group_id']?.toString(),
      chatName: row['chat_name']?.toString() ?? 'General',
      chatType: row['chat_type']?.toString() ?? 'trip_general',
      isDefault: row['is_default'] == 1,
      isActive: row['is_active'] == 1,
      chatStatus: row['chat_status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'chat_id': chatId,
      'trip_id': tripId,
      'channel_id': channelId,
      'cloud_group_id': cloudGroupId,
      'chat_name': chatName,
      'chat_type': chatType,
      'is_default': isDefault ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'chat_status': chatStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
