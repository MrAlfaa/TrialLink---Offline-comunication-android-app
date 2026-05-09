class LocationUpdateModel {
  const LocationUpdateModel({
    required this.localLocationId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.source,
    required this.shareStatus,
    required this.syncState,
    required this.createdAt,
    this.serverLocationId,
    this.groupId,
    this.offlineChannelId,
    this.channelCode,
    this.userName,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
  });

  final String localLocationId;
  final String? serverLocationId;
  final String? groupId;
  final String? offlineChannelId;
  final String? channelCode;
  final String userId;
  final String? userName;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime capturedAt;
  final String source;
  final String shareStatus;
  final String syncState;
  final DateTime createdAt;

  LocationUpdateModel copyWith({
    String? serverLocationId,
    String? shareStatus,
    String? syncState,
  }) {
    return LocationUpdateModel(
      localLocationId: localLocationId,
      serverLocationId: serverLocationId ?? this.serverLocationId,
      groupId: groupId,
      offlineChannelId: offlineChannelId,
      channelCode: channelCode,
      userId: userId,
      userName: userName,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      speed: speed,
      heading: heading,
      capturedAt: capturedAt,
      source: source,
      shareStatus: shareStatus ?? this.shareStatus,
      syncState: syncState ?? this.syncState,
      createdAt: createdAt,
    );
  }

  factory LocationUpdateModel.fromDb(Map<String, Object?> row) {
    return LocationUpdateModel(
      localLocationId: row['local_location_id'].toString(),
      serverLocationId: row['server_location_id']?.toString(),
      groupId: row['group_id']?.toString(),
      offlineChannelId: row['offline_channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      userId: row['user_id'].toString(),
      userName: row['user_name']?.toString(),
      latitude: double.parse(row['latitude'].toString()),
      longitude: double.parse(row['longitude'].toString()),
      accuracy: _nullableDouble(row['accuracy']),
      altitude: _nullableDouble(row['altitude']),
      speed: _nullableDouble(row['speed']),
      heading: _nullableDouble(row['heading']),
      capturedAt: DateTime.tryParse(row['captured_at']?.toString() ?? '') ??
          DateTime.now(),
      source: row['source']?.toString() ?? 'gps',
      shareStatus: row['share_status']?.toString() ?? 'local_only',
      syncState: _normalizeSyncState(row['sync_state']?.toString()),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  factory LocationUpdateModel.fromApiJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return LocationUpdateModel(
      localLocationId:
          json['clientLocationId']?.toString() ?? json['id'].toString(),
      serverLocationId: json['id']?.toString(),
      groupId: json['groupId']?.toString(),
      userId: user['id']?.toString() ?? currentUserId,
      userName: user['fullName']?.toString(),
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: _nullableDouble(json['accuracy']),
      altitude: _nullableDouble(json['altitude']),
      speed: _nullableDouble(json['speed']),
      heading: _nullableDouble(json['heading']),
      capturedAt: DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
          DateTime.now(),
      source: 'backend',
      shareStatus: 'shared',
      syncState: 'synced',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'local_location_id': localLocationId,
      'server_location_id': serverLocationId,
      'group_id': groupId,
      'offline_channel_id': offlineChannelId,
      'channel_code': channelCode,
      'user_id': userId,
      'user_name': userName,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'captured_at': capturedAt.toIso8601String(),
      'source': source,
      'share_status': shareStatus,
      'sync_state': syncState,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'clientLocationId': localLocationId,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  static double? _nullableDouble(Object? value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  static String _normalizeSyncState(String? value) {
    return switch (value) {
      'server_synced' => 'synced',
      'completed' => 'synced',
      'pending' => 'needs_sync',
      'error' => 'failed',
      'local_only' => 'local_only',
      'needs_sync' => 'needs_sync',
      'synced' => 'synced',
      'failed' => 'failed',
      _ => 'local_only',
    };
  }
}
