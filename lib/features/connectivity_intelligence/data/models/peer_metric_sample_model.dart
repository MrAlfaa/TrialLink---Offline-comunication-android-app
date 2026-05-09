class PeerMetricSampleModel {
  const PeerMetricSampleModel({
    required this.endpointId,
    required this.connectionStatus,
    required this.lastSeenAt,
    required this.sampleSource,
    required this.createdAt,
    this.userId,
    this.displayName,
    this.channelId,
    this.channelCode,
    this.rssi,
    this.ackRttMs,
    this.packetSuccessRate,
    this.retryCount = 0,
    this.disconnectCount = 0,
  });

  final String endpointId;
  final String? userId;
  final String? displayName;
  final String? channelId;
  final String? channelCode;
  final int? rssi;
  final int? ackRttMs;
  final double? packetSuccessRate;
  final int retryCount;
  final int disconnectCount;
  final String connectionStatus;
  final DateTime lastSeenAt;
  final String sampleSource;
  final DateTime createdAt;

  factory PeerMetricSampleModel.fromDb(Map<String, Object?> row) {
    return PeerMetricSampleModel(
      endpointId: row['endpoint_id'].toString(),
      userId: row['user_id']?.toString(),
      displayName: row['display_name']?.toString(),
      channelId: row['channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      rssi: row['rssi'] is int ? row['rssi'] as int : null,
      ackRttMs: row['ack_rtt_ms'] is int ? row['ack_rtt_ms'] as int : null,
      packetSuccessRate: row['packet_success_rate'] == null
          ? null
          : double.tryParse(row['packet_success_rate'].toString()),
      retryCount: int.tryParse(row['retry_count']?.toString() ?? '') ?? 0,
      disconnectCount:
          int.tryParse(row['disconnect_count']?.toString() ?? '') ?? 0,
      connectionStatus: row['connection_status']?.toString() ?? 'unknown',
      lastSeenAt: DateTime.tryParse(row['last_seen_at']?.toString() ?? '') ??
          DateTime.now(),
      sampleSource: row['sample_source']?.toString() ?? 'heartbeat',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'endpoint_id': endpointId,
      'user_id': userId,
      'display_name': displayName,
      'channel_id': channelId,
      'channel_code': channelCode,
      'rssi': rssi,
      'ack_rtt_ms': ackRttMs,
      'packet_success_rate': packetSuccessRate,
      'retry_count': retryCount,
      'disconnect_count': disconnectCount,
      'connection_status': connectionStatus,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'sample_source': sampleSource,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
