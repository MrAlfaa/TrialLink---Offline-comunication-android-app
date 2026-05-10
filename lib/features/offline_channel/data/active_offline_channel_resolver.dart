import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/local_identity_repository.dart';
import 'models/offline_channel_member_model.dart';
import 'models/offline_channel_model.dart';
import 'offline_channel_repository.dart';

class ActiveOfflineChannelResolver {
  ActiveOfflineChannelResolver({
    LocalDatabase? database,
    OfflineChannelRepository? channelRepository,
    LocalIdentityRepository? identityRepository,
    Uuid? uuid,
  })  : _database = database ?? LocalDatabase.instance,
        _channelRepository = channelRepository ?? OfflineChannelRepository(),
        _identityRepository = identityRepository ?? LocalIdentityRepository(),
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final OfflineChannelRepository _channelRepository;
  final LocalIdentityRepository _identityRepository;
  final Uuid _uuid;

  Future<OfflineChannelModel?> getActiveOfflineChannel() async {
    final db = await _database.database;
    final flagged = await _flaggedActiveChannel(db);
    if (flagged != null) return flagged;

    final activeId = await _database.readSetting('active_offline_channel_id');
    if (activeId != null && activeId.isNotEmpty) {
      final rows = await db.query(
        'offline_channels',
        where: 'channel_id = ? AND channel_status = ?',
        whereArgs: [activeId, 'active'],
        limit: 1,
      );
      if (rows.isNotEmpty) return OfflineChannelModel.fromDb(rows.first);
    }
    return null;
  }

  Future<OfflineChannelModel?> getActiveOfflineChannelForActiveTrip() async {
    final trip = await _activeOfflineTrip();
    if (trip == null) return null;
    return _channelForTrip(trip, repair: true);
  }

  Future<OfflineChannelModel?> getActiveUsableOfflineChannel() async {
    await repairActiveChannelFromActiveTripIfNeeded();
    final channel = await getActiveOfflineChannel() ??
        await getActiveOfflineChannelForActiveTrip();
    if (channel == null || channel.channelCode.trim().isEmpty) return null;
    if (channel.channelStatus != 'active') return null;
    if (!await _ensureCurrentUserMembershipIfNeeded(channel)) return null;
    return channel;
  }

  Future<bool> hasActiveUsableOfflineChannel() async {
    return (await getActiveUsableOfflineChannel()) != null;
  }

  Future<List<OfflineChannelModel>> repairAndListChannels() async {
    await repairActiveChannelFromActiveTripIfNeeded();
    return _channelRepository.getChannels();
  }

  Future<void> setActiveChannel(String channelId) {
    return _channelRepository.setActiveChannel(channelId);
  }

  Future<void> repairActiveChannelFromActiveTripIfNeeded() async {
    final active = await getActiveOfflineChannel();
    if (active != null) return;
    final trip = await _activeOfflineTrip();
    if (trip == null) return;
    final channel = await _channelForTrip(trip, repair: true);
    if (channel == null || channel.isEnded) return;
    await _activateOnly(channel.channelId);
  }

  Future<Map<String, Object?>> diagnostics() async {
    final db = await _database.database;
    final trip = await _activeOfflineTrip();
    final channel = await getActiveUsableOfflineChannel() ??
        await getActiveOfflineChannel();
    final identity = await _identityRepository.getCurrentIdentity();
    return {
      'activeTripId': trip?['trip_id'],
      'activeTripName': trip?['trip_name'],
      'activeTripMode': trip?['mode'],
      'activeTripStatus': trip?['status'],
      'trip offline_channel_id': trip?['offline_channel_id'],
      'trip channel_code': trip?['channel_code'],
      'channelId': channel?.channelId,
      'channelCode': channel?.channelCode,
      'channelStatus': channel?.channelStatus,
      'channelIsActive': channel?.isActive,
      'localIdentityId': identity?.localUserId,
      'memberCount': channel == null
          ? 0
          : Sqflite.firstIntValue(
                await db.rawQuery(
                  'SELECT COUNT(*) FROM offline_channel_members WHERE channel_id = ?',
                  [channel.channelId],
                ),
              ) ??
              0,
      'Resolver result': channel == null
          ? await _nullReason(trip)
          : 'Resolved ${channel.channelCode}',
    };
  }

