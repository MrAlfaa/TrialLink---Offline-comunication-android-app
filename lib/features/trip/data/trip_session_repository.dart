import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/local_identity_model.dart';
import '../../../core/mode/mode_models.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/data/models/group_model.dart';
import '../../offline_channel/data/offline_channel_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import 'trip_session_model.dart';

final tripSessionRepositoryProvider = Provider<TripSessionRepository>((ref) {
  return TripSessionRepository();
});

class TripSessionRepository {
  TripSessionRepository({
    LocalDatabase? database,
    OfflineChannelRepository? offlineChannelRepository,
    Uuid? uuid,
  })  : _database = database ?? LocalDatabase.instance,
        _offlineChannelRepository =
            offlineChannelRepository ?? OfflineChannelRepository(),
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final OfflineChannelRepository _offlineChannelRepository;
  final Uuid _uuid;
  static const activeOnlineTripSettingKey = 'active_online_trip_id';
  static const activeOfflineTripSettingKey = 'active_offline_trip_id';

  Future<TripSessionModel?> getActiveTrip() async {
    final db = await _database.database;
    final rows = await db.query(
      'trip_sessions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : TripSessionModel.fromDb(rows.first);
  }

  Future<TripSessionModel?> getActiveTripForMode(EffectiveMode mode) async {
    final db = await _database.database;
    final key = _activeTripSettingKeyForMode(mode);
    final selectedTripId = await _database.readSetting(key);
    if (selectedTripId != null && selectedTripId.trim().isNotEmpty) {
      final selected = await getTrip(selectedTripId);
      if (selected != null &&
          _matchesEffectiveMode(selected, mode) &&
          _isUsableTripStatus(selected.status)) {
        return selected;
      }
    }

    final rows = await db.query(
      'trip_sessions',
      where: '${_modeWhereClause(mode)} AND status NOT IN (?, ?)',
      whereArgs: [..._modeWhereArgs(mode), 'archived', 'completed'],
      orderBy:
          "CASE status WHEN 'active' THEN 0 ELSE 1 END, COALESCE(last_opened_at, started_at, created_at) DESC",
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final fallback = TripSessionModel.fromDb(rows.first);
    await _database.upsertSetting(key, fallback.tripId);
    return fallback;
  }

  Future<void> setActiveTripForMode(
    EffectiveMode mode,
    String tripId,
  ) async {
    final trip = await getTrip(tripId);
    if (trip == null) {
      throw StateError('Trip not found.');
    }
    if (!_matchesEffectiveMode(trip, mode)) {
      throw StateError('Trip does not belong to the selected mode.');
    }
    await _markTripActiveWithinMode(trip);
    await _database.upsertSetting(_activeTripSettingKeyForMode(mode), tripId);
    final channelId = trip.activeChannelId ?? trip.offlineChannelId;
    if (trip.mode == 'offline' && channelId != null && channelId.isNotEmpty) {
      await _activateTripChannel(tripId: tripId, channelId: channelId);
    }
  }

  Future<List<TripSessionModel>> getTrips() async {
    final db = await _database.database;
    final rows = await db.query(
      'trip_sessions',
      orderBy: 'status ASC, started_at DESC',
    );
    return rows.map(TripSessionModel.fromDb).toList();
  }

  Future<TripSessionModel?> getTrip(String tripId) async {
    final db = await _database.database;
    final rows = await db.query(
      'trip_sessions',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    return rows.isEmpty ? null : TripSessionModel.fromDb(rows.first);
  }

  Future<TripSessionModel> createOfflineTrip({
    required String tripName,
    required LocalIdentityModel identity,
    String? customChannelCode,
    bool activate = true,
  }) async {
    _validateTripName(tripName);
    final channel = await _offlineChannelRepository.createChannelForIdentity(
      identity: identity,
      channelName: tripName.trim(),
      description: 'Offline trip channel for ${tripName.trim()}.',
      customCode: customChannelCode,
      activate: activate,
    );
    return createTripFromOfflineChannel(
      tripName: tripName,
      offlineChannelId: channel.channelId,
      channelCode: channel.channelCode,
      channelName: channel.channelName,
      localIdentityId: identity.localUserId,
      activate: activate,
    );
  }

  Future<TripSessionModel> createOfflineOnlyTrip({
    required String tripName,
    required LocalIdentityModel identity,
    String? customChannelCode,
    bool activate = true,
  }) {
    return createOfflineTrip(
      tripName: tripName,
      identity: identity,
      customChannelCode: customChannelCode,
      activate: activate,
    );
  }

  Future<TripSessionModel> createCloudBackupTrip({
    required String tripName,
    required String description,
    required LocalIdentityModel identity,
    GroupRepository? groupRepository,
    String? customChannelCode,
  }) async {
    _validateTripName(tripName);
    GroupModel? group;
    if (groupRepository != null) {
      try {
        group = await groupRepository.createGroup(
          groupName: tripName.trim(),
          description: description.trim(),
        );
      } catch (_) {
        group = null;
      }
    }

    final channel = await _offlineChannelRepository.createChannelForIdentity(
      identity: identity,
      channelName: tripName.trim(),
      description: description.trim().isEmpty
          ? 'Offline support channel for ${tripName.trim()}.'
          : description.trim(),
      customCode: customChannelCode,
    );
    return _insertHybridTrip(
      tripName: tripName.trim(),
      identity: identity,
      group: group,
      channel: channel,
      syncState: group == null ? 'needs_sync' : 'server_synced',
    );
  }

  Future<TripSessionModel> joinOfflineTrip({
    required String channelCode,
    required LocalIdentityModel identity,
    String? tripName,
    bool activate = true,
  }) async {
    final normalized = normalizeChannelCode(channelCode);
    final channel = await _offlineChannelRepository.joinChannelForIdentity(
      identity: identity,
      channelCode: normalized,
      activate: activate,
    );
    return createTripFromOfflineChannel(
      tripName: (tripName?.trim().isNotEmpty ?? false)
          ? tripName!.trim()
          : 'Offline Trip $normalized',
      offlineChannelId: channel.channelId,
      channelCode: channel.channelCode,
      channelName: channel.channelName,
      localIdentityId: identity.localUserId,
      activate: activate,
    );
  }

  Future<TripSessionModel> joinExistingTrip({
    required String tripCode,
    required LocalIdentityModel identity,
    GroupRepository? groupRepository,
    bool tryCloud = true,
  }) async {
    GroupModel? group;
    if (tryCloud && groupRepository != null) {
      try {
        group = await groupRepository.joinGroup(groupCode: tripCode.trim());
      } catch (_) {
        group = null;
      }
    }
    if (group == null) {
      return joinOfflineTrip(
        channelCode: tripCode,
        identity: identity,
        tripName: null,
      );
    }

    OfflineChannelModel channel;
    try {
      channel = await _offlineChannelRepository.joinChannelForIdentity(
        identity: identity,
        channelCode: group.groupCode,
      );
    } catch (_) {
      channel = await _offlineChannelRepository.createChannelForIdentity(
        identity: identity,
        channelName: group.groupName,
        description: 'Offline support channel for ${group.groupName}.',
      );
    }
    return _insertHybridTrip(
      tripName: group.groupName,
      identity: identity,
      group: group,
      channel: channel,
      syncState: 'server_synced',
    );
  }

  Future<TripSessionModel> createTripFromOfflineChannel({
    required String tripName,
    required String offlineChannelId,
    required String channelCode,
    required String localIdentityId,
    String? channelName,
    bool activate = true,
  }) async {
    _validateTripName(tripName);
    final trip = _buildTrip(
      tripName: tripName.trim(),
      mode: 'offline',
      localIdentityId: localIdentityId,
      offlineChannelId: offlineChannelId,
      activeChannelId: offlineChannelId,
      channelCode: normalizeChannelCode(channelCode),
      channelName: channelName,
    );
    return activate ? _insertAsActive(trip) : _insertAsInactive(trip);
  }

  Future<TripSessionModel> activateOfflineChannelTrip({
    required OfflineChannelModel channel,
    required LocalIdentityModel identity,
    String? tripName,
  }) async {
    await _offlineChannelRepository.setActiveChannel(channel.channelId);
    final normalizedCode = normalizeChannelCode(channel.channelCode);
    final db = await _database.database;
    final rows = await db.query(
      'trip_sessions',
      where: 'mode IN (?, ?) AND (offline_channel_id = ? OR channel_code = ?)',
      whereArgs: [
        'offline',
        'hybrid',
        channel.channelId,
        normalizedCode,
      ],
      orderBy: "CASE status WHEN 'active' THEN 0 ELSE 1 END, started_at DESC",
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = TripSessionModel.fromDb(rows.first);
      await updateTripChannel(
        tripId: existing.tripId,
        offlineChannelId: channel.channelId,
        channelCode: normalizedCode,
      );
      await setActiveTrip(existing.tripId);
      return (await getActiveTrip()) ?? existing;
    }

    return createTripFromOfflineChannel(
      tripName: (tripName?.trim().isNotEmpty ?? false)
          ? tripName!.trim()
          : channel.channelName,
      offlineChannelId: channel.channelId,
      channelCode: normalizedCode,
      channelName: channel.channelName,
      localIdentityId: identity.localUserId,
    );
  }

  Future<TripSessionModel> createOnlineTripFromGroup({
    required GroupModel group,
    required String localIdentityId,
  }) async {
    final trip = _buildTrip(
      tripName: group.groupName,
      mode: 'online',
      localIdentityId: localIdentityId,
      cloudGroupId: group.id,
      cloudGroupName: group.groupName,
      syncState: 'server_synced',
    );
    return _insertAsActive(trip);
  }

  Future<TripSessionModel> _insertHybridTrip({
    required String tripName,
    required LocalIdentityModel identity,
    required OfflineChannelModel channel,
    GroupModel? group,
    String syncState = 'local_only',
  }) {
    final trip = _buildTrip(
      tripName: tripName,
      mode: 'hybrid',
      localIdentityId: identity.localUserId,
      cloudGroupId: group?.id,
      cloudGroupName: group?.groupName,
      offlineChannelId: channel.channelId,
      activeChannelId: channel.channelId,
      channelCode: channel.channelCode,
      channelName: channel.channelName,
      syncState: syncState,
    );
    return _insertAsActive(trip);
  }

  Future<void> setActiveTrip(String tripId) async {
    final trip = await getTrip(tripId);
    if (trip == null) throw StateError('Trip not found.');
    await _markTripActiveWithinMode(trip);
    await _database.upsertSetting(_settingKeyForTrip(trip), tripId);
    final channelId = trip.activeChannelId ?? trip.offlineChannelId;
    if (trip.mode == 'offline' && channelId != null && channelId.isNotEmpty) {
      await _activateTripChannel(tripId: tripId, channelId: channelId);
    }
  }

  Future<void> completeTrip(String tripId) async {
    await _updateStatus(tripId, 'completed', endedAt: DateTime.now());
  }

  Future<void> archiveTrip(String tripId) async {
    await _updateStatus(tripId, 'archived');
  }

  Future<void> updateTripChannel({
    required String tripId,
    required String offlineChannelId,
    required String channelCode,
  }) async {
    final db = await _database.database;
    await db.update(
      'trip_sessions',
      {
        'offline_channel_id': offlineChannelId,
        'active_channel_id': offlineChannelId,
        'channel_code': normalizeChannelCode(channelCode),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
  }

  Future<void> clearActiveTrip() async {
    final db = await _database.database;
    await db.update(
      'trip_sessions',
      {'status': 'inactive', 'updated_at': DateTime.now().toIso8601String()},
      where: 'status = ?',
      whereArgs: ['active'],
    );
  }

  String normalizeChannelCode(String value) {
    final code = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(code)) {
      throw StateError(
        'Invalid channel code. Use uppercase letters, numbers, and hyphens.',
      );
    }
    return code;
  }

  TripSessionModel _buildTrip({
    required String tripName,
    required String mode,
    required String localIdentityId,
    String? cloudGroupId,
    String? cloudGroupName,
    String? offlineChannelId,
    String? activeChannelId,
    String? channelCode,
    String? channelName,
    String syncState = 'local_only',
  }) {
    final now = DateTime.now();
    return TripSessionModel(
      tripId: _uuid.v4(),
      tripName: tripName,
      mode: mode,
      cloudGroupId: cloudGroupId,
      cloudGroupName: cloudGroupName,
      offlineChannelId: offlineChannelId,
      activeChannelId: activeChannelId ?? offlineChannelId,
      channelCode: channelCode,
      channelName: channelName,
      localIdentityId: localIdentityId,
      status: 'active',
      startedAt: now,
      syncState: syncState,
      createdAt: now,
      lastOpenedAt: now,
      updatedAt: now,
    );
  }

  Future<TripSessionModel> _insertAsActive(TripSessionModel trip) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'trip_sessions',
        {'status': 'inactive', 'updated_at': now},
        where: 'status = ? AND ${_modeWhereClauseForTrip(trip)}',
        whereArgs: ['active', ..._modeWhereArgsForTrip(trip)],
      );
      await txn.insert(
        'trip_sessions',
        trip.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if ((trip.offlineChannelId ?? '').isNotEmpty) {
        await txn.update('offline_channels', {'is_active': 0});
        await txn.update(
          'offline_channels',
          {
            'trip_id': trip.tripId,
            'is_primary': 1,
            'is_active': 1,
            'channel_status': 'active',
            'last_opened_at': now,
            'updated_at': now,
          },
          where: 'channel_id = ?',
          whereArgs: [trip.offlineChannelId],
        );
      }
    });
    await _database.upsertSetting(_settingKeyForTrip(trip), trip.tripId);
    await _ensureDefaultChatForTrip(trip);
    return (await getTrip(trip.tripId)) ?? trip;
  }

  Future<TripSessionModel> _insertAsInactive(TripSessionModel trip) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final values = trip.toDbMap()
      ..['status'] = 'inactive'
      ..['updated_at'] = now;
    await db.transaction((txn) async {
      await txn.insert(
        'trip_sessions',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if ((trip.offlineChannelId ?? '').isNotEmpty) {
        await txn.update(
          'offline_channels',
          {
            'trip_id': trip.tripId,
            'is_primary': 1,
            'is_active': 0,
            'channel_status': 'inactive',
            'last_opened_at': now,
            'updated_at': now,
          },
          where: 'channel_id = ?',
          whereArgs: [trip.offlineChannelId],
        );
      }
    });
    final inactive = TripSessionModel.fromDb(values);
    await _ensureDefaultChatForTrip(inactive);
    return inactive;
  }

  Future<void> _updateStatus(
    String tripId,
    String status, {
    DateTime? endedAt,
  }) async {
    final db = await _database.database;
    await db.update(
      'trip_sessions',
      {
        'status': status,
        'ended_at': endedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'trip_id = ?',
      whereArgs: [tripId],
    );
    if (status == 'archived' || status == 'completed') {
      final now = DateTime.now().toIso8601String();
      await db.update(
        'offline_channels',
        {'is_active': 0, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      await db.update(
        'chat_rooms',
        {'is_active': 0, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
    }
  }

  Future<void> _activateTripChannel({
    required String tripId,
    required String channelId,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('offline_channels', {'is_active': 0});
      await txn.update(
        'offline_channels',
        {
          'trip_id': tripId,
          'is_active': 1,
          'channel_status': 'active',
          'last_opened_at': now,
          'updated_at': now,
        },
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
      await txn.update(
        'trip_sessions',
        {
          'active_channel_id': channelId,
          'offline_channel_id': channelId,
          'last_opened_at': now,
          'updated_at': now,
        },
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      await txn.update(
        'chat_rooms',
        {'is_active': 0, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      await txn.update(
        'chat_rooms',
        {'is_active': 1, 'updated_at': now},
        where: 'trip_id = ? AND channel_id = ? AND is_default = 1',
        whereArgs: [tripId, channelId],
      );
    });
    await _database.upsertSetting('active_offline_channel_id', channelId);
  }

  Future<void> _ensureDefaultChatForTrip(TripSessionModel trip) async {
    final db = await _database.database;
    final channelId = trip.activeChannelId ?? trip.offlineChannelId;
    final chatType = (channelId ?? '').isNotEmpty
        ? 'offline_channel'
        : (trip.cloudGroupId ?? '').isNotEmpty
            ? 'cloud_group'
            : 'trip_general';
    final rows = await db.query(
      'chat_rooms',
      where:
          'trip_id = ? AND COALESCE(channel_id, "") = ? AND chat_type = ? AND is_default = 1',
      whereArgs: [trip.tripId, channelId ?? '', chatType],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'chat_rooms',
      {
        'chat_id':
            'chat_${trip.tripId}_${channelId ?? trip.cloudGroupId ?? 'general'}',
        'trip_id': trip.tripId,
        'channel_id': channelId,
        'cloud_group_id': trip.cloudGroupId,
        'chat_name': 'General',
        'chat_type': chatType,
        'is_default': 1,
        'is_active': trip.isActive ? 1 : 0,
        'chat_status': 'active',
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  void _validateTripName(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 3 || trimmed.length > 60) {
      throw StateError('Trip name must be 3-60 characters.');
    }
  }

  Future<void> _markTripActiveWithinMode(TripSessionModel trip) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'trip_sessions',
        {'status': 'inactive', 'updated_at': now},
        where: 'status = ? AND ${_modeWhereClauseForTrip(trip)}',
        whereArgs: ['active', ..._modeWhereArgsForTrip(trip)],
      );
      await txn.update(
        'trip_sessions',
        {'status': 'active', 'last_opened_at': now, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [trip.tripId],
      );
    });
  }

  static bool _isUsableTripStatus(String status) {
    return status != 'archived' && status != 'completed';
  }

  static bool _matchesEffectiveMode(TripSessionModel trip, EffectiveMode mode) {
    return switch (mode) {
      EffectiveMode.online => trip.mode == 'online' || trip.mode == 'hybrid',
      EffectiveMode.offline => trip.mode == 'offline',
      EffectiveMode.hybridLimited => trip.mode == 'offline',
    };
  }

  static String _activeTripSettingKeyForMode(EffectiveMode mode) {
    return mode == EffectiveMode.online
        ? activeOnlineTripSettingKey
        : activeOfflineTripSettingKey;
  }

  static String _settingKeyForTrip(TripSessionModel trip) {
    return trip.mode == 'offline'
        ? activeOfflineTripSettingKey
        : activeOnlineTripSettingKey;
  }

  static String _modeWhereClause(EffectiveMode mode) {
    return mode == EffectiveMode.online ? 'mode IN (?, ?)' : 'mode = ?';
  }

  static List<String> _modeWhereArgs(EffectiveMode mode) {
    return mode == EffectiveMode.online
        ? const ['online', 'hybrid']
        : const ['offline'];
  }

  static String _modeWhereClauseForTrip(TripSessionModel trip) {
    return trip.mode == 'offline' ? 'mode = ?' : 'mode IN (?, ?)';
  }

  static List<String> _modeWhereArgsForTrip(TripSessionModel trip) {
    return trip.mode == 'offline'
        ? const ['offline']
        : const ['online', 'hybrid'];
  }
}
