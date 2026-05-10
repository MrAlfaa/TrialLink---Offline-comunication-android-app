import 'package:uuid/uuid.dart';

import '../../auth/data/models/user_model.dart';
import 'chat_api.dart';
import 'chat_media_service.dart';
import 'message_dao.dart';
import 'message_sync_service.dart';
import 'models/chat_message_model.dart';

class ChatRepository {
  ChatRepository({
    ChatApi? api,
    MessageDao? dao,
    MessageSyncService? syncService,
    ChatMediaService? mediaService,
  })  : _api = api ?? ChatApi(),
        _dao = dao ?? MessageDao(),
        _syncService = syncService ?? MessageSyncService(),
        _mediaService = mediaService ?? ChatMediaService(),
        _uuid = const Uuid();

  final ChatApi _api;
  final MessageDao _dao;
  final MessageSyncService _syncService;
  final ChatMediaService _mediaService;
  final Uuid _uuid;

  Future<List<ChatMessageModel>> loadLocalMessages(String groupId) {
    return _dao.getMessagesForGroup(groupId);
  }

  Future<List<ChatMessageModel>> refreshHistory({
    required String groupId,
    required UserModel currentUser,
  }) async {
    final messages = await _api.getGroupMessages(
      groupId: groupId,
      currentUserId: currentUser.id,
    );
    await _dao.upsertMessages(messages);
    return _dao.getMessagesForGroup(groupId);
  }

  Future<ChatMessageModel> createLocalOutgoingMessage({
    required String groupId,
    String? tripId,
    String? channelId,
    String? chatId,
    required UserModel currentUser,
    required String content,
  }) async {
    final now = DateTime.now();
    final message = ChatMessageModel(
      localId: _uuid.v4(),
      clientMessageId: _uuid.v4(),
      groupId: groupId,
      tripId: tripId,
      channelId: channelId,
      chatId: chatId,
      senderId: currentUser.id,
      senderName: currentUser.fullName,
      messageType: 'text',
      content: content.trim(),
      deliveryStatus: 'pending',
      isMine: true,
      createdAt: now,
      updatedAt: now,
      syncState: 'needs_sync',
    );

    await _dao.upsertMessage(message);
    await _dao.enqueueOutgoingMessage(message);
    return message;
  }

  Future<ChatMessageModel?> createLocalImageMessage({
    required String groupId,
    String? tripId,
    String? channelId,
    String? chatId,
    required UserModel currentUser,
  }) async {
    final media = await _mediaService.pickImageFromGallery();
    if (media == null) return null;
    return _createLocalMediaMessage(
      groupId: groupId,
      tripId: tripId,
      channelId: channelId,
      chatId: chatId,
      currentUser: currentUser,
      media: media,
      content: 'Image',
    );
  }

  Future<void> startVoiceRecording() {
    return _mediaService.startVoiceRecording();
  }

  Future<void> cancelVoiceRecording() {
    return _mediaService.cancelVoiceRecording();
  }

  Future<ChatMessageModel?> stopAndCreateLocalVoiceMessage({
    required String groupId,
    String? tripId,
    String? channelId,
    String? chatId,
    required UserModel currentUser,
  }) async {
    final media = await _mediaService.stopVoiceRecording();
    if (media == null) return null;
    return _createLocalMediaMessage(
      groupId: groupId,
      tripId: tripId,
      channelId: channelId,
      chatId: chatId,
      currentUser: currentUser,
      media: media,
      content: 'Voice note',
    );
  }

  Future<ChatMessageModel> _createLocalMediaMessage({
    required String groupId,
    String? tripId,
    String? channelId,
    String? chatId,
    required UserModel currentUser,
    required PickedChatMedia media,
    required String content,
  }) async {
    final now = DateTime.now();
    final message = ChatMessageModel(
      localId: _uuid.v4(),
      clientMessageId: _uuid.v4(),
      groupId: groupId,
      tripId: tripId,
      channelId: channelId,
      chatId: chatId,
      senderId: currentUser.id,
      senderName: currentUser.fullName,
      messageType: media.messageType,
      content: content,
      deliveryStatus: 'pending',
      isMine: true,
      createdAt: now,
      updatedAt: now,
      syncState: 'needs_sync',
      localFilePath: media.localFilePath,
      fileName: media.fileName,
      fileSizeBytes: media.fileSizeBytes,
      mimeType: media.mimeType,
      durationMs: media.durationMs,
      uploadStatus: 'pending',
    );
    await _dao.upsertMessage(message);
    return message;
  }

