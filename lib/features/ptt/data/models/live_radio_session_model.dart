class LiveRadioSessionModel {
  const LiveRadioSessionModel({
    required this.streamId,
    required this.offlineChannelId,
    required this.channelCode,
    required this.senderLocalId,
    required this.senderName,
    required this.startedAt,
    this.endedAt,
    this.durationMs,
    this.chunkCount = 0,
    this.status = 'started',
    this.lastError,
  });

  final String streamId;
  final String offlineChannelId;
  final String channelCode;
  final String senderLocalId;
  final String senderName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final int chunkCount;
  final String status;
  final String? lastError;

  factory LiveRadioSessionModel.fromDb(Map<String, Object?> row) {
    return LiveRadioSessionModel(
      streamId: row['stream_id'].toString(),
      offlineChannelId: row['offline_channel_id'].toString(),
      channelCode: row['channel_code'].toString(),
      senderLocalId: row['sender_local_id'].toString(),
      senderName: row['sender_name'].toString(),
      startedAt: DateTime.tryParse(row['started_at']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(row['ended_at']?.toString() ?? ''),
      durationMs: int.tryParse(row['duration_ms']?.toString() ?? ''),
      chunkCount: int.tryParse(row['chunk_count']?.toString() ?? '') ?? 0,
      status: row['status']?.toString() ?? 'started',
      lastError: row['last_error']?.toString(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'stream_id': streamId,
      'offline_channel_id': offlineChannelId,
      'channel_code': channelCode,
      'sender_local_id': senderLocalId,
      'sender_name': senderName,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_ms': durationMs,
      'chunk_count': chunkCount,
      'status': status,
      'last_error': lastError,
    };
  }

  LiveRadioSessionModel copyWith({
    DateTime? endedAt,
    int? durationMs,
    int? chunkCount,
    String? status,
    String? lastError,
  }) {
    return LiveRadioSessionModel(
      streamId: streamId,
      offlineChannelId: offlineChannelId,
      channelCode: channelCode,
      senderLocalId: senderLocalId,
      senderName: senderName,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      chunkCount: chunkCount ?? this.chunkCount,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }
}
