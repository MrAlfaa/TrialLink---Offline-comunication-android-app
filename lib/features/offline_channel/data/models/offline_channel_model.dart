class OfflineChannelModel {
  const OfflineChannelModel({
    required this.channelId,
    required this.channelCode,
    required this.channelName,
    required this.createdByUserId,
    required this.createdAt,
    this.tripId,
    this.description,
    this.createdByName,
    this.channelKeyHash,
    this.isPrimary = false,
    this.isActive = false,
    this.channelStatus = 'active',
    this.endedAt,
    this.endedByUserId,
    this.endedReason,
    this.updatedAt,
    this.lastOpenedAt,
  });

  final String channelId;
  final String channelCode;
  final String channelName;
  final String? tripId;
  final String? description;
  final String createdByUserId;
  final String? createdByName;
  final String? channelKeyHash;
  final bool isPrimary;
  final bool isActive;
  final String channelStatus;
  final DateTime? endedAt;
  final String? endedByUserId;
  final String? endedReason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastOpenedAt;

  bool get isEnded => channelStatus == 'ended';
  bool get isUsable => channelStatus == 'active' || channelStatus == 'inactive';

  factory OfflineChannelModel.fromDb(Map<String, Object?> row) {
    return OfflineChannelModel(
      channelId: row['channel_id'].toString(),
      channelCode: row['channel_code'].toString(),
      channelName: row['channel_name'].toString(),
      tripId: row['trip_id']?.toString(),
      description: row['description']?.toString(),
      createdByUserId: row['created_by_user_id'].toString(),
      createdByName: row['created_by_name']?.toString(),
      channelKeyHash: row['channel_key_hash']?.toString(),
      isPrimary: row['is_primary'] == 1,
      isActive: row['is_active'] == 1,
      channelStatus: row['channel_status']?.toString() ?? 'active',
      endedAt: DateTime.tryParse(row['ended_at']?.toString() ?? ''),
      endedByUserId: row['ended_by_user_id']?.toString(),
      endedReason: row['ended_reason']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      lastOpenedAt: DateTime.tryParse(row['last_opened_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'channel_id': channelId,
      'channel_code': channelCode,
      'channel_name': channelName,
      'trip_id': tripId,
      'description': description,
      'created_by_user_id': createdByUserId,
      'created_by_name': createdByName,
      'channel_key_hash': channelKeyHash,
      'is_primary': isPrimary ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'channel_status': channelStatus,
      'ended_at': endedAt?.toIso8601String(),
      'ended_by_user_id': endedByUserId,
      'ended_reason': endedReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'last_opened_at': lastOpenedAt?.toIso8601String(),
    };
  }

  OfflineChannelModel copyWith({
    String? tripId,
    bool clearTripId = false,
    bool? isPrimary,
    bool? isActive,
    String? channelStatus,
    DateTime? endedAt,
    String? endedByUserId,
    String? endedReason,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
  }) {
    return OfflineChannelModel(
      channelId: channelId,
      channelCode: channelCode,
      channelName: channelName,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      tripId: clearTripId ? null : tripId ?? this.tripId,
      description: description,
      createdByName: createdByName,
      channelKeyHash: channelKeyHash,
      isPrimary: isPrimary ?? this.isPrimary,
      isActive: isActive ?? this.isActive,
      channelStatus: channelStatus ?? this.channelStatus,
      endedAt: endedAt ?? this.endedAt,
      endedByUserId: endedByUserId ?? this.endedByUserId,
      endedReason: endedReason ?? this.endedReason,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
