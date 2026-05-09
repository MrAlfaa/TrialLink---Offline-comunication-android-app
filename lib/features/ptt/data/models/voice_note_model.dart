class VoiceNoteModel {
  const VoiceNoteModel({
    required this.localVoiceId,
    required this.senderId,
    required this.senderName,
    required this.isMine,
    required this.deliveryMode,
    required this.deliveryStatus,
    required this.ackStatus,
    required this.createdAt,
    required this.syncState,
    this.serverVoiceId,
    this.groupId,
    this.offlineChannelId,
    this.channelCode,
    this.localFilePath,
    this.remoteAudioUrl,
    this.durationMs,
    this.fileSizeBytes,
    this.updatedAt,
  });

  final String localVoiceId;
  final String? serverVoiceId;
  final String? groupId;
  final String? offlineChannelId;
  final String? channelCode;
  final String senderId;
  final String senderName;
  final String? localFilePath;
  final String? remoteAudioUrl;
  final int? durationMs;
  final int? fileSizeBytes;
  final bool isMine;
  final String deliveryMode;
  final String deliveryStatus;
  final String ackStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String syncState;

  factory VoiceNoteModel.fromDb(Map<String, Object?> row) {
    return VoiceNoteModel(
      localVoiceId: row['local_voice_id'].toString(),
      serverVoiceId: row['server_voice_id']?.toString(),
      groupId: row['group_id']?.toString(),
      offlineChannelId: row['offline_channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      senderId: row['sender_id'].toString(),
      senderName: row['sender_name'].toString(),
      localFilePath: row['local_file_path']?.toString(),
      remoteAudioUrl: row['remote_audio_url']?.toString(),
      durationMs: int.tryParse(row['duration_ms']?.toString() ?? ''),
      fileSizeBytes: int.tryParse(row['file_size_bytes']?.toString() ?? ''),
      isMine: row['is_mine'] == 1,
      deliveryMode: row['delivery_mode']?.toString() ?? 'offline',
      deliveryStatus: row['delivery_status']?.toString() ?? 'pending',
      ackStatus: row['ack_status']?.toString() ?? 'none',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      syncState: _normalizeSyncState(row['sync_state']?.toString()),
    );
  }

  factory VoiceNoteModel.fromApiJson(
    Map<String, dynamic> data, {
    required String currentUserId,
  }) {
    final sender = data['sender'] as Map<String, dynamic>? ?? {};
    return VoiceNoteModel(
      localVoiceId: data['clientVoiceId'].toString(),
      serverVoiceId: data['voiceNoteId']?.toString(),
      groupId: data['groupId']?.toString(),
      senderId: sender['id']?.toString() ?? '',
      senderName: sender['fullName']?.toString() ?? 'TrailLink User',
      remoteAudioUrl: data['audioUrl']?.toString(),
      durationMs: int.tryParse(data['durationMs']?.toString() ?? ''),
      fileSizeBytes: int.tryParse(data['fileSizeBytes']?.toString() ?? ''),
      isMine: sender['id']?.toString() == currentUserId,
      deliveryMode: 'online',
      deliveryStatus:
          sender['id']?.toString() == currentUserId ? 'sent' : 'received',
      ackStatus: 'none',
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      syncState: 'synced',
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'local_voice_id': localVoiceId,
      'server_voice_id': serverVoiceId,
      'group_id': groupId,
      'offline_channel_id': offlineChannelId,
      'channel_code': channelCode,
      'sender_id': senderId,
      'sender_name': senderName,
      'local_file_path': localFilePath,
      'remote_audio_url': remoteAudioUrl,
      'duration_ms': durationMs,
      'file_size_bytes': fileSizeBytes,
      'is_mine': isMine ? 1 : 0,
      'delivery_mode': deliveryMode,
      'delivery_status': deliveryStatus,
      'ack_status': ackStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_state': syncState,
    };
  }

  VoiceNoteModel copyWith({
    String? serverVoiceId,
    String? localFilePath,
    String? remoteAudioUrl,
    int? durationMs,
    int? fileSizeBytes,
    String? deliveryStatus,
    String? ackStatus,
    String? syncState,
  }) {
    return VoiceNoteModel(
      localVoiceId: localVoiceId,
      serverVoiceId: serverVoiceId ?? this.serverVoiceId,
      groupId: groupId,
      offlineChannelId: offlineChannelId,
      channelCode: channelCode,
      senderId: senderId,
      senderName: senderName,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteAudioUrl: remoteAudioUrl ?? this.remoteAudioUrl,
      durationMs: durationMs ?? this.durationMs,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isMine: isMine,
      deliveryMode: deliveryMode,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      ackStatus: ackStatus ?? this.ackStatus,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      syncState: syncState ?? this.syncState,
    );
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
