import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_models.dart';
import '../../../core/settings/settings_service.dart';
import '../../auth/data/models/user_model.dart';
import '../../connectivity_intelligence/data/connectivity_metrics_recorder.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'live_radio_audio_service.dart';
import 'live_radio_eligibility_service.dart';
import 'models/live_radio_session_model.dart';
import 'models/voice_note_model.dart';
import 'ptt_api.dart';
import 'ptt_audio_service.dart';
import 'ptt_floor_controller.dart';
import 'ptt_local_data_source.dart';
import 'ptt_packet_service.dart';

class PttRepository {
  PttRepository({
    PttApi? api,
    PttLocalDataSource? local,
    PttAudioService? audio,
    LiveRadioAudioService? liveAudio,
    PttPacketService? packetService,
    PttFloorController? floorController,
    NearbyRepository? nearbyRepository,
    ConnectivityMetricsRecorder? metricsRecorder,
    SettingsService? settings,
    LiveRadioEligibilityService? liveRadioEligibility,
    Uuid? uuid,
  })  : _api = api ?? PttApi(),
        _local = local ?? PttLocalDataSource(),
        _audio = audio ?? PttAudioService(),
        _liveAudio = liveAudio ?? LiveRadioAudioService(),
        _packetService = packetService ?? PttPacketService(),
        _floorController = floorController ?? PttFloorController.instance,
        _nearby = nearbyRepository,
        _metricsRecorder = metricsRecorder ?? ConnectivityMetricsRecorder(),
        _settings = settings ?? SettingsService(LocalDatabase.instance),
        _liveRadioEligibility = liveRadioEligibility,
        _uuid = uuid ?? const Uuid();

  static const offlineMaxFileBytes = 250 * 1024;
  static const liveAudioMaxPacketBytes = 64 * 1024;

  final PttApi _api;
  final PttLocalDataSource _local;
  final PttAudioService _audio;
  final LiveRadioAudioService _liveAudio;
  final PttPacketService _packetService;
  final PttFloorController _floorController;
  final NearbyRepository? _nearby;
  final ConnectivityMetricsRecorder _metricsRecorder;
  final SettingsService _settings;
  final LiveRadioEligibilityService? _liveRadioEligibility;
  final Uuid _uuid;
  final Map<String, int> _incomingLiveChunkCounts = {};
  final _liveRadioFailureController = StreamController<String>.broadcast();
  String? _activeLiveStreamId;
  DateTime? _activeLiveStartedAt;
  int _activeLiveChunkCount = 0;
  bool _handlingLiveFailure = false;

  PttFloorController get floorController => _floorController;
  Stream<String> get liveRadioFailureStream =>
      _liveRadioFailureController.stream;

  Future<void> configureFloorTimeout() async {
    _floorController.configureTimeoutSeconds(
      await _local.speakerTimeoutSeconds(),
    );
  }

  Future<List<LiveRadioSessionModel>> loadLiveRadioSessions({
    required String offlineChannelId,
  }) {
    return _local.liveRadioSessions(offlineChannelId: offlineChannelId);
  }

  Future<LiveRadioEligibilityResult> evaluateLiveRadio({
    required EffectiveMode effectiveMode,
    required OfflineChannelModel? channel,
  }) {
    final service = _liveRadioEligibility ??
        LiveRadioEligibilityService(
          settings: _settings,
          local: _local,
          audio: _liveAudio,
          nearby: _nearby,
        );
    return service.evaluate(effectiveMode: effectiveMode, channel: channel);
  }

  Future<List<VoiceNoteModel>> loadNotes({
    String? groupId,
    String? offlineChannelId,
  }) {
    return _local.voiceNotes(
      groupId: groupId,
      offlineChannelId: offlineChannelId,
    );
  }

