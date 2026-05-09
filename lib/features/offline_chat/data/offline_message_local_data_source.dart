import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/offline_ack_model.dart';
import 'models/offline_packet_model.dart';
import 'models/offline_text_message_model.dart';

class OfflineMessageLocalDataSource {
  OfflineMessageLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<List<OfflineTextMessageModel>> getMessages(String channelId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_messages',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      orderBy: 'created_at ASC',
    );
    return rows.map(OfflineTextMessageModel.fromDb).toList();
  }

  Future<void> upsertMessage(OfflineTextMessageModel message) async {
    final db = await _database.database;
    await db.insert(
      'offline_messages',
      message.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> messageExists(String messageId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_messages',
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> updateMessageStatus({
    required String messageId,
    required String deliveryStatus,
    String? ackStatus,
  }) async {
    final db = await _database.database;
    await db.update(
      'offline_messages',
      {
        'delivery_status': deliveryStatus,
        if (ackStatus != null) 'ack_status': ackStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> updateMessageStatusByPacket({
    required String packetId,
    required String deliveryStatus,
    String? ackStatus,
  }) async {
    final db = await _database.database;
    await db.update(
      'offline_messages',
      {
        'delivery_status': deliveryStatus,
        if (ackStatus != null) 'ack_status': ackStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'packet_id = ?',
      whereArgs: [packetId],
    );
  }

  Future<void> enqueuePacket(OfflinePacketModel packet) async {
    final db = await _database.database;
    await db.insert(
      'offline_packet_queue',
      {
        'packet_id': packet.packetId,
        'channel_id': packet.channelId,
        'channel_code': packet.channelCode,
        'packet_type': packet.packetType,
        'priority': packet.priority,
        'payload_json': packet.toJsonString(),
        'queue_status': 'pending',
        'retry_count': 0,
        'created_at': packet.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<OfflinePacketModel>> getQueuedPackets(String channelId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_packet_queue',
      where: 'channel_id = ? AND queue_status IN (?, ?)',
      whereArgs: [channelId, 'pending', 'failed'],
      orderBy:
          "CASE priority WHEN 'emergency' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END, created_at ASC",
    );
    return rows
        .map((row) => OfflinePacketModel.fromJsonString(
              row['payload_json'].toString(),
            ))
        .toList();
  }

  Future<void> markQueueStatus(
    String packetId,
    String status, {
    String? lastError,
  }) async {
    final db = await _database.database;
    await db.update(
      'offline_packet_queue',
      {
        'queue_status': status,
        if (lastError != null) 'last_error': lastError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'packet_id = ?',
      whereArgs: [packetId],
    );
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
    required OfflinePacketModel packet,
    required String action,
  }) async {
    final db = await _database.database;
    await db.insert(
      'processed_offline_packets',
      {
        'packet_id': packet.packetId,
        'channel_id': packet.channelId,
        'channel_code': packet.channelCode,
        'sender_id': packet.senderId,
        'processed_action': action,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> saveAck(OfflineAckModel ack) async {
    final db = await _database.database;
    await db.insert(
      'offline_acks',
      ack.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<NearbyPeerModel>> getConnectedPeers(String channelCode) async {
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
}