  Future<void> uploadMediaMessage(ChatMessageModel message) async {
    final path = message.localFilePath;
    if (!await _mediaService.localFileExists(path)) {
      await _dao.updateMediaUploadStatus(
        clientMessageId: message.clientMessageId,
        uploadStatus: 'failed',
        deliveryStatus: 'failed',
        syncState: 'needs_sync',
      );
      throw StateError('Local media file is missing. Select the media again.');
    }
    await _dao.updateMediaUploadStatus(
      clientMessageId: message.clientMessageId,
      uploadStatus: 'uploading',
      deliveryStatus: 'sending',
      syncState: 'needs_sync',
    );
    try {
      final uploaded = await _api.uploadMediaMessage(
        groupId: message.groupId,
        currentUserId: message.senderId,
        clientMessageId: message.clientMessageId,
        messageType: message.messageType,
        filePath: path!,
        fileName: message.fileName ?? '${message.clientMessageId}.bin',
        content: message.content,
        tripId: message.tripId,
        channelId: message.channelId,
        chatId: message.chatId,
        mimeType: message.mimeType,
        durationMs: message.durationMs,
        createdAt: message.createdAt,
      );
      await _dao.updateMediaUploadStatus(
        clientMessageId: message.clientMessageId,
        uploadStatus: 'uploaded',
        remoteUrl: uploaded.remoteUrl,
        serverId: uploaded.serverId,
        deliveryStatus: 'synced',
        syncState: 'synced',
      );
      await _dao.upsertRemoteMessage(uploaded);
    } catch (error) {
      await _dao.updateMediaUploadStatus(
        clientMessageId: message.clientMessageId,
        uploadStatus: 'failed',
        deliveryStatus: 'failed',
        syncState: 'needs_sync',
      );
      rethrow;
    }
  }

  Future<void> playMedia(ChatMessageModel message) {
    final pathOrUrl = message.localFilePath ?? message.remoteUrl;
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      throw StateError('Media file is missing.');
    }
    return _mediaService.play(pathOrUrl);
  }

  Future<void> upsertIncoming(ChatMessageModel message) async {
    final existing = await _dao.findByClientMessageId(message.clientMessageId);
    if (existing != null) {
      if (message.isMedia) {
        await _dao.upsertRemoteMessage(message);
        return;
      }
      await _dao.updateDeliveryStatus(
        clientMessageId: message.clientMessageId,
        serverId: message.serverId,
        deliveryStatus: 'synced',
      );
      await _dao.markQueuesCompleted(message.clientMessageId);
      return;
    }

    await _dao.upsertMessage(message);
  }

  Future<void> markSending(String clientMessageId) {
    return _dao.updateDeliveryStatus(
      clientMessageId: clientMessageId,
      deliveryStatus: 'sending',
      syncState: 'needs_sync',
    );
  }

  Future<void> markAck({
    required String clientMessageId,
    required String? serverId,
  }) async {
    await _dao.updateDeliveryStatus(
      clientMessageId: clientMessageId,
      serverId: serverId,
      deliveryStatus: 'synced',
    );
    await _dao.markQueuesCompleted(clientMessageId);
  }

  Future<void> markFailed(String clientMessageId, String error) async {
    await _dao.markQueueFailed(clientMessageId, error);
    await _dao.updateDeliveryStatus(
      clientMessageId: clientMessageId,
      deliveryStatus: 'failed',
      syncState: 'needs_sync',
    );
  }

  Future<void> syncPendingMessages() {
    return _syncService.syncPendingMessages();
  }
}