  Future<bool> requestOfflineFloor({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
  }) async {
    final granted = await _floorController.requestLocalFloor(
      contextType: 'offline_channel',
      contextId: channel.channelId,
      user: user,
    );
    if (!granted) return false;
    final packet = _packetService.createRequestPacket(
        channel: channel, user: user, actor: actor);
    await _sendOfflinePacket(packet, channel.channelCode);
    return true;
  }

  Future<void> releaseOfflineFloor({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
  }) async {
    await _floorController.release(
      contextType: 'offline_channel',
      contextId: channel.channelId,
      speakerId: user.id,
      speakerName: user.fullName,
    );
    final packet = _packetService.createReleasePacket(
        channel: channel, user: user, actor: actor);
    await _sendOfflinePacket(packet, channel.channelCode);
  }

  Future<void> startRecording() => _audio.startRecording();

  Future<String> startLiveRadio({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
  }) async {
    if (_activeLiveStreamId != null) {
      throw StateError('Live Radio is already active.');
    }
    final granted = await requestOfflineFloor(
      channel: channel,
      user: user,
      actor: actor,
    );
    if (!granted) throw StateError('Another user is speaking.');

    final streamId = _uuid.v4();
    final startedAt = DateTime.now();
    _activeLiveStreamId = streamId;
    _activeLiveStartedAt = startedAt;
    _activeLiveChunkCount = 0;
    final packetActor = actor ?? CurrentUserActor.fromUserModel(user);
    await _local.upsertLiveRadioSession(
      LiveRadioSessionModel(
        streamId: streamId,
        offlineChannelId: channel.channelId,
        channelCode: channel.channelCode,
        senderLocalId: packetActor.localUserId,
        senderName: packetActor.displayName,
        startedAt: startedAt,
        status: 'started',
      ),
    );
    try {
      final liveStartSent = await _sendOfflinePacket(
        _packetService.createLiveStartPacket(
          channel: channel,
          user: user,
          actor: actor,
          streamId: streamId,
          startedAt: startedAt,
        ),
        channel.channelCode,
      );
      if (!liveStartSent) {
        throw StateError(
          'Live Radio could not reach connected peers. Use voice-note PTT.',
        );
      }
      await _liveAudio.startOutgoingStream(
        streamId: streamId,
        onChunk: (chunk) async {
          _activeLiveChunkCount = chunk.sequence + 1;
          final packet = _packetService.createLiveChunkPacket(
            channel: channel,
            user: user,
            actor: actor,
            streamId: streamId,
            sequence: chunk.sequence,
            bytes: chunk.bytes,
            createdAt: chunk.createdAt,
          );
          final packetBytes = packet.toJsonString().length;
          if (packetBytes > liveAudioMaxPacketBytes) {
            throw StateError(
              'Live Radio audio packet is too large. Use voice-note PTT.',
            );
          }
          final sent = await _sendOfflinePacket(packet, channel.channelCode);
          if (!sent) {
            throw StateError(
              'Live Radio packet delivery failed. Use voice-note PTT.',
            );
          }
        },
        onChunkError: (error, _) {
          unawaited(
            _failActiveLiveRadio(
              channel: channel,
              user: user,
              actor: actor,
              error: error,
            ),
          );
        },
      );
      return streamId;
    } catch (error) {
      await _liveAudio.stopOutgoingStream();
      await releaseOfflineFloor(channel: channel, user: user, actor: actor);
      await _local.updateLiveRadioSession(
        streamId: streamId,
        endedAt: DateTime.now(),
        status: 'failed',
        lastError: error.toString(),
      );
      _activeLiveStreamId = null;
      _activeLiveStartedAt = null;
      rethrow;
    }
  }