  Future<OfflineChannelModel?> _flaggedActiveChannel(Database db) async {
    final rows = await db.query(
      'offline_channels',
      where: 'is_active = ? AND channel_status = ?',
      whereArgs: [1, 'active'],
      orderBy: 'last_opened_at DESC, updated_at DESC, created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelModel.fromDb(rows.first);
  }

  Future<Map<String, Object?>?> _activeOfflineTrip() async {
    final db = await _database.database;
    final rows = await db.query(
      'trip_sessions',
      where: 'status = ? AND mode IN (?, ?)',
      whereArgs: ['active', 'offline', 'hybrid'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<OfflineChannelModel?> _channelForTrip(
    Map<String, Object?> trip, {
    required bool repair,
  }) async {
    final channelId = _value(trip['offline_channel_id']);
    final channelCode = _value(trip['channel_code'])?.toUpperCase();
    OfflineChannelModel? channel;
    if (channelId != null) {
      channel = await _channelRepository.getChannel(channelId);
    }
    if (channel == null && channelCode != null) {
      channel = await _channelRepository.getChannelByCode(channelCode);
    }
    if (channel != null) {
      if (repair && !channel.isActive && !channel.isEnded) {
        await _activateOnly(channel.channelId);
        return _channelRepository.getChannel(channel.channelId);
      }
      return channel;
    }
    if (!repair || channelCode == null || channelCode.isEmpty) return null;
    return _createRepairedChannel(trip, channelCode);
  }

  Future<OfflineChannelModel?> _createRepairedChannel(
    Map<String, Object?> trip,
    String channelCode,
  ) async {
    final identity = await _identityRepository.getCurrentIdentity();
    final localUserId =
        identity?.localUserId ?? _value(trip['local_identity_id']);
    if (localUserId == null || localUserId.isEmpty) return null;

    final db = await _database.database;
    final now = DateTime.now();
    final channelId = _value(trip['offline_channel_id']) ?? _uuid.v4();
    final channel = OfflineChannelModel(
      channelId: channelId,
      channelCode: channelCode,
      channelName: _value(trip['channel_name']) ??
          _value(trip['trip_name']) ??
          'Offline Trip $channelCode',
      description: 'Recovered from active trip session.',
      createdByUserId: localUserId,
      createdByName: identity?.displayName,
      isActive: true,
      channelStatus: 'active',
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );
    await db.transaction((txn) async {
      await txn.update('offline_channels', {'is_active': 0});
      await txn.insert(
        'offline_channels',
        channel.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'offline_channels',
        {
          'is_active': 1,
          'channel_status': 'active',
          'last_opened_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'channel_id = ? OR channel_code = ?',
        whereArgs: [channelId, channelCode],
      );
    });
    await _database.upsertSetting('active_offline_channel_id', channelId);
    await _ensureLocalMembership(
      channel: channel,
      localUserId: localUserId,
      displayName: identity?.displayName,
    );
    return await _channelRepository.getChannel(channelId) ??
        await _channelRepository.getChannelByCode(channelCode);
  }

  Future<void> _activateOnly(String channelId) async {
    await _channelRepository.setActiveChannel(channelId);
    await _database.upsertSetting('active_offline_channel_id', channelId);
  }

  Future<void> _ensureLocalMembership({
    required OfflineChannelModel channel,
    required String localUserId,
    required String? displayName,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channel_members',
      where: 'channel_id = ? AND user_id = ?',
      whereArgs: [channel.channelId, localUserId],
      limit: 1,
    );
    final now = DateTime.now();
    if (rows.isNotEmpty) {
      await db.update(
        'offline_channel_members',
        {
          'status': 'active',
          'membership_status': 'active',
          'presence_status': 'connected',
          'connection_status': 'connected',
          'last_seen_at': now.toIso8601String(),
        },
        where: 'channel_id = ? AND user_id = ?',
        whereArgs: [channel.channelId, localUserId],
      );
      return;
    }
    final memberRole =
        channel.createdByUserId == localUserId ? 'owner' : 'member';
    await db.insert(
      'offline_channel_members',
      OfflineChannelMemberModel(
        channelId: channel.channelId,
        userId: localUserId,
        displayName: displayName ?? 'TrailLink User',
        memberRole: memberRole,
        source: 'local',
        status: 'active',
        membershipStatus: 'active',
        presenceStatus: 'connected',
        connectionStatus: 'connected',
        identityType: 'local_only',
        joinedAt: now,
        lastSeenAt: now,
      ).toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> _ensureCurrentUserMembershipIfNeeded(
    OfflineChannelModel channel,
  ) async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) return true;
    final db = await _database.database;
    final localRows = await db.query(
      'offline_channel_members',
      where: 'channel_id = ? AND user_id = ? AND membership_status = ?',
      whereArgs: [channel.channelId, identity.localUserId, 'active'],
      limit: 1,
    );
    if (localRows.isNotEmpty) return true;
    await _ensureLocalMembership(
      channel: channel,
      localUserId: identity.localUserId,
      displayName: identity.displayName,
    );
    return true;
  }

  Future<String> _nullReason(Map<String, Object?>? trip) async {
    if (trip == null) return 'No active offline/hybrid trip.';
    if (_value(trip['channel_code']) == null &&
        _value(trip['offline_channel_id']) == null) {
      return 'Active trip has no offline channel id or code.';
    }
    return 'Active trip references a channel that could not be resolved.';
  }

  String? _value(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
