class OfflineChannelMemberModel {
  const OfflineChannelMemberModel({
    required this.channelId,
    required this.userId,
    required this.displayName,
    required this.memberRole,
    required this.source,
    required this.status,
    required this.joinedAt,
    this.membershipStatus = 'active',
    this.presenceStatus = 'unknown',
    this.connectionStatus = 'disconnected',
    this.endpointId,
    this.identityType = 'guest',
    this.lastSeenAt,
  });

  final String channelId;
  final String userId;
  final String displayName;
  final String memberRole;
  final String source;
  final String status;
  final String membershipStatus;
  final String presenceStatus;
  final String connectionStatus;
  final String? endpointId;
  final String identityType;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;

  factory OfflineChannelMemberModel.fromDb(Map<String, Object?> row) {
    final legacyStatus = row['status']?.toString() ?? 'active';
    return OfflineChannelMemberModel(
      channelId: row['channel_id'].toString(),
      userId: row['user_id'].toString(),
      displayName: row['display_name'].toString(),
      memberRole: row['member_role'].toString(),
      source: row['source'].toString(),
      status: legacyStatus,
      membershipStatus: row['membership_status']?.toString() ?? legacyStatus,
      presenceStatus: row['presence_status']?.toString() ?? 'unknown',
      connectionStatus: row['connection_status']?.toString() ?? 'disconnected',
      endpointId: row['endpoint_id']?.toString(),
      identityType: row['identity_type']?.toString() ?? 'guest',
      joinedAt: DateTime.tryParse(row['joined_at']?.toString() ?? '') ??
          DateTime.now(),
      lastSeenAt: DateTime.tryParse(row['last_seen_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'channel_id': channelId,
      'user_id': userId,
      'display_name': displayName,
      'member_role': memberRole,
      'source': source,
      'status': membershipStatus,
      'membership_status': membershipStatus,
      'presence_status': presenceStatus,
      'connection_status': connectionStatus,
      'endpoint_id': endpointId,
      'identity_type': identityType,
      'joined_at': joinedAt.toIso8601String(),
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }

  OfflineChannelMemberModel copyWith({
    String? channelId,
    String? userId,
    String? displayName,
    String? memberRole,
    String? source,
    String? status,
    String? membershipStatus,
    String? presenceStatus,
    String? connectionStatus,
    String? endpointId,
    String? identityType,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
  }) {
    return OfflineChannelMemberModel(
      channelId: channelId ?? this.channelId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      memberRole: memberRole ?? this.memberRole,
      source: source ?? this.source,
      status: status ?? this.status,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      endpointId: endpointId ?? this.endpointId,
      identityType: identityType ?? this.identityType,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