  Future<void> endLiveRadio({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    String status = 'ended',
  }) async {
    final streamId = _activeLiveStreamId;
    final startedAt = _activeLiveStartedAt;
    await _liveAudio.stopOutgoingStream();
    if (streamId != null) {
      final endedAt = DateTime.now();
      await _sendOfflinePacket(
        _packetService.createLiveEndPacket(
          channel: channel,
          user: user,
          actor: actor,
          streamId: streamId,
          endedAt: endedAt,
        ),
        channel.channelCode,
      );
      await _local.updateLiveRadioSession(
        streamId: streamId,
        endedAt: endedAt,
        durationMs: startedAt == null
            ? null
            : endedAt.difference(startedAt).inMilliseconds,
        chunkCount: _activeLiveChunkCount,
        status: status,
      );
    }
    await releaseOfflineFloor(channel: channel, user: user, actor: actor);
    _activeLiveStreamId = null;
    _activeLiveStartedAt = null;
    _activeLiveChunkCount = 0;
  }

  Future<VoiceNoteModel?> stopAndCreateNote({
    required UserModel user,
    String? groupId,
    OfflineChannelModel? channel,
    required String deliveryMode,
  }) async {
    final clip = await _audio.stopRecording();
    if (clip == null) return null;
    final note = VoiceNoteModel(
      localVoiceId: _uuid.v4(),
      groupId: groupId,
      offlineChannelId: channel?.channelId,
      channelCode: channel?.channelCode,
      senderId: user.id,
      senderName: user.fullName,
      localFilePath: clip.filePath,
      durationMs: clip.durationMs,
      fileSizeBytes: clip.fileSizeBytes,
      isMine: true,
      deliveryMode: deliveryMode,
      deliveryStatus: 'recorded',
      ackStatus: deliveryMode == 'offline' ? 'waiting' : 'none',
      createdAt: DateTime.now(),
      syncState: deliveryMode == 'online' ? 'needs_sync' : 'local_only',
    );
    await _local.upsertVoiceNote(note);
    return note;
  }

  Future<void> sendOnline({
    required String groupId,
    required UserModel user,
    required VoiceNoteModel note,
  }) async {
    final path = note.localFilePath;
    if (path == null) throw StateError('Voice file is missing.');
    await _local.updateVoiceStatus(
      localVoiceId: note.localVoiceId,
      deliveryStatus: 'sending',
    );
    final uploaded = await _api.uploadVoiceNote(
      groupId: groupId,
      currentUserId: user.id,
      localVoiceId: note.localVoiceId,
      filePath: path,
      durationMs: note.durationMs ?? 0,
      createdAt: note.createdAt,
    );
    await _local.updateVoiceStatus(
      localVoiceId: note.localVoiceId,
      deliveryStatus: 'sent',
      serverVoiceId: uploaded.serverVoiceId,
      remoteAudioUrl: uploaded.remoteAudioUrl,
      syncState: 'synced',
    );
  }

  Future<void> sendOffline({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required VoiceNoteModel note,
  }) async {
    final size = note.fileSizeBytes ?? 0;
    if (size > offlineMaxFileBytes) {
      await _local.updateVoiceStatus(
        localVoiceId: note.localVoiceId,
        deliveryStatus: 'failed',
        ackStatus: 'timeout',
      );
      throw StateError(
          'Offline voice note is too large. Keep clips under 250 KB.');
    }
    final packet = await _packetService.createVoiceNotePacket(
      channel: channel,
      user: user,
      actor: actor,
      note: note,
    );
    await _local.enqueueVoicePacket(
      packetId: packet.packetId,
      localVoiceId: note.localVoiceId,
      offlineChannelId: channel.channelId,
      channelCode: channel.channelCode,
      payloadJson: packet.toJsonString(),
    );
    final hadConnectedPeers =
        (await _connectedPeers(channel.channelCode)).isNotEmpty;
    final sent = await _sendOfflinePacket(packet, channel.channelCode);
    await _local.updateVoiceStatus(
      localVoiceId: note.localVoiceId,
      deliveryStatus: sent
          ? 'sent'
          : hadConnectedPeers
              ? 'failed'
              : 'pending',
      ackStatus: sent
          ? 'waiting'
          : hadConnectedPeers
              ? 'timeout'
              : 'waiting',
    );
    if (!sent && hadConnectedPeers) {
      throw StateError(
        'Voice note could not reach connected peers. Try again or move closer.',
      );
    }
  }

