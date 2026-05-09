import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/live_radio_session_model.dart';
import 'models/voice_note_model.dart';

class PttLocalDataSource {
  PttLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<List<VoiceNoteModel>> voiceNotes({
    String? groupId,
    String? offlineChannelId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'voice_notes',
      where: groupId != null ? 'group_id = ?' : 'offline_channel_id = ?',
      whereArgs: [groupId ?? offlineChannelId],
      orderBy: 'created_at ASC',
    );
    return rows.map(VoiceNoteModel.fromDb).toList();
  }

  Future<void> upsertVoiceNote(VoiceNoteModel note) async {
    final db = await _database.database;
    await db.insert(
      'voice_notes',
      note.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateVoiceStatus({
    required String localVoiceId,
    required String deliveryStatus,
    String? ackStatus,
    String? serverVoiceId,
    String? remoteAudioUrl,
    String? syncState,
  }) async {
    final db = await _database.database;
    await db.update(
      'voice_notes',
      {
        'delivery_status': deliveryStatus,
        if (ackStatus != null) 'ack_status': ackStatus,
        if (serverVoiceId != null) 'server_voice_id': serverVoiceId,
        if (remoteAudioUrl != null) 'remote_audio_url': remoteAudioUrl,
        if (syncState != null) 'sync_state': syncState,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_voice_id = ?',
      whereArgs: [localVoiceId],
    );
  }

  Future<void> saveFloorEvent({
    required String eventId,
    required String contextType,
    required String contextId,
    required String speakerId,
    required String speakerName,
    required String eventType,
  }) async {
    final db = await _database.database;
    await db.insert(
      'ptt_floor_events',
      {
        'event_id': eventId,
        'context_type': contextType,
        'context_id': contextId,
        'speaker_id': speakerId,
        'speaker_name': speakerName,
        'event_type': eventType,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> enqueueVoicePacket({
    required String packetId,
    required String localVoiceId,
    required String? offlineChannelId,
    required String? channelCode,
    required String payloadJson,
  }) async {
    final db = await _database.database;
    await db.insert(
      'voice_packet_queue',
      {
        'packet_id': packetId,
        'local_voice_id': localVoiceId,
        'offline_channel_id': offlineChannelId,
        'channel_code': channelCode,
        'payload_json': payloadJson,
        'queue_status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> markQueueStatus(
    String packetId,
    String status, {
    String? lastError,
  }) async {
    final db = await _database.database;
    await db.update(
      'voice_packet_queue',
      {
        'queue_status': status,
        if (lastError != null) 'last_error': lastError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'packet_id = ?',
      whereArgs: [packetId],
    );
  }

  Future<List<LiveRadioSessionModel>> liveRadioSessions({
    required String offlineChannelId,
    int limit = 12,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'live_radio_sessions',
      where: 'offline_channel_id = ?',
      whereArgs: [offlineChannelId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(LiveRadioSessionModel.fromDb).toList();
  }

  Future<void> upsertLiveRadioSession(LiveRadioSessionModel session) async {
    final db = await _database.database;
    await db.insert(
      'live_radio_sessions',
      session.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateLiveRadioSession({
    required String streamId,
    DateTime? endedAt,
    int? durationMs,
    int? chunkCount,
    String? status,
    String? lastError,
  }) async {
    final db = await _database.database;
    await db.update(
      'live_radio_sessions',
      {
        if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
        if (durationMs != null) 'duration_ms': durationMs,
        if (chunkCount != null) 'chunk_count': chunkCount,
        if (status != null) 'status': status,
        if (lastError != null) 'last_error': lastError,
      },
      where: 'stream_id = ?',
      whereArgs: [streamId],
    );
  }

  Future<List<NearbyPeerModel>> connectedPeers(String channelCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'nearby_peers',
      where:
          'active_channel_code = ? AND connection_status = ? AND is_same_channel = 1',
      whereArgs: [channelCode, PeerConnectionStatus.connected.name],
      orderBy: 'last_seen_at DESC',
    );
    return rows.map(NearbyPeerModel.fromDb).toList();
  }

  Future<int> speakerTimeoutSeconds({int fallback = 35}) async {
    final db = await _database.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['speaker_timeout_seconds'],
      limit: 1,
    );
    if (rows.isEmpty) return fallback;
    return int.tryParse(rows.first['value']?.toString() ?? '') ?? fallback;
  }

  Future<bool> processedPacketExists(String packetId) async {
    final db = await _database.database;
    final rows = await db.query(
      'processed_offline_packets',
      where: 'packet_id = ?',
      whereArgs: [packetId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markProcessed({
    required String packetId,
    required String channelId,
    required String channelCode,
    required String senderId,
    required String action,
  }) async {
    final db = await _database.database;
    await db.insert(
      'processed_offline_packets',
      {
        'packet_id': packetId,
        'channel_id': channelId,
        'channel_code': channelCode,
        'sender_id': senderId,
        'processed_action': action,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
