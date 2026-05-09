import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import 'models/group_member_model.dart';
import 'models/group_model.dart';

class GroupLocalDataSource {
  GroupLocalDataSource({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<List<GroupModel>> loadGroups() async {
    final db = await _database.database;
    final rows = await db.query(
      'local_groups',
      where: 'status NOT IN (?, ?)',
      whereArgs: ['archived', 'left'],
      orderBy: 'COALESCE(last_synced_at, updated_at, created_at) DESC',
    );
    return rows.map(GroupModel.fromDb).toList();
  }

  Future<GroupModel?> loadGroup(String groupId) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    return rows.isEmpty ? null : GroupModel.fromDb(rows.first);
  }

  Future<void> upsertGroups(List<GroupModel> groups) async {
    final db = await _database.database;
    final batch = db.batch();
    for (final group in groups) {
      batch.insert(
        'local_groups',
        group.toLocalDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<GroupMemberModel>> loadMembers(String groupId) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_group_members',
      where: 'group_id = ? AND membership_status = ?',
      whereArgs: [groupId, 'active'],
      orderBy: 'role ASC, display_name ASC',
    );
    return rows.map(GroupMemberModel.fromDb).toList();
  }

  Future<void> upsertMembers(
    String groupId,
    List<GroupMemberModel> members,
  ) async {
    final db = await _database.database;
    final batch = db.batch();
    for (final member in members) {
      batch.insert(
        'local_group_members',
        member.toLocalDbMap(fallbackGroupId: groupId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markMemberStatus({
    required String groupId,
    required String memberId,
    required String membershipStatus,
  }) async {
    final db = await _database.database;
    await db.update(
      'local_group_members',
      {
        'membership_status': membershipStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'group_id = ? AND (user_id = ? OR local_user_id = ?)',
      whereArgs: [groupId, memberId, memberId],
    );
  }

  Future<void> markCurrentGroupLeft(String groupId) async {
    final db = await _database.database;
    await db.update(
      'local_groups',
      {
        'status': 'left',
        'sync_state': 'synced',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  Future<void> markGroupArchived(String groupId) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'local_groups',
      {
        'status': 'archived',
        'sync_state': 'synced',
        'updated_at': now,
      },
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    await db.update(
      'local_group_members',
      {
        'membership_status': 'removed',
        'presence_status': 'offline',
        'updated_at': now,
      },
      where: 'group_id = ? AND membership_status = ?',
      whereArgs: [groupId, 'active'],
    );
  }

  Future<void> markGroupSyncState({
    required String groupId,
    required String syncState,
    String? errorMessage,
  }) async {
    final db = await _database.database;
    await db.update(
      'local_groups',
      {
        'sync_state': syncState,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }
}
