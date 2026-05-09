import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/emergency_ack_model.dart';
import 'models/emergency_event_model.dart';

class EmergencyLocalDataSource {
  EmergencyLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<void> upsertEvent(EmergencyEventModel event) async {
    final db = await _database.database;
    await db.insert(
      'emergency_events',
      event.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<EmergencyEventModel>> events({
    String? groupId,
    String? offlineChannelId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'emergency_events',
      where: groupId != null
          ? 'group_id = ?'
          : offlineChannelId != null
              ? 'offline_channel_id = ?'
              : null,
      whereArgs: groupId != null
          ? [groupId]
          : offlineChannelId != null
              ? [offlineChannelId]
              : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(EmergencyEventModel.fromDb).toList();
  }

  Future<EmergencyEventModel?> latestEvent() async {
    final db = await _database.database;
    final rows = await db.query(
      'emergency_events',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : EmergencyEventModel.fromDb(rows.first);
  }

  Future<void> markEvent({
    required String localEventId,
    String? serverEventId,
    required String status,
    String? ackStatus,
    String? syncState,
  }) async {
    final db = await _database.database;
    await db.update(
      'emergency_events',
      {
        'server_event_id': serverEventId,
        'status': status,
        if (ackStatus != null) 'ack_status': ackStatus,
        if (syncState != null) 'sync_state': syncState,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_event_id = ?',
      whereArgs: [localEventId],
    );
  }

  Future<List<EmergencyEventModel>> pendingSyncEvents() async {
    final db = await _database.database;
    final rows = await db.query(
      'emergency_events',
      where:
          'group_id IS NOT NULL AND sync_state IN (?, ?) AND retry_count < ?',
      whereArgs: ['needs_sync', 'failed', 3],
      orderBy: 'created_at ASC',
    );
    return rows.map(EmergencyEventModel.fromDb).toList();
  }

  Future<void> markSyncFailed({
    required String localEventId,
    required String error,
  }) async {
    final db = await _database.database;
    await db.rawUpdate(
      '''
      UPDATE emergency_events
      SET sync_state = ?, status = ?, retry_count = retry_count + 1, updated_at = ?
      WHERE local_event_id = ?
      ''',
      ['failed', 'pending', DateTime.now().toIso8601String(), localEventId],
    );
  }

  Future<void> enqueuePacket({
    required String packetId,
    required EmergencyEventModel event,
    required String payloadJson,
  }) async {
    final db = await _database.database;
    await db.insert(
      'emergency_packet_queue',
      {
        'packet_id': packetId,
        'local_event_id': event.localEventId,
        'group_id': event.groupId,
        'offline_channel_id': event.offlineChannelId,
        'channel_code': event.channelCode,
        'payload_json': payloadJson,
        'priority': 'emergency',
        'queue_status': 'pending',
        'retry_count': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> saveAck(EmergencyAckModel ack) async {
    final db = await _database.database;
    await db.insert(
      'emergency_acks',
      ack.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
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
