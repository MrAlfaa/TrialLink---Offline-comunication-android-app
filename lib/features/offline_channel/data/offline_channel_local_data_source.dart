import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/offline_channel_member_model.dart';
import 'models/offline_channel_model.dart';
import 'models/offline_packet_model.dart';

class OfflineChannelLocalDataSource {
  OfflineChannelLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<List<OfflineChannelModel>> getChannels() async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'channel_status IN (?, ?)',
      whereArgs: ['active', 'inactive'],
      orderBy: 'is_active DESC, last_opened_at DESC, created_at DESC',
    );
    return rows.map(OfflineChannelModel.fromDb).toList();
  }

  Future<OfflineChannelModel?> getChannel(String channelId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelModel.fromDb(rows.first);
  }

  Future<OfflineChannelModel?> getChannelByCode(String channelCode) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'channel_code = ?',
      whereArgs: [channelCode.toUpperCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelModel.fromDb(rows.first);
  }

  Future<OfflineChannelModel?> getActiveChannelByFlag() async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'is_active = ? AND channel_status = ?',
      whereArgs: [1, 'active'],
      orderBy: 'last_opened_at DESC, updated_at DESC, created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelModel.fromDb(rows.first);
  }

  Future<int> countActiveMembers(String channelId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS member_count
      FROM offline_channel_members
      WHERE channel_id = ? AND membership_status = ?
      ''',
      [channelId, 'active'],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<OfflineChannelMemberModel?> getMember({
    required String channelId,
    required String userId,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channel_members',
      where: 'channel_id = ? AND user_id = ?',
      whereArgs: [channelId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelMemberModel.fromDb(rows.first);
  }

  Future<OfflineChannelModel?> getActiveChannel() async {
    final flagged = await getActiveChannelByFlag();
    if (flagged?.isUsable == true) return flagged;
    final activeId = await _database.readSetting('active_offline_channel_id');
    if (activeId == null || activeId.isEmpty) return null;
    final channel = await getChannel(activeId);
    return channel?.isUsable == true ? channel : null;
  }

  Future<void> insertChannel(OfflineChannelModel channel) async {
    final db = await _database.database;
    await db.insert(
      'offline_channels',
      channel.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> upsertMember(OfflineChannelMemberModel member) async {
    final db = await _database.database;
    await db.delete(
      'offline_channel_members',
      where: 'channel_id = ? AND user_id = ?',
      whereArgs: [member.channelId, member.userId],
    );
    await db.insert('offline_channel_members', member.toDbMap());
  }

  Future<List<OfflineChannelMemberModel>> getMembers(String channelId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channel_members',
      where: 'channel_id = ? AND membership_status = ?',
      whereArgs: [channelId, 'active'],
      orderBy:
          "CASE presence_status WHEN 'connected' THEN 0 WHEN 'nearby' THEN 1 WHEN 'recently_seen' THEN 2 WHEN 'disconnected' THEN 3 ELSE 4 END, last_seen_at DESC, joined_at ASC",
    );
    return rows.map(OfflineChannelMemberModel.fromDb).toList();
  }

  Future<void> updateMemberPresence({
    required String channelId,
    required String userId,
    required String presenceStatus,
    required String connectionStatus,
    required DateTime lastSeenAt,
    String? endpointId,
  }) async {
    final db = await _database.database;
    await db.update(
      'offline_channel_members',
      {
        'presence_status': presenceStatus,
        'connection_status': connectionStatus,
        'endpoint_id': endpointId,
        'last_seen_at': lastSeenAt.toIso8601String(),
      },
      where: 'channel_id = ? AND user_id = ?',
      whereArgs: [channelId, userId],
    );
  }

  Future<void> markMemberLeft({
    required String channelId,
    required String userId,
  }) async {
    final db = await _database.database;
    await db.update(
      'offline_channel_members',
      {
        'status': 'left',
        'membership_status': 'left',
        'presence_status': 'disconnected',
        'connection_status': 'disconnected',
        'last_seen_at': DateTime.now().toIso8601String(),
      },
      where: 'channel_id = ? AND user_id = ?',
      whereArgs: [channelId, userId],
    );
  }

  Future<void> clearActiveChannel(String channelId) async {
    final db = await _database.database;
    await db.update(
      'offline_channels',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    final activeId = await _database.readSetting('active_offline_channel_id');
    if (activeId == channelId) {
      await _database.upsertSetting('active_offline_channel_id', '');
    }
  }

  Future<void> markChannelStatus({
    required String channelId,
    required String channelStatus,
    String? endedByUserId,
    String? endedReason,
    DateTime? endedAt,
  }) async {
    final db = await _database.database;
    final now = DateTime.now();
    await db.update(
      'offline_channels',
      {
        'channel_status': channelStatus,
        if (channelStatus == 'ended' || channelStatus == 'inactive')
          'is_active': 0,
        if (channelStatus == 'ended')
          'ended_at': (endedAt ?? now).toIso8601String(),
        if (channelStatus == 'ended') 'ended_by_user_id': endedByUserId,
        if (channelStatus == 'ended') 'ended_reason': endedReason,
        'updated_at': now.toIso8601String(),
      },
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    if (channelStatus == 'ended') {
      await db.update(
        'offline_channel_members',
        {
          'presence_status': 'disconnected',
          'connection_status': 'disconnected',
          'last_seen_at': now.toIso8601String(),
        },
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
    }
    if (channelStatus == 'ended' || channelStatus == 'inactive') {
      final activeId = await _database.readSetting('active_offline_channel_id');
      if (activeId == channelId) {
        await _database.upsertSetting('active_offline_channel_id', '');
      }
    }
  }

  Future<void> sweepPresence({
    required String channelId,
    required DateTime now,
  }) async {
    final members = await getMembers(channelId);
    final db = await _database.database;
    final batch = db.batch();
    for (final member in members) {
      final lastSeen = member.lastSeenAt;
      if (lastSeen == null) continue;
      final age = now.difference(lastSeen);
      String? nextPresence;
      if (age >= const Duration(seconds: 120) &&
          member.presenceStatus != 'disconnected') {
        nextPresence = 'disconnected';
      } else if (age >= const Duration(seconds: 30) &&
          member.presenceStatus == 'connected') {
        nextPresence = 'recently_seen';
      }
      if (nextPresence == null) continue;
      batch.update(
        'offline_channel_members',
        {
          'presence_status': nextPresence,
          'connection_status':
              nextPresence == 'disconnected' ? 'disconnected' : 'connected',
        },
        where: 'channel_id = ? AND user_id = ?',
        whereArgs: [channelId, member.userId],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> setActiveChannel(String channelId) async {
    final db = await _database.database;
    final channel = await getChannel(channelId);
    if (channel == null) {
      throw StateError('Offline channel not found.');
    }
    if (!channel.isUsable) {
      throw StateError('Ended channels are read-only.');
    }
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('offline_channels', {'is_active': 0});
      await txn.update(
        'offline_channels',
        {
          'is_active': 1,
          'channel_status': 'active',
          'last_opened_at': now,
          'updated_at': now,
        },
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
    });
    await _database.upsertSetting('active_offline_channel_id', channelId);
  }

  Future<void> deleteChannel(String channelId) async {
    final db = await _database.database;
    await db.delete(
      'offline_channel_members',
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    await db.delete(
      'offline_channel_packets',
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    await db.delete(
      'offline_channels',
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );
    final activeId = await _database.readSetting('active_offline_channel_id');
    if (activeId == channelId) {
      await _database.upsertSetting('active_offline_channel_id', '');
    }
  }

  Future<bool> packetExists(String packetId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channel_packets',
      where: 'packet_id = ?',
      whereArgs: [packetId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> insertPacket(OfflinePacketModel packet) async {
    final db = await _database.database;
    await db.insert(
      'offline_channel_packets',
      packet.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