  Future<String> handleIncomingPacket({
    required OfflinePacketModel packet,
    required OfflineChannelModel activeChannel,
    required UserModel currentUser,
  }) async {
    if (packet.channelCode != activeChannel.channelCode) {
      await _markProcessed(packet, 'ignored_wrong_channel');
      return 'Voice packet belongs to another channel.';
    }
    if (packet.ttl <= 0 || packet.hopCount > 5) {
      await _markProcessed(packet, 'ignored_expired');
      return 'Expired voice packet ignored.';
    }
    if (await _local.processedPacketExists(packet.packetId)) {
      return 'Duplicate voice packet ignored.';
    }

    switch (packet.packetType) {
      case 'ptt_request':
        final message = await _floorController.handleIncomingRequest(
          packet: packet,
          contextIdOverride: activeChannel.channelId,
        );
        await _markProcessed(packet, 'accepted');
        return message;
      case 'ptt_release':
        final message = await _floorController.handleIncomingRelease(
          packet: packet,
          contextIdOverride: activeChannel.channelId,
        );
        await _markProcessed(packet, 'accepted');
        return message;
      case 'voice_note':
        await _handleVoiceNote(packet, activeChannel, currentUser);
        await _markProcessed(packet, 'accepted');
        return 'Voice note received.';
      case 'live_audio_start':
        await _handleLiveStart(packet, activeChannel, currentUser);
        await _markProcessed(packet, 'accepted');
        return '${packet.senderName} is live.';
      case 'live_audio_chunk':
        await _handleLiveChunk(packet, currentUser);
        await _markProcessed(packet, 'accepted');
        return 'Live audio received.';
      case 'live_audio_end':
        await _handleLiveEnd(packet, activeChannel, currentUser);
        await _markProcessed(packet, 'accepted');
        return 'Live Radio ended.';
      case 'voice_ack':
        final localVoiceId = packet.payload['ackForVoiceId']?.toString();
        if (localVoiceId != null && localVoiceId.isNotEmpty) {
          await _local.updateVoiceStatus(
            localVoiceId: localVoiceId,
            deliveryStatus: 'delivered',
            ackStatus: 'acknowledged',
          );
          await _metricsRecorder.recordAck(
            endpointId: packet.senderId,
            userId: packet.senderId,
            displayName: packet.senderName,
            channelId: packet.channelId,
            channelCode: packet.channelCode,
            ackRttMs: DateTime.now()
                .difference(packet.createdAt)
                .inMilliseconds
                .abs(),
          );
        }
        await _markProcessed(packet, 'accepted');
        return 'Voice note delivered.';
      default:
        return 'Unsupported PTT packet ignored.';
    }
  }

  Future<void> upsertRemoteVoiceNote(
    Map<String, dynamic> data, {
    required String currentUserId,
  }) async {
    await _local.upsertVoiceNote(
      VoiceNoteModel.fromApiJson(data, currentUserId: currentUserId),
    );
  }

  Future<void> play(VoiceNoteModel note) {
    final pathOrUrl = note.localFilePath ?? note.remoteAudioUrl;
    if (pathOrUrl == null) throw StateError('Voice file is missing.');
    return _audio.play(pathOrUrl);
  }

  Future<void> dispose() async {
    await _liveAudio.dispose();
    await _audio.dispose();
    await _liveRadioFailureController.close();
  }

  Future<void> stopAllAudio() async {
    await _liveAudio.stopAll();
  }

