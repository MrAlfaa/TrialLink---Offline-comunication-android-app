import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/chat_message_model.dart';

class MessageDao {
  MessageDao({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<List<ChatMessageModel>> getMessagesForGroup(String groupId) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_messages',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ChatMessageModel.fromDb).toList();
  }

  Future<void> upsertMessage(ChatMessageModel message) async {
    final db = await _database.database;
    await db.insert(
      'local_messages',
      message.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertMessages(List<ChatMessageModel> messages) async {
    for (final message in messages) {
      await upsertRemoteMessage(message);
    }
  }

  Future<void> upsertRemoteMessage(ChatMessageModel remote) async {
    final db = await _database.database;
    final existing = await findByClientMessageId(remote.clientMessageId) ??
        await findByServerId(remote.serverId);
    final message = existing == null
        ? remote
        : ChatMessageModel.mergeLocalWithRemote(
            local: existing,
            remote: remote,
          );
    await db.insert(
      'local_messages',
      message.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ChatMessageModel?> findByClientMessageId(
      String clientMessageId) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_messages',
      where: 'client_message_id = ?',
      whereArgs: [clientMessageId],
      limit: 1,
    );
    return rows.isEmpty ? null : ChatMessageModel.fromDb(rows.first);
  }

  Future<ChatMessageModel?> findByServerId(String? serverId) async {
    if (serverId == null || serverId.isEmpty) return null;
    final db = await _database.database;
    final rows = await db.query(
      'local_messages',
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : ChatMessageModel.fromDb(rows.first);
  }

  Future<void> updateDeliveryStatus({
    required String clientMessageId,
    required String deliveryStatus,
    String? serverId,
    String syncState = 'synced',
  }) async {
    final db = await _database.database;
    await db.update(
      'local_messages',
      {
        if (serverId != null) 'server_id': serverId,
        'delivery_status': deliveryStatus,
        'sync_state': syncState,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'client_message_id = ?',
      whereArgs: [clientMessageId],
    );
  }

  Future<void> updateMediaUploadStatus({
    required String clientMessageId,
    required String uploadStatus,
    String? remoteUrl,
    String? serverId,
    String? deliveryStatus,
    String? syncState,
    String? lastError,
  }) async {
    final db = await _database.database;
    final values = <String, Object?>{
      'upload_status': uploadStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (remoteUrl != null) values['remote_url'] = remoteUrl;
    if (serverId != null) values['server_id'] = serverId;
    if (deliveryStatus != null) values['delivery_status'] = deliveryStatus;
    if (syncState != null) values['sync_state'] = syncState;
    await db.update(
      'local_messages',
      values,
      where: 'client_message_id = ?',
      whereArgs: [clientMessageId],
    );
    if (lastError != null) {
      await markQueueFailed(clientMessageId, lastError);
    }
  }

  Future<void> enqueueOutgoingMessage(ChatMessageModel message) async {
    final db = await _database.database;
    final payload = jsonEncode({
      'groupId': message.groupId,
      ...message.toSyncJson(),
    });
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'message_queue',
      {
        'client_message_id': message.clientMessageId,
        'group_id': message.groupId,
        'trip_id': message.tripId,
        'channel_id': message.channelId,
        'chat_id': message.chatId,
        'payload_json': payload,
        'queue_status': 'pending',
        'context_type': 'online_group',
        'context_id': message.groupId,
        'retry_count': 0,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'sync_queue',
      {
        'entity_type': 'message',
        'entity_id': message.clientMessageId,
        'operation': 'create',
        'payload_json': payload,
        'status': 'pending',
        'context_type': 'online_group',
        'context_id': message.groupId,
        'retry_count': 0,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markQueuesCompleted(String clientMessageId) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'message_queue',
      {'queue_status': 'completed', 'updated_at': now},
      where: 'client_message_id = ?',
      whereArgs: [clientMessageId],
    );
    await db.update(
      'sync_queue',
      {'status': 'completed', 'updated_at': now},
      where: 'entity_id = ? AND entity_type = ?',
      whereArgs: [clientMessageId, 'message'],
    );
  }

  Future<void> markQueueFailed(String clientMessageId, String error) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE message_queue
      SET queue_status = ?, retry_count = retry_count + 1, last_error = ?, updated_at = ?
      WHERE client_message_id = ?
      ''',
      ['failed', error, now, clientMessageId],
    );
    await db.rawUpdate(
      '''
      UPDATE sync_queue
      SET status = ?, retry_count = retry_count + 1, last_error = ?, updated_at = ?
      WHERE entity_id = ? AND entity_type = ?
      ''',
      ['failed', error, now, clientMessageId, 'message'],
    );
  }

  Future<List<Map<String, dynamic>>> pendingSyncRows() async {
    final db = await _database.database;
    return db.query(
      'sync_queue',
      where: 'entity_type = ? AND status IN (?, ?) AND retry_count < ?',
      whereArgs: ['message', 'pending', 'failed', 3],
      orderBy: 'created_at ASC',
    );
  }
}
