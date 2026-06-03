import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/nearby_connection_status.dart';
import 'models/nearby_peer_model.dart';

class NearbyLocalDataSource {
  NearbyLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<List<NearbyPeerModel>> getPeersForChannel(String channelCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'nearby_peers',
      where: 'active_channel_code = ? AND is_same_channel = 1',
      whereArgs: [channelCode],
      orderBy: 'last_seen_at DESC',
    );
    return NearbyPeerModel.collapseDuplicates(
      rows.map(NearbyPeerModel.fromDb),
    );
  }

  Future<void> upsertPeer(NearbyPeerModel peer) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(
        'nearby_peers',
        peer.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _collapseDuplicateRows(txn, peer.activeChannelCode);
    });
    await addEvent(peer.endpointId, peer.status.name);
  }

  Future<void> _collapseDuplicateRows(
    Transaction txn,
    String channelCode,
  ) async {
    final rows = await txn.query(
      'nearby_peers',
      where: 'active_channel_code = ? AND is_same_channel = 1',
      whereArgs: [channelCode],
      orderBy: 'last_seen_at DESC',
    );
    if (rows.length < 2) return;
    final collapsed = NearbyPeerModel.collapseDuplicates(
      rows.map(NearbyPeerModel.fromDb),
    );
    final keepEndpoints = collapsed.map((peer) => peer.endpointId).toSet();
    for (final row in rows) {
      final endpointId = row['endpoint_id']?.toString();
      if (endpointId == null || keepEndpoints.contains(endpointId)) continue;
      await txn.delete(
        'nearby_peers',
        where: 'endpoint_id = ?',
        whereArgs: [endpointId],
      );
    }
  }

  Future<void> updateStatus(
    String endpointId,
    PeerConnectionStatus status,
  ) async {
    final db = await _database.database;
    await db.update(
      'nearby_peers',
      {
        'connection_status': status.name,
        'last_seen_at': DateTime.now().toIso8601String(),
      },
      where: 'endpoint_id = ?',
      whereArgs: [endpointId],
    );
    await addEvent(endpointId, status.name);
  }

  Future<void> addEvent(
    String endpointId,
    String eventType, {
    String? details,
  }) async {
    final db = await _database.database;
    await db.insert('peer_connection_events', {
      'endpoint_id': endpointId,
      'event_type': eventType,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
