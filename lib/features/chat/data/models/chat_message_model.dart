class ChatMessageModel {
  const ChatMessageModel({
    required this.localId,
    required this.clientMessageId,
    required this.groupId,
    this.tripId,
    this.channelId,
    this.chatId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.content,
    required this.deliveryStatus,
    required this.isMine,
    required this.createdAt,
    this.serverId,
    this.offlineChannelId,
    this.chatContextType = 'cloud_group',
    this.senderLocalId,
    this.updatedAt,
    this.syncState = 'needs_sync',
    this.sourcePath = 'online',
    this.originLocalId,
    this.originIdentityType,
    this.bridgedByName,
    this.localFilePath,
    this.remoteUrl,
    this.thumbnailPath,
    this.fileName,
    this.fileSizeBytes,
    this.mimeType,
    this.durationMs,
    this.uploadStatus = 'not_required',
  });

  final String localId;
  final String? serverId;
  final String clientMessageId;
  final String groupId;
  final String? tripId;
  final String? channelId;
  final String? chatId;
  final String? offlineChannelId;
  final String chatContextType;
  final String senderId;
  final String? senderLocalId;
  final String senderName;
  final String messageType;
  final String content;
  final String deliveryStatus;
  final bool isMine;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String syncState;
  final String sourcePath;
  final String? originLocalId;
  final String? originIdentityType;
  final String? bridgedByName;
  final String? localFilePath;
  final String? remoteUrl;
  final String? thumbnailPath;
  final String? fileName;
  final int? fileSizeBytes;
  final String? mimeType;
  final int? durationMs;
  final String uploadStatus;

  bool get isMedia =>
      messageType == 'image' || messageType == 'voice' || messageType == 'file';
  bool get isUploadPending =>
      uploadStatus == 'pending' || uploadStatus == 'uploading';

  ChatMessageModel copyWith({
    String? localId,
    String? serverId,
    String? clientMessageId,
    String? groupId,
    String? tripId,
    String? channelId,
    String? chatId,
    String? offlineChannelId,
    String? chatContextType,
    String? senderId,
    String? senderLocalId,
    String? senderName,
    String? messageType,
    String? content,
    String? deliveryStatus,
    bool? isMine,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncState,
    String? sourcePath,
    String? originLocalId,
    String? originIdentityType,
    String? bridgedByName,
    String? localFilePath,
    String? remoteUrl,
    String? thumbnailPath,
    String? fileName,
    int? fileSizeBytes,
    String? mimeType,
    int? durationMs,
    String? uploadStatus,
  }) {
    return ChatMessageModel(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      groupId: groupId ?? this.groupId,
      tripId: tripId ?? this.tripId,
      channelId: channelId ?? this.channelId,
      chatId: chatId ?? this.chatId,
      offlineChannelId: offlineChannelId ?? this.offlineChannelId,
      chatContextType: chatContextType ?? this.chatContextType,
      senderId: senderId ?? this.senderId,
      senderLocalId: senderLocalId ?? this.senderLocalId,
      senderName: senderName ?? this.senderName,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isMine: isMine ?? this.isMine,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      sourcePath: sourcePath ?? this.sourcePath,
      originLocalId: originLocalId ?? this.originLocalId,
      originIdentityType: originIdentityType ?? this.originIdentityType,
      bridgedByName: bridgedByName ?? this.bridgedByName,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      durationMs: durationMs ?? this.durationMs,
      uploadStatus: uploadStatus ?? this.uploadStatus,
    );
  }

  factory ChatMessageModel.fromApiJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final sender = json['sender'] as Map<String, dynamic>? ?? {};
    final senderId = sender['id']?.toString() ?? '';
    final clientMessageId =
        json['clientMessageId']?.toString() ?? json['id'].toString();

    return ChatMessageModel(
      localId: clientMessageId,
      serverId: json['id']?.toString(),
      clientMessageId: clientMessageId,
      groupId: json['groupId']?.toString() ?? '',
      tripId: json['tripId']?.toString(),
      channelId: json['channelId']?.toString(),
      chatId: json['chatId']?.toString(),
      offlineChannelId: json['offlineChannelId']?.toString(),
      chatContextType: json['chatContextType']?.toString() ?? 'cloud_group',
      senderId: senderId,
      senderLocalId: json['senderLocalId']?.toString(),
      senderName: sender['fullName']?.toString() ?? 'TrailLink User',
      messageType: json['messageType']?.toString() ?? 'text',
      content: json['content']?.toString() ?? '',
      deliveryStatus: 'synced',
      isMine: senderId == currentUserId,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      syncState: 'synced',
      sourcePath: json['sourcePath']?.toString() ?? 'online',
      originLocalId: json['originLocalId']?.toString(),
      originIdentityType: json['originIdentityType']?.toString(),
      bridgedByName: json['bridgedByName']?.toString(),
      remoteUrl: json['mediaUrl']?.toString(),
      thumbnailPath: json['thumbnailUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      fileSizeBytes: int.tryParse(json['fileSizeBytes']?.toString() ?? ''),
      mimeType: json['mimeType']?.toString(),
      durationMs: int.tryParse(json['durationMs']?.toString() ?? ''),
      uploadStatus: json['mediaUrl'] == null ? 'not_required' : 'uploaded',
    );
  }

  factory ChatMessageModel.fromDb(Map<String, Object?> row) {
    return ChatMessageModel(
      localId: row['local_id'].toString(),
      serverId: row['server_id']?.toString(),
      clientMessageId: row['client_message_id'].toString(),
      groupId: row['group_id'].toString(),
      tripId: row['trip_id']?.toString(),
      channelId: row['channel_id']?.toString(),
      chatId: row['chat_id']?.toString(),
      offlineChannelId: row['offline_channel_id']?.toString(),
      chatContextType: row['chat_context_type']?.toString() ?? 'cloud_group',
      senderId: row['sender_id'].toString(),
      senderLocalId: row['sender_local_id']?.toString(),
      senderName: row['sender_name']?.toString() ?? 'TrailLink User',
      messageType: row['message_type']?.toString() ?? 'text',
      content: row['content']?.toString() ?? '',
      deliveryStatus: row['delivery_status']?.toString() ?? 'pending',
      isMine: row['is_mine'] == 1,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      syncState: _normalizeSyncState(row['sync_state']?.toString()),
      sourcePath: row['source_path']?.toString() ?? 'online',
      originLocalId: row['origin_local_id']?.toString(),
      originIdentityType: row['origin_identity_type']?.toString(),
      bridgedByName: row['bridged_by_name']?.toString(),
      localFilePath: row['local_file_path']?.toString(),
      remoteUrl: row['remote_url']?.toString(),
      thumbnailPath: row['thumbnail_path']?.toString(),
      fileName: row['file_name']?.toString(),
      fileSizeBytes: int.tryParse(row['file_size_bytes']?.toString() ?? ''),
      mimeType: row['mime_type']?.toString(),
      durationMs: int.tryParse(row['duration_ms']?.toString() ?? ''),
      uploadStatus: row['upload_status']?.toString() ??
          (row['message_type']?.toString() == 'text'
              ? 'not_required'
              : 'pending'),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'client_message_id': clientMessageId,
      'group_id': groupId,
      'trip_id': tripId,
      'channel_id': channelId,
      'chat_id': chatId,
      'offline_channel_id': offlineChannelId,
      'chat_context_type': chatContextType,
      'sender_id': senderId,
      'sender_local_id': senderLocalId,
      'sender_name': senderName,
      'message_type': messageType,
      'content': content,
      'delivery_status': deliveryStatus,
      'is_mine': isMine ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'sync_state': syncState,
      'created_locally': isMine ? 1 : 0,
      'source_path': sourcePath,
      'origin_local_id': originLocalId,
      'origin_identity_type': originIdentityType,
      'bridged_by_name': bridgedByName,
      'local_file_path': localFilePath,
      'remote_url': remoteUrl,
      'thumbnail_path': thumbnailPath,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'duration_ms': durationMs,
      'upload_status': uploadStatus,
    };
  }

  Map<String, dynamic> toSyncJson() {
    return {
      'clientMessageId': clientMessageId,
      if (tripId != null) 'tripId': tripId,
      if (channelId != null) 'channelId': channelId,
      if (chatId != null) 'chatId': chatId,
      'content': content,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
      'sourcePath': sourcePath,
      if (senderLocalId != null) 'senderLocalId': senderLocalId,
      if (offlineChannelId != null) 'offlineChannelId': offlineChannelId,
      'chatContextType': chatContextType,
      if (originLocalId != null) 'originLocalId': originLocalId,
      if (originIdentityType != null) 'originIdentityType': originIdentityType,
      if (bridgedByName != null) 'bridgedByName': bridgedByName,
      if (remoteUrl != null) 'mediaUrl': remoteUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      if (mimeType != null) 'mimeType': mimeType,
      if (durationMs != null) 'durationMs': durationMs,
    };
  }

  static ChatMessageModel mergeLocalWithRemote({
    required ChatMessageModel local,
    required ChatMessageModel remote,
  }) {
    final keepLocalPending = local.syncState == 'needs_sync' ||
        local.deliveryStatus == 'pending' ||
        local.deliveryStatus == 'sending' ||
        local.deliveryStatus == 'failed';
    return local.copyWith(
      serverId: remote.serverId ?? local.serverId,
      content: local.content.isNotEmpty ? local.content : remote.content,
      updatedAt: remote.updatedAt ?? DateTime.now(),
      sourcePath: remote.sourcePath,
      originLocalId: remote.originLocalId,
      originIdentityType: remote.originIdentityType,
      bridgedByName: remote.bridgedByName,
      remoteUrl: remote.remoteUrl ?? local.remoteUrl,
      thumbnailPath: remote.thumbnailPath ?? local.thumbnailPath,
      fileName: remote.fileName ?? local.fileName,
      fileSizeBytes: remote.fileSizeBytes ?? local.fileSizeBytes,
      mimeType: remote.mimeType ?? local.mimeType,
      durationMs: remote.durationMs ?? local.durationMs,
      uploadStatus:
          remote.uploadStatus == 'uploaded' ? 'uploaded' : local.uploadStatus,
      deliveryStatus:
          keepLocalPending ? local.deliveryStatus : remote.deliveryStatus,
      syncState: keepLocalPending ? local.syncState : remote.syncState,
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
      _ => 'needs_sync',
    };
  }
}
