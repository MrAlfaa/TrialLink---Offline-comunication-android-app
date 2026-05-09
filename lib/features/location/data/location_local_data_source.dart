import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/location_update_model.dart';
import 'models/teammate_location_model.dart';

class LocationLocalDataSource {
  LocationLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<void> upsertLocation(LocationUpdateModel location) async {
    final db = await _database.database;
    await db.insert(
      'location_updates',
      location.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markShared({
    required String localLocationId,
    String? serverLocationId,
    String syncState = 'synced',
  }) async {
    final db = await _database.database;
    await db.update(
      'location_updates',
      {
        'server_location_id': serverLocationId,
        'share_status': 'shared',
        'sync_state': syncState,
      },
      where: 'local_location_id = ?',
      whereArgs: [localLocationId],
    );
  }

  Future<List<LocationUpdateModel>> pendingSyncLocations() async {
    final db = await _database.database;
    final rows = await db.query(
      'location_updates',
      where: 'group_id IS NOT NULL AND sync_state = ?',
      whereArgs: ['needs_sync'],
      orderBy: 'captured_at ASC',
    );
    return rows.map(LocationUpdateModel.fromDb).toList();
  }

  Future<LocationUpdateModel?> latestOwnLocation(String userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'location_updates',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LocationUpdateModel.fromDb(rows.first);
  }

  Future<void> upsertTeammateLocation(TeammateLocationModel location) async {
    final db = await _database.database;
    await db.insert(
      'teammate_locations',
      location.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TeammateLocationModel>> teammateLocations({
    String? groupId,
    String? offlineChannelId,
  }) async {
    final db = await _database.database;
    String? where;
    List<Object?>? whereArgs;
    if (groupId != null) {
      where = 'group_id = ?';
      whereArgs = [groupId];
    } else if (offlineChannelId != null) {
      where = 'offline_channel_id = ?';
      whereArgs = [offlineChannelId];
    }
    final rows = await db.query(
      'teammate_locations',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'captured_at DESC',
    );
    return rows.map(TeammateLocationModel.fromDb).toList();
  }

  Future<void> enqueueLocationPacket({
    required String packetId,
    required String localLocationId,
    required String? offlineChannelId,
    required String? channelCode,
    required String payloadJson,
  }) async {
    final db = await _database.database;
    await db.insert(
      'location_packet_queue',
      {
        'packet_id': packetId,
        'local_location_id': localLocationId,
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