  Future<void> _handleVoiceNote(
    OfflinePacketModel packet,
    OfflineChannelModel activeChannel,
    UserModel currentUser,
  ) async {
    if (packet.senderId == currentUser.id) return;
    final audioBase64 = packet.payload['audioBase64']?.toString();
    if (audioBase64 == null || audioBase64.isEmpty) {
      throw StateError('Voice packet is missing audio.');
    }
    final bytes = base64Decode(audioBase64);
    if (bytes.length > offlineMaxFileBytes) {
      throw StateError('Received voice note is too large.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${dir.path}/voice_notes');
    if (!voiceDir.existsSync()) voiceDir.createSync(recursive: true);
    final localVoiceId =
        packet.payload['localVoiceId']?.toString() ?? packet.packetId;
    final filePath = '${voiceDir.path}/$localVoiceId.m4a';
    await File(filePath).writeAsBytes(bytes);

    await _local.upsertVoiceNote(
      VoiceNoteModel(
        localVoiceId: localVoiceId,
        offlineChannelId: activeChannel.channelId,
        channelCode: activeChannel.channelCode,
        senderId: packet.senderId,
        senderName: packet.senderName,
        localFilePath: filePath,
        durationMs:
            int.tryParse(packet.payload['durationMs']?.toString() ?? ''),
        fileSizeBytes: bytes.length,
        isMine: false,
        deliveryMode: 'offline',
        deliveryStatus: 'received',
        ackStatus: 'none',
        createdAt: packet.createdAt,
        syncState: 'local_only',
      ),
    );
    final ack = _packetService.createVoiceAckPacket(
      receivedPacket: packet,
      user: currentUser,
    );
    await _sendOfflinePacket(ack, activeChannel.channelCode);
  }

  Future<void> _handleLiveStart(
    OfflinePacketModel packet,
    OfflineChannelModel activeChannel,
    UserModel currentUser,
  ) async {
    if (_isMine(packet, currentUser)) return;
    final streamId = packet.payload['streamId']?.toString();
    if (streamId == null || streamId.isEmpty) return;
    final startedAt =
        DateTime.tryParse(packet.payload['startedAt']?.toString() ?? '') ??
            packet.createdAt;
    await _floorController.setRemoteSpeaker(
      contextType: 'offline_channel',
      contextId: activeChannel.channelId,
      speakerId: packet.senderLocalId ?? packet.senderId,
      speakerName: packet.senderName,
    );
    await _local.upsertLiveRadioSession(
      LiveRadioSessionModel(
        streamId: streamId,
        offlineChannelId: activeChannel.channelId,
        channelCode: activeChannel.channelCode,
        senderLocalId: packet.senderLocalId ?? packet.senderId,
        senderName: packet.senderName,
        startedAt: startedAt,
        status: 'started',
      ),
    );
    _incomingLiveChunkCounts[streamId] = 0;
    await _liveAudio.startIncomingStream(
      streamId: streamId,
      senderName: packet.senderName,
    );
  }

  Future<void> _handleLiveChunk(
    OfflinePacketModel packet,
    UserModel currentUser,
  ) async {
    if (_isMine(packet, currentUser)) return;
    final streamId = packet.payload['streamId']?.toString();
    final encoded = packet.payload['audioChunkBase64']?.toString();
    if (streamId == null || streamId.isEmpty || encoded == null) return;
    final sequence =
        int.tryParse(packet.payload['sequence']?.toString() ?? '') ?? 0;
    final bytes = Uint8List.fromList(base64Decode(encoded));
    if (bytes.length > liveAudioMaxPacketBytes) {
      await _local.updateLiveRadioSession(
        streamId: streamId,
        status: 'failed',
        lastError: 'Received Live Radio chunk was too large.',
      );
      return;
    }
    _incomingLiveChunkCounts[streamId] =
        (_incomingLiveChunkCounts[streamId] ?? 0) + 1;
    await _liveAudio.addIncomingChunk(
      LiveAudioChunk(
        streamId: streamId,
        sequence: sequence,
        bytes: bytes,
        createdAt: packet.createdAt,
        chunkDurationMs: int.tryParse(
              packet.payload['chunkDurationMs']?.toString() ?? '',
            ) ??
            LiveRadioAudioService.chunkDurationMs,
      ),
    );
  }

  Future<void> _handleLiveEnd(
    OfflinePacketModel packet,
    OfflineChannelModel activeChannel,
    UserModel currentUser,
  ) async {
    if (_isMine(packet, currentUser)) return;
    final streamId = packet.payload['streamId']?.toString();
    if (streamId == null || streamId.isEmpty) return;
    final endedAt =
        DateTime.tryParse(packet.payload['endedAt']?.toString() ?? '') ??
            packet.createdAt;
    await _liveAudio.endIncomingStream(streamId);
    await _floorController.release(
      contextType: 'offline_channel',
      contextId: activeChannel.channelId,
      speakerId: packet.senderLocalId ?? packet.senderId,
      speakerName: packet.senderName,
    );
    await _local.updateLiveRadioSession(
      streamId: streamId,
      endedAt: endedAt,
      chunkCount: _incomingLiveChunkCounts.remove(streamId),
      status: 'ended',
    );
  }

  bool _isMine(OfflinePacketModel packet, UserModel currentUser) {
    return packet.senderId == currentUser.id ||
        packet.senderLocalId == currentUser.id;
  }

  Future<void> _failActiveLiveRadio({
    required OfflineChannelModel channel,
    required UserModel user,
    CurrentUserActor? actor,
    required Object error,
  }) async {
    if (_handlingLiveFailure) return;
    final streamId = _activeLiveStreamId;
    if (streamId == null) return;
    _handlingLiveFailure = true;
    _activeLiveStreamId = null;
    _activeLiveStartedAt = null;
    _activeLiveChunkCount = 0;
    try {
      await _liveAudio.stopOutgoingStream();
      await _local.updateLiveRadioSession(
        streamId: streamId,
        endedAt: DateTime.now(),
        status: 'failed',
        lastError: '$error',
      );
      _liveRadioFailureController.add(
        'Live Radio stopped. Use voice-note PTT. $error',
      );
      try {
        await releaseOfflineFloor(channel: channel, user: user, actor: actor);
      } catch (_) {
        // The local live state is already failed; release propagation is best-effort.
      }
    } finally {
      _handlingLiveFailure = false;
    }
  }

  Future<bool> _sendOfflinePacket(
    OfflinePacketModel packet,
    String channelCode,
  ) async {
    final nearby = _nearby;
    if (nearby == null) return false;
    final peers = await _connectedPeers(channelCode);
    if (peers.isEmpty) return false;
    var sent = false;
    for (final peer in peers) {
      try {
        await nearby.sendPacket(
          endpointId: peer.endpointId,
          packetJson: packet.toJsonString(),
        );
        await _metricsRecorder.recordPacketResult(
          endpointId: peer.endpointId,
          userId: peer.userId,
          displayName: peer.displayName,
          channelId: packet.channelId,
          channelCode: packet.channelCode,
          success: true,
        );
        sent = true;
      } catch (error) {
        await _metricsRecorder.recordPacketResult(
          endpointId: peer.endpointId,
          userId: peer.userId,
          displayName: peer.displayName,
          channelId: packet.channelId,
          channelCode: packet.channelCode,
          success: false,
          retryCount: 1,
        );
        if (packet.packetType == 'voice_note') {
          await _local.markQueueStatus(
            packet.packetId,
            'failed',
            lastError: error.toString(),
          );
        }
      }
    }
    if (sent && packet.packetType == 'voice_note') {
      await _local.markQueueStatus(packet.packetId, 'sent');
    }
    return sent;
  }

  Future<List<NearbyPeerModel>> _connectedPeers(String channelCode) async {
    final nearby = _nearby;
    if (nearby == null) return _local.connectedPeers(channelCode);
    return nearby.connectedPeers(channelCode);
  }

  Future<void> _markProcessed(OfflinePacketModel packet, String action) {
    return _local.markProcessed(
      packetId: packet.packetId,
      channelId: packet.channelId,
      channelCode: packet.channelCode,
      senderId: packet.senderId,
      action: action,
    );
  }
}
