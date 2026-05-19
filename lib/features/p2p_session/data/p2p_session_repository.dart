import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/p2p_peer_connection_model.dart';
import 'models/p2p_session_model.dart';
import 'models/p2p_session_state.dart';

final p2pSessionRepositoryProvider = Provider<P2PSessionRepository>((ref) {
  return P2PSessionRepository();
});

class P2PSessionRepository {
  P2PSessionRepository({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<P2PSessionModel?> getActiveSession() async {
    final db = await _database.database;
    final rows = await db.query(
      'p2p_connection_sessions',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : P2PSessionModel.fromDb(rows.first);
  }

  Future<P2PSessionModel?> findActiveSessionForTrip(String tripId) async {
    final session = await getActiveSession();
    return session?.tripId == tripId ? session : null;
  }

  Future<P2PSessionModel> upsertActiveSession({
    required String sessionId,
    required String tripId,
    required String channelId,
    required String channelCode,
    required String localUserId,
    required P2PSessionState state,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'p2p_connection_sessions',
        {'is_active': 0},
        where: 'is_active = ? AND session_id != ?',
        whereArgs: [1, sessionId],
      );
      await txn.insert(
        'p2p_connection_sessions',
        {
          'session_id': sessionId,
          'trip_id': tripId,
          'channel_id': channelId,
          'channel_code': channelCode,
          'local_user_id': localUserId,
          'state': state.name,
          'started_at': now,
          'last_activity_at': now,
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    final active = await getActiveSession();
    if (active == null) {
      throw StateError('P2P session could not be created.');
    }
    return active;
  }

  Future<void> updateActiveSessionState(
    P2PSessionState state, {
    String? errorMessage,
    bool endSession = false,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'p2p_connection_sessions',
      {
        'state': state.name,
        'last_activity_at': now,
        if (endSession) 'ended_at': now,
        if (endSession) 'is_active': 0,
        'error_message': errorMessage,
      },
      where: 'is_active = ?',
      whereArgs: [1],
    );
  }

  Future<List<P2PPeerConnectionModel>> getPeersForSession(
    String sessionId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'p2p_connected_peers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'COALESCE(last_heartbeat_at, last_seen_at, created_at) DESC',
    );
    return rows.map(P2PPeerConnectionModel.fromDb).toList();
  }

  Future<List<P2PPeerConnectionModel>> getActiveSessionPeers() async {
    final session = await getActiveSession();
    if (session == null) return const [];
    return getPeersForSession(session.sessionId);
  }

  Future<void> upsertPeer({
    required P2PSessionModel session,
    String? endpointId,
    String? peerLocalId,
    String? peerPublicUserId,
    String? peerDisplayName,
    required P2PPeerConnectionState state,
    bool heartbeat = false,
  }) async {
    if ((endpointId ?? '').isEmpty && (peerLocalId ?? '').isEmpty) return;
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'p2p_connected_peers',
      where: 'session_id = ? AND (endpoint_id = ? OR peer_local_id = ?)',
      whereArgs: [session.sessionId, endpointId, peerLocalId],
      limit: 1,
    );
    final values = {
      'session_id': session.sessionId,
      'trip_id': session.tripId,
      'channel_id': session.channelId,
      'channel_code': session.channelCode,
      'endpoint_id': endpointId,
      'peer_local_id': peerLocalId,
      'peer_public_user_id': peerPublicUserId,
      'peer_display_name': peerDisplayName,
      'connection_state': state.name,
      'last_seen_at': now,
      if (heartbeat) 'last_heartbeat_at': now,
      'created_at': now,
      'updated_at': now,
    };
    if (existing.isEmpty) {
      await db.insert(
        'p2p_connected_peers',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }
    await db.update(
      'p2p_connected_peers',
      {
        'endpoint_id': endpointId ?? existing.first['endpoint_id'],
        'peer_local_id': peerLocalId ?? existing.first['peer_local_id'],
        'peer_public_user_id':
            peerPublicUserId ?? existing.first['peer_public_user_id'],
        'peer_display_name':
            peerDisplayName ?? existing.first['peer_display_name'],
        'connection_state': state.name,
        'last_seen_at': now,
        if (heartbeat) 'last_heartbeat_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [existing.first['id']],
    );
  }

  Future<void> updatePeerState(
    String endpointId,
    P2PPeerConnectionState state,
  ) async {
    if (endpointId.isEmpty) return;
    final db = await _database.database;
    await db.update(
      'p2p_connected_peers',
      {
        'connection_state': state.name,
        'last_seen_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'endpoint_id = ?',
      whereArgs: [endpointId],
    );
  }

  Future<void> updatePeerStateByLocalId(
    String peerLocalId,
    P2PPeerConnectionState state,
  ) async {
    if (peerLocalId.isEmpty) return;
    final db = await _database.database;
    await db.update(
      'p2p_connected_peers',
      {
        'connection_state': state.name,
        'last_seen_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'peer_local_id = ?',
      whereArgs: [peerLocalId],
    );
  }

  Future<void> markAllPeers(
    String sessionId,
    P2PPeerConnectionState state,
  ) async {
    final db = await _database.database;
    await db.update(
      'p2p_connected_peers',
      {
        'connection_state': state.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> cleanupStalePeers({
    Duration staleAfter = const Duration(seconds: 30),
    Duration lostAfter = const Duration(seconds: 120),
  }) async {
    final db = await _database.database;
    final now = DateTime.now();
    final peers = await db.query(
      'p2p_connected_peers',
      where: 'connection_state IN (?, ?)',
      whereArgs: [
        P2PPeerConnectionState.connected.name,
        P2PPeerConnectionState.stale.name,
      ],
    );
    for (final row in peers) {
      final heartbeat =
          DateTime.tryParse(row['last_heartbeat_at']?.toString() ?? '') ??
              DateTime.tryParse(row['last_seen_at']?.toString() ?? '');
      if (heartbeat == null) continue;
      final age = now.difference(heartbeat);
      if (age >= lostAfter) {
        await _updatePeerRowState(
            row['id'] as int, P2PPeerConnectionState.lost);
      } else if (age >= staleAfter) {
        await _updatePeerRowState(
          row['id'] as int,
          P2PPeerConnectionState.stale,
        );
      }
    }
  }

  Future<void> _updatePeerRowState(
    int id,
    P2PPeerConnectionState state,
  ) async {
    final db = await _database.database;
    await db.update(
      'p2p_connected_peers',
      {
        'connection_state': state.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
