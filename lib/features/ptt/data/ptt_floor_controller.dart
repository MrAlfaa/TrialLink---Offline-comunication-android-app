import 'package:uuid/uuid.dart';

import '../../auth/data/models/user_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'models/ptt_floor_state.dart';
import 'ptt_local_data_source.dart';

class PttFloorController {
  PttFloorController({
    PttLocalDataSource? local,
    Uuid? uuid,
  })  : _local = local ?? PttLocalDataSource(),
        _uuid = uuid ?? const Uuid();

  static final PttFloorController instance = PttFloorController();

  final PttLocalDataSource _local;
  final Uuid _uuid;
  final Map<String, PttFloorState> _floorByContext = {};
  int _speakerTimeoutSeconds = 35;

  void configureTimeoutSeconds(int seconds) {
    if (seconds > 0) _speakerTimeoutSeconds = seconds;
  }

  PttFloorState stateFor({
    required String contextType,
    required String contextId,
    String? currentUserId,
  }) {
    final key = _key(contextType, contextId);
    final current = _floorByContext[key] ??
        PttFloorState(contextType: contextType, contextId: contextId);
    if (_isExpired(current)) {
      _floorByContext.remove(key);
      return PttFloorState(
        contextType: contextType,
        contextId: contextId,
        currentUserId: currentUserId,
      );
    }
    return current.copyWith(currentUserId: currentUserId);
  }

  Future<bool> requestLocalFloor({
    required String contextType,
    required String contextId,
    required UserModel user,
  }) async {
    final current = stateFor(
      contextType: contextType,
      contextId: contextId,
      currentUserId: user.id,
    );
    if (!current.canCurrentUserSpeak) return false;
    await _setSpeaker(
      contextType: contextType,
      contextId: contextId,
      speakerId: user.id,
      speakerName: user.fullName,
      eventType: 'granted',
    );
    return true;
  }

  Future<void> release({
    required String contextType,
    required String contextId,
    required String speakerId,
    required String speakerName,
    String eventType = 'release',
  }) async {
    final key = _key(contextType, contextId);
    final current = _floorByContext[key];
    if (current?.currentSpeakerId == speakerId) {
      _floorByContext.remove(key);
    }
    await _local.saveFloorEvent(
      eventId: _uuid.v4(),
      contextType: contextType,
      contextId: contextId,
      speakerId: speakerId,
      speakerName: speakerName,
      eventType: eventType,
    );
  }

  Future<void> setRemoteSpeaker({
    required String contextType,
    required String contextId,
    required String speakerId,
    required String speakerName,
  }) {
    return _setSpeaker(
      contextType: contextType,
      contextId: contextId,
      speakerId: speakerId,
      speakerName: speakerName,
      eventType: 'granted',
    );
  }

  Future<String> handleIncomingRequest({
    required OfflinePacketModel packet,
    String? contextIdOverride,
  }) async {
    final contextType = 'offline_channel';
    final contextId = contextIdOverride ?? packet.channelId;
    final current = stateFor(contextType: contextType, contextId: contextId);
    final incomingId = packet.senderLocalId ?? packet.senderId;
    if (!current.hasSpeaker) {
      await _setSpeaker(
        contextType: contextType,
        contextId: contextId,
        speakerId: incomingId,
        speakerName: packet.senderName,
        eventType: 'granted',
      );
      return '${packet.senderName} is speaking.';
    }

    final lockedAt = current.lockedAt ?? DateTime.now();
    final currentId = current.currentSpeakerId ?? '';
    final incomingWins = packet.createdAt.isBefore(lockedAt) ||
        (packet.createdAt.isAtSameMomentAs(lockedAt) &&
            incomingId.compareTo(currentId) < 0);
    if (incomingWins) {
      await _setSpeaker(
        contextType: contextType,
        contextId: contextId,
        speakerId: incomingId,
        speakerName: packet.senderName,
        eventType: 'granted',
        lockedAt: packet.createdAt,
      );
      return '${packet.senderName} is speaking.';
    }

    await _local.saveFloorEvent(
      eventId: _uuid.v4(),
      contextType: contextType,
      contextId: contextId,
      speakerId: incomingId,
      speakerName: packet.senderName,
      eventType: 'denied',
    );
    return 'Another user is speaking.';
  }

  Future<String> handleIncomingRelease({
    required OfflinePacketModel packet,
    String? contextIdOverride,
  }) async {
    await release(
      contextType: 'offline_channel',
      contextId: contextIdOverride ?? packet.channelId,
      speakerId: packet.senderLocalId ?? packet.senderId,
      speakerName: packet.senderName,
    );
    return 'PTT channel is free.';
  }

  Future<void> _setSpeaker({
    required String contextType,
    required String contextId,
    required String speakerId,
    required String speakerName,
    required String eventType,
    DateTime? lockedAt,
  }) async {
    _floorByContext[_key(contextType, contextId)] = PttFloorState(
      contextType: contextType,
      contextId: contextId,
      currentSpeakerId: speakerId,
      currentSpeakerName: speakerName,
      lockedAt: lockedAt ?? DateTime.now(),
    );
    await _local.saveFloorEvent(
      eventId: _uuid.v4(),
      contextType: contextType,
      contextId: contextId,
      speakerId: speakerId,
      speakerName: speakerName,
      eventType: eventType,
    );
  }

  bool _isExpired(PttFloorState state) {
    final lockedAt = state.lockedAt;
    return lockedAt != null &&
        DateTime.now().difference(lockedAt).inSeconds >= _speakerTimeoutSeconds;
  }

  String _key(String contextType, String contextId) =>
      '$contextType:$contextId';
}
