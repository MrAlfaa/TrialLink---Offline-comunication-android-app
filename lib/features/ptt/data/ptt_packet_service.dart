import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/identity/current_user_actor.dart';
import '../../auth/data/models/user_model.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'models/voice_note_model.dart';

class PttPacketService {
  PttPacketService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  OfflinePacketModel createRequestPacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'ptt_request',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'high',
      ttl: 5,
      hopCount: 0,
      createdAt: DateTime.now(),
      requiresAck: true,
      payload: {'requestId': _uuid.v4()},
    );
  }

  OfflinePacketModel createReleasePacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'ptt_release',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'high',
      ttl: 5,
      hopCount: 0,
      createdAt: DateTime.now(),
      requiresAck: false,
      payload: {'releasedAt': DateTime.now().toIso8601String()},
    );
  }

  Future<OfflinePacketModel> createVoiceNotePacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required VoiceNoteModel note,
  }) async {
    final filePath = note.localFilePath;
    if (filePath == null) throw StateError('Voice note file is missing.');
    final bytes = await File(filePath).readAsBytes();
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'voice_note',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'high',
      ttl: 5,
      hopCount: 0,
      createdAt: note.createdAt,
      requiresAck: true,
      payload: {
        'localVoiceId': note.localVoiceId,
        'originLocalId': packetActor.localUserId,
        'originBackendId': packetActor.backendUserId,
        'originDisplayName': packetActor.displayName,
        'originIdentityType': packetActor.identityType,
        'durationMs': note.durationMs,
        'fileName': '${note.localVoiceId}.m4a',
        'fileSizeBytes': note.fileSizeBytes,
        'audioBase64': base64Encode(bytes),
      },
    );
  }

  OfflinePacketModel createVoiceAckPacket({
    required OfflinePacketModel receivedPacket,
    required UserModel user,
    CurrentUserActor? actor,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'voice_ack',
      channelId: receivedPacket.channelId,
      channelCode: receivedPacket.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'device',
      targetId: receivedPacket.senderLocalId ?? receivedPacket.senderId,
      priority: 'normal',
      ttl: 3,
      hopCount: 0,
      createdAt: DateTime.now(),
      requiresAck: false,
      payload: {
        'ackForVoiceId': receivedPacket.payload['localVoiceId'],
        'receivedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  OfflinePacketModel createLiveStartPacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required String streamId,
    required DateTime startedAt,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'live_audio_start',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'high',
      ttl: 3,
      hopCount: 0,
      createdAt: startedAt,
      requiresAck: false,
      payload: {
        'streamId': streamId,
        'startedAt': startedAt.toIso8601String(),
        'codec': 'pcm16',
        'sampleRate': 16000,
        'chunkDurationMs': 200,
      },
    );
  }

  OfflinePacketModel createLiveChunkPacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required String streamId,
    required int sequence,
    required Uint8List bytes,
    required DateTime createdAt,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'live_audio_chunk',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'high',
      ttl: 2,
      hopCount: 0,
      createdAt: createdAt,
      requiresAck: false,
      payload: {
        'streamId': streamId,
        'sequence': sequence,
        'timestamp': createdAt.toIso8601String(),
        'codec': 'pcm16',
        'sampleRate': 16000,
        'chunkDurationMs': 200,
        'audioChunkBase64': base64Encode(bytes),
      },
    );
  }

  OfflinePacketModel createLiveEndPacket({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required String streamId,
    required DateTime endedAt,
  }) {
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    return OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'live_audio_end',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: packetActor.backendUserId ?? packetActor.localUserId,
      senderLocalId: packetActor.localUserId,
      senderBackendId: packetActor.backendUserId,
      senderName: packetActor.displayName,
      identityType: packetActor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      priority: 'high',
      ttl: 3,
      hopCount: 0,
      createdAt: endedAt,
      requiresAck: false,
      payload: {
        'streamId': streamId,
        'endedAt': endedAt.toIso8601String(),
      },
    );
  }
}
