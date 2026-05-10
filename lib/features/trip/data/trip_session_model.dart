class TripSessionModel {
  const TripSessionModel({
    this.id,
    required this.tripId,
    required this.tripName,
    required this.mode,
    this.cloudGroupId,
    this.cloudGroupName,
    this.offlineChannelId,
    this.activeChannelId,
    this.channelCode,
    this.channelName,
    required this.localIdentityId,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.syncState,
    required this.createdAt,
    this.lastOpenedAt,
    this.updatedAt,
  });

  final int? id;
  final String tripId;
  final String tripName;
  final String mode;
  final String? cloudGroupId;
  final String? cloudGroupName;
  final String? offlineChannelId;
  final String? activeChannelId;
  final String? channelCode;
  final String? channelName;
  final String localIdentityId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String syncState;
  final DateTime createdAt;
  final DateTime? lastOpenedAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';
  bool get isOffline => mode == 'offline';
  bool get isOnline => mode == 'online';

  factory TripSessionModel.fromDb(Map<String, Object?> row) {
    return TripSessionModel(
      id: row['id'] as int?,
      tripId: row['trip_id'].toString(),
      tripName: row['trip_name'].toString(),
      mode: row['mode'].toString(),
      cloudGroupId: row['cloud_group_id']?.toString(),
      cloudGroupName: row['cloud_group_name']?.toString(),
      offlineChannelId: row['offline_channel_id']?.toString(),
      activeChannelId: row['active_channel_id']?.toString() ??
          row['offline_channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      channelName: row['channel_name']?.toString(),
      localIdentityId: row['local_identity_id'].toString(),
      status: row['status'].toString(),
      startedAt: DateTime.tryParse(row['started_at']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(row['ended_at']?.toString() ?? ''),
      syncState: row['sync_state'].toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      lastOpenedAt: DateTime.tryParse(row['last_opened_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'trip_id': tripId,
      'trip_name': tripName,
      'mode': mode,
      'cloud_group_id': cloudGroupId,
      'cloud_group_name': cloudGroupName,
      'offline_channel_id': offlineChannelId,
      'active_channel_id': activeChannelId ?? offlineChannelId,
      'channel_code': channelCode,
      'channel_name': channelName,
      'local_identity_id': localIdentityId,
      'status': status,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'sync_state': syncState,
      'created_at': createdAt.toIso8601String(),
      'last_opened_at': lastOpenedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
