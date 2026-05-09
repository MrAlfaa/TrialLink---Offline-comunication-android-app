class EmergencyEventModel {
  const EmergencyEventModel({
    required this.localEventId,
    required this.alertType,
    required this.priority,
    required this.status,
    required this.deliveryMode,
    required this.ackStatus,
    required this.retryCount,
    required this.createdAt,
    required this.syncState,
    this.serverEventId,
    this.groupId,
    this.offlineChannelId,
    this.channelCode,
    this.message,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationCapturedAt,
    this.updatedAt,
  });

  final String localEventId;
  final String? serverEventId;
  final String? groupId;
  final String? offlineChannelId;
  final String? channelCode;
  final String alertType;
  final String? message;
  final String priority;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? locationCapturedAt;
  final String status;
  final String deliveryMode;
  final String ackStatus;
  final int retryCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String syncState;

  EmergencyEventModel copyWith({
    String? serverEventId,
    String? status,
    String? ackStatus,
    int? retryCount,
    String? syncState,
  }) {
    return EmergencyEventModel(
      localEventId: localEventId,
      serverEventId: serverEventId ?? this.serverEventId,
      groupId: groupId,
      offlineChannelId: offlineChannelId,
      channelCode: channelCode,
      alertType: alertType,
      message: message,
      priority: priority,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      locationCapturedAt: locationCapturedAt,
      status: status ?? this.status,
      deliveryMode: deliveryMode,
      ackStatus: ackStatus ?? this.ackStatus,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      syncState: syncState ?? this.syncState,
    );
  }

  factory EmergencyEventModel.fromDb(Map<String, Object?> row) {
    return EmergencyEventModel(
      localEventId: row['local_event_id'].toString(),
      serverEventId: row['server_event_id']?.toString(),
      groupId: row['group_id']?.toString(),
      offlineChannelId: row['offline_channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      alertType: row['alert_type']?.toString() ?? 'sos',
      message: row['message']?.toString(),
      priority: row['priority']?.toString() ?? 'emergency',
      latitude: _nullableDouble(row['latitude']),
      longitude: _nullableDouble(row['longitude']),
      accuracy: _nullableDouble(row['accuracy']),
      locationCapturedAt:
          DateTime.tryParse(row['location_captured_at']?.toString() ?? ''),
      status: row['status']?.toString() ?? 'pending',
      deliveryMode: row['delivery_mode']?.toString() ?? 'offline',
      ackStatus: row['ack_status']?.toString() ?? 'waiting',
      retryCount: int.tryParse(row['retry_count']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      syncState: _normalizeSyncState(row['sync_state']?.toString()),
    );
  }

  factory EmergencyEventModel.fromApiJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>?;
    return EmergencyEventModel(
      localEventId: json['clientEventId']?.toString() ?? json['id'].toString(),
      serverEventId: json['id']?.toString(),
      groupId: json['groupId']?.toString(),
      alertType: json['alertType']?.toString() ?? 'sos',
      message: json['message']?.toString(),
      priority: json['priority']?.toString() ?? 'emergency',
      latitude: _nullableDouble(location?['latitude']),
      longitude: _nullableDouble(location?['longitude']),
      accuracy: _nullableDouble(location?['accuracy']),
      locationCapturedAt:
          DateTime.tryParse(location?['capturedAt']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'active',
      deliveryMode: 'online',
      ackStatus: (json['acknowledgements'] as List? ?? []).isEmpty
          ? 'waiting'
          : 'acknowledged',
      retryCount: 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      syncState: 'synced',
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'local_event_id': localEventId,
      'server_event_id': serverEventId,
      'group_id': groupId,
      'offline_channel_id': offlineChannelId,
      'channel_code': channelCode,
      'alert_type': alertType,
      'message': message,
      'priority': priority,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_captured_at': locationCapturedAt?.toIso8601String(),
      'status': status,
      'delivery_mode': deliveryMode,
      'ack_status': ackStatus,
      'retry_count': retryCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_state': syncState,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'clientEventId': localEventId,
      'alertType': alertType,
      'message': message ?? '',
      if (latitude != null && longitude != null)
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
          'capturedAt': (locationCapturedAt ?? createdAt).toIso8601String(),
        },
      'createdAt': createdAt.toIso8601String(),
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
