import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/local_identity_model.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../groups/data/group_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_channel/data/offline_channel_repository.dart';
import '../../p2p_session/data/p2p_session_service.dart';
import '../../trip/data/trip_session_model.dart';
import '../../trip/data/trip_session_repository.dart';
import 'models/active_trip_context.dart';
import 'models/chat_room_model.dart';

final tripContextServiceProvider = Provider<TripContextService>((ref) {
  return TripContextService(
    identityRepository: ref.read(localIdentityRepositoryProvider),
    tripRepository: ref.read(tripSessionRepositoryProvider),
    channelRepository: OfflineChannelRepository(),
    groupRepository: GroupRepository(),
    p2pSessionService: ref.read(p2pSessionServiceProvider),
  );
});

final activeTripContextProvider = FutureProvider<ActiveTripContext?>((ref) {
  final mode = ref.watch(effectiveModeProvider);
  return ref.read(tripContextServiceProvider).getActiveTripContextForMode(mode);
});

class OfflineChatContext {
  const OfflineChatContext({
    required this.trip,
    required this.channel,
    required this.chat,
    required this.membershipStatus,
  });

  final TripSessionModel trip;
  final OfflineChannelModel channel;
  final ChatRoomModel chat;
  final String membershipStatus;

  bool get isReadOnly {
    return trip.status == 'archived' ||
        trip.status == 'completed' ||
        channel.isEnded ||
        channel.channelStatus == 'archived' ||
        chat.isReadOnly ||
        membershipStatus == 'left' ||
        membershipStatus == 'removed' ||
        membershipStatus == 'blocked';
  }

  bool get canCompose {
    return trip.status == 'active' &&
        channel.isActive &&
        channel.isUsable &&
        chat.chatStatus == 'active' &&
        membershipStatus == 'active';
  }
}

class OfflineChatRouteTarget {
  const OfflineChatRouteTarget({
    required this.tripId,
    required this.channelId,
    required this.chatId,
  });

  final String tripId;
  final String channelId;
  final String chatId;

  String get location => '/trips/$tripId/channels/$channelId/chats/$chatId';
}

class TripContextService {
  TripContextService({
    LocalDatabase? database,
    LocalIdentityRepository? identityRepository,
    TripSessionRepository? tripRepository,
    OfflineChannelRepository? channelRepository,
    GroupRepository? groupRepository,
    P2PSessionService? p2pSessionService,
    Uuid? uuid,
  })  : _database = database ?? LocalDatabase.instance,
        _identityRepository = identityRepository ?? LocalIdentityRepository(),
        _tripRepository = tripRepository ?? TripSessionRepository(),
        _channelRepository = channelRepository ?? OfflineChannelRepository(),
        _groupRepository = groupRepository ?? GroupRepository(),
        _p2pSessionService = p2pSessionService,
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final LocalIdentityRepository _identityRepository;
  final TripSessionRepository _tripRepository;
  final OfflineChannelRepository _channelRepository;
  final GroupRepository _groupRepository;
  final P2PSessionService? _p2pSessionService;
  final Uuid _uuid;

  Future<ActiveTripContext?> getActiveTripContext() async {
    return getActiveTripContextForMode(EffectiveMode.offline);
  }

  Future<ActiveTripContext?> getActiveTripContextForMode(
    EffectiveMode mode,
  ) async {
    await _normalizeActiveTrips();
    var trip = await _tripRepository.getActiveTripForMode(mode);
    if (mode != EffectiveMode.online) {
      trip = await _reconcileGloballyActiveChannel(trip) ?? trip;
      trip ??= await _repairOrphanActiveChannel();
    }
    if (trip == null || trip.status != 'active') return null;
    await ensureDefaultChannelAndChat(trip.tripId);
    trip = await _tripRepository.getTrip(trip.tripId) ?? trip;
    final channel = await _resolveChannelForTrip(trip);
    final chat = await _resolveChatForTrip(trip, channel);
    return ActiveTripContext(
      trip: trip,
      activeChannel: channel,
      activeChat: chat,
    );
  }

  Future<void> activateTrip(String tripId) async {
    final activeSession = await _p2pSessionService?.getActiveSession();
    if (activeSession != null &&
        activeSession.tripId != tripId &&
        activeSession.blocksTripSwitch) {
      await _p2pSessionService?.stopActiveSession(reason: 'switch_trip');
    }
    await _tripRepository.setActiveTrip(tripId);
    await ensureDefaultChannelAndChat(tripId);
  }

  Future<void> deactivateTrip(String tripId) async {
    final activeSession = await _p2pSessionService?.getActiveSession();
    if (activeSession?.tripId == tripId) {
      await _p2pSessionService?.stopActiveSession(reason: 'deactivate_trip');
    }
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'trip_sessions',
        {'status': 'inactive', 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      await txn.update(
        'offline_channels',
        {'is_active': 0, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
      await txn.update(
        'chat_rooms',
        {'is_active': 0, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [tripId],
      );
    });
  }

  Future<ActiveTripContext> createTripWithPrimaryChannel({
    required String tripName,
    required String mode,
    String? description,
    String? customChannelCode,
    String? cloudGroupId,
    String? cloudGroupName,
    bool activate = true,
  }) async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      throw StateError('Create your TrailLink profile before starting a trip.');
    }
    final trip = cloudGroupId == null
        ? await _tripRepository.createOfflineTrip(
            tripName: tripName,
            identity: identity,
            customChannelCode: customChannelCode,
            activate: activate,
          )
        : await _tripRepository.createCloudBackupTrip(
            tripName: tripName,
            description: description ?? '',
            identity: identity,
            groupRepository: null,
            customChannelCode: customChannelCode,
          );
    if (cloudGroupId != null) {
      final db = await _database.database;
      await db.update(
        'trip_sessions',
        {
          'mode': mode,
          'cloud_group_id': cloudGroupId,
          'cloud_group_name': cloudGroupName,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'trip_id = ?',
        whereArgs: [trip.tripId],
      );
    }
    final context = await getActiveTripContextForMode(
      mode == 'online' || mode == 'hybrid'
          ? EffectiveMode.online
          : EffectiveMode.offline,
    );
    if (context == null) throw StateError('Active trip context not created.');
    return context;
  }

  Future<ActiveTripContext> joinOfflineChannelAsActiveTrip(
    String channelCode, {
    String? tripName,
  }) async {
    final identity = await _requireIdentity();
    final channel = await _channelRepository.joinChannelForIdentity(
      identity: identity,
      channelCode: channelCode,
    );
    await _activateOfflineChannelTripRecord(
      channel: channel,
      identity: identity,
      tripName: tripName,
    );
    final context = await getActiveTripContextForMode(EffectiveMode.offline);
    if (context == null ||
        context.activeChannel?.channelId != channel.channelId) {
      throw StateError('Joined channel was not activated.');
    }
    return context;
  }

  Future<TripSessionModel> joinOfflineChannelAsInactiveTrip(
    String channelCode, {
    String? tripName,
  }) async {
    final identity = await _requireIdentity();
    final trip = await _tripRepository.joinOfflineTrip(
      channelCode: channelCode,
      identity: identity,
      tripName: tripName,
      activate: false,
    );
    await ensureDefaultChannelAndChat(trip.tripId);
    return trip;
  }

  Future<ActiveTripContext> activateOfflineChannelAsTrip(
    String channelId, {
    String? tripName,
  }) async {
    final identity = await _requireIdentity();
    final channel = await _channelById(channelId);
    if (channel == null) throw StateError('Offline channel not found.');
    await _activateOfflineChannelTripRecord(
      channel: channel,
      identity: identity,
      tripName: tripName,
    );
    final context = await getActiveTripContextForMode(EffectiveMode.offline);
    if (context == null || context.activeChannel?.channelId != channelId) {
      throw StateError('Offline channel was not activated.');
    }
    return context;
  }

  Future<void> ensureDefaultChannelAndChat(String tripId) async {
    final db = await _database.database;
    final trip = await _tripById(tripId);
    if (trip == null) return;
    OfflineChannelModel? channel = await _resolveChannelForTrip(trip);
    if (channel == null && trip.mode != 'online') {
      final identity = await _identityRepository.getCurrentIdentity();
      if (identity != null) {
        channel = await _channelRepository.createChannelForIdentity(
          identity: identity,
          channelName: trip.tripName,
          description: 'Primary channel for ${trip.tripName}.',
        );
        await db.update(
          'offline_channels',
          {
            'trip_id': trip.tripId,
            'is_primary': 1,
            'is_active': trip.isActive ? 1 : 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'channel_id = ?',
          whereArgs: [channel.channelId],
        );
        await db.update(
          'trip_sessions',
          {
            'offline_channel_id': channel.channelId,
            'active_channel_id': channel.channelId,
            'channel_code': channel.channelCode,
            'channel_name': channel.channelName,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'trip_id = ?',
          whereArgs: [trip.tripId],
        );
      }
    }
    await _ensureDefaultChat(
      trip: trip,
      channel: channel,
      isActive: trip.isActive,
    );
  }

  Future<OfflineChannelModel?> getActiveChannel() async {
    return (await getActiveTripContext())?.activeChannel;
  }

  Future<ChatRoomModel?> getActiveChat() async {
    return (await getActiveTripContext())?.activeChat;
  }

  Future<OfflineChatContext?> resolveOfflineChatContext({
    required String tripId,
    required String channelId,
    String? chatId,
  }) async {
    await ensureDefaultChannelAndChat(tripId);
    final trip = await _tripById(tripId);
    if (trip == null) return null;
    final channel = await _channelById(channelId);
    if (channel == null || channel.tripId != tripId) return null;
    final chat = chatId == null || chatId.isEmpty
        ? await _defaultChatForChannel(tripId, channelId)
        : await _chatById(chatId);
    if (chat == null || chat.tripId != tripId || chat.channelId != channelId) {
      return null;
    }
    return OfflineChatContext(
      trip: trip,
      channel: channel,
      chat: chat,
      membershipStatus: await _localMembershipStatus(channelId),
    );
  }

  Future<OfflineChatRouteTarget?> resolveDefaultOfflineChatRoute(
    String channelId,
  ) async {
    final channel = await _channelById(channelId);
    final tripId =
        channel?.tripId ?? (await getActiveTripContext())?.trip.tripId;
    if (tripId == null || tripId.isEmpty) return null;
    await ensureDefaultChannelAndChat(tripId);
    final chat = await _defaultChatForChannel(tripId, channelId);
    if (chat == null) return null;
    return OfflineChatRouteTarget(
      tripId: tripId,
      channelId: channelId,
      chatId: chat.chatId,
    );
  }

  Future<void> switchActiveChannel(String channelId) async {
    await activateOfflineChannelAsTrip(channelId);
  }

  Future<void> switchActiveChat(String chatId) async {
    final db = await _database.database;
    final rows = await db.query(
      'chat_rooms',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Chat room not found.');
    final chat = ChatRoomModel.fromDb(rows.first);
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'chat_rooms',
        {'is_active': 0, 'updated_at': now},
        where: 'trip_id = ?',
        whereArgs: [chat.tripId],
      );
      await txn.update(
        'chat_rooms',
        {'is_active': 1, 'updated_at': now},
        where: 'chat_id = ?',
        whereArgs: [chatId],
      );
    });
  }

  Future<List<TripSessionModel>> getTrips() => _tripRepository.getTrips();

  Future<List<OfflineChannelModel>> getChannelsForTrip(String tripId) async {
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'trip_id = ? AND channel_status IN (?, ?)',
      whereArgs: [tripId, 'active', 'inactive'],
      orderBy: 'is_primary DESC, is_active DESC, created_at ASC',
    );
    return rows.map(OfflineChannelModel.fromDb).toList();
  }

  Future<OfflineChannelModel> createChannelUnderTrip({
    required String tripId,
    required String channelName,
    String description = '',
    String? customCode,
  }) async {
    throw StateError('Trips use one primary channel in this build.');
  }

  Future<void> archiveTrip(String tripId) async {
    final activeSession = await _p2pSessionService?.getActiveSession();
    if (activeSession?.tripId == tripId) {
      await _p2pSessionService?.stopActiveSession(reason: 'archive_trip');
    }
    await _tripRepository.archiveTrip(tripId);
  }

  Future<bool> canDeleteTrip(String tripId) async {
    final trip = await _tripRepository.getTrip(tripId);
    if (trip == null) return false;
    return _currentUserOwnsTrip(trip);
  }

  Future<void> deleteTrip(String tripId) async {
    final trip = await _tripRepository.getTrip(tripId);
    if (trip == null) {
      throw StateError('Trip not found.');
    }
    if (!await _currentUserOwnsTrip(trip)) {
      throw StateError('Only the trip owner can delete this trip.');
    }

    final activeSession = await _p2pSessionService?.getActiveSession();
    if (activeSession?.tripId == tripId) {
      await _p2pSessionService?.stopActiveSession(reason: 'delete_trip');
    }

    if ((trip.cloudGroupId ?? '').isNotEmpty) {
      await _groupRepository.archiveGroup(trip.cloudGroupId!);
    }
    await _tripRepository.deleteTripLocal(tripId);
  }

  Future<void> _normalizeActiveTrips() async {
    final db = await _database.database;
    for (final modeSet in const [
      ['offline'],
      ['online', 'hybrid'],
    ]) {
      final placeholders = List.filled(modeSet.length, '?').join(', ');
      final activeRows = await db.query(
        'trip_sessions',
        where: 'status = ? AND mode IN ($placeholders)',
        whereArgs: ['active', ...modeSet],
        orderBy: 'COALESCE(last_opened_at, started_at, created_at) DESC',
      );
      if (activeRows.length <= 1) continue;
      final keep = activeRows.first['trip_id']?.toString();
      if (keep == null) continue;
      await db.update(
        'trip_sessions',
        {
          'status': 'inactive',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'status = ? AND mode IN ($placeholders) AND trip_id != ?',
        whereArgs: ['active', ...modeSet, keep],
      );
    }
  }

  Future<TripSessionModel?> _repairOrphanActiveChannel() async {
    final channel = await _channelRepository.getActiveChannel();
    if (channel == null || !channel.isUsable) return null;
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) return null;
    return _activateOfflineChannelTripRecord(
      channel: channel,
      identity: identity,
      tripName: channel.channelName,
    );
  }

  Future<bool> _currentUserOwnsTrip(TripSessionModel trip) async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) return false;
    final userIds = <String>{
      identity.localUserId,
      if ((identity.backendUserId ?? '').isNotEmpty) identity.backendUserId!,
      if ((identity.cloudUserId ?? '').isNotEmpty) identity.cloudUserId!,
      if ((identity.publicUserId ?? '').isNotEmpty) identity.publicUserId!,
    };

    if ((trip.cloudGroupId ?? '').isNotEmpty) {
      final db = await _database.database;
      final groupRows = await db.query(
        'local_groups',
        columns: ['member_role'],
        where: 'group_id = ?',
        whereArgs: [trip.cloudGroupId],
        limit: 1,
      );
      final role = groupRows.isEmpty
          ? null
          : groupRows.first['member_role']?.toString();
      if (role == 'owner') return true;
      final ownerMemberRows = await db.query(
        'local_group_members',
        where:
            'group_id = ? AND role = ? AND (${_inClause('user_id', userIds.length)} OR ${_inClause('local_user_id', userIds.length)})',
        whereArgs: [trip.cloudGroupId, 'owner', ...userIds, ...userIds],
        limit: 1,
      );
      if (ownerMemberRows.isNotEmpty) return true;
    }

    final channel = await _resolveChannelForTrip(trip);
    if (channel == null) return false;
    if (userIds.contains(channel.createdByUserId)) return true;
    final db = await _database.database;
    final ownerRows = await db.query(
      'offline_channel_members',
      where:
          'channel_id = ? AND member_role = ? AND ${_inClause('user_id', userIds.length)}',
      whereArgs: [channel.channelId, 'owner', ...userIds],
      limit: 1,
    );
    return ownerRows.isNotEmpty;
  }

  Future<TripSessionModel?> _reconcileGloballyActiveChannel(
    TripSessionModel? trip,
  ) async {
    final channel = await _channelRepository.getActiveChannel();
    if (channel == null || !channel.isUsable) return null;
    final tripChannelId = trip?.activeChannelId ?? trip?.offlineChannelId;
    if (trip != null && tripChannelId == channel.channelId) return null;
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) return null;
    return _activateOfflineChannelTripRecord(
      channel: channel,
      identity: identity,
      tripName: channel.channelName,
    );
  }

  Future<TripSessionModel> _activateOfflineChannelTripRecord({
    required OfflineChannelModel channel,
    required LocalIdentityModel identity,
    String? tripName,
  }) async {
    if (!channel.isUsable) {
      throw StateError('Ended channels are read-only.');
    }
    final normalizedCode = _tripRepository.normalizeChannelCode(
      channel.channelCode,
    );
    final db = await _database.database;
    final existing = await _findTripForChannel(channel, normalizedCode);
    if (existing == null) {
      return _tripRepository.createTripFromOfflineChannel(
        tripName: (tripName?.trim().isNotEmpty ?? false)
            ? tripName!.trim()
            : channel.channelName,
        offlineChannelId: channel.channelId,
        channelCode: normalizedCode,
        channelName: channel.channelName,
        localIdentityId: identity.localUserId,
      );
    }

    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update(
        'trip_sessions',
        {'status': 'inactive', 'updated_at': now},
        where: 'status = ?',
        whereArgs: ['active'],
      );
      await txn.update(
        'trip_sessions',
        {
          'status': 'active',
          'mode': existing.mode == 'online' ? 'hybrid' : existing.mode,
          'offline_channel_id': channel.channelId,
          'active_channel_id': channel.channelId,
          'channel_code': normalizedCode,
          'channel_name': channel.channelName,
          'last_opened_at': now,
          'updated_at': now,
        },
        where: 'trip_id = ?',
        whereArgs: [existing.tripId],
      );
      await txn.update('offline_channels', {'is_active': 0});
      await txn.update(
        'offline_channels',
        {
          'trip_id': existing.tripId,
          'is_primary': 1,
          'is_active': 1,
          'channel_status': 'active',
          'last_opened_at': now,
          'updated_at': now,
        },
        where: 'channel_id = ?',
        whereArgs: [channel.channelId],
      );
      await txn.update(
        'chat_rooms',
        {'is_active': 0, 'updated_at': now},
      );
    });
    await _database.upsertSetting(
        'active_offline_channel_id', channel.channelId);
    await ensureDefaultChannelAndChat(existing.tripId);
    final chat =
        await _defaultChatForChannel(existing.tripId, channel.channelId);
    if (chat != null) await switchActiveChat(chat.chatId);
    return (await _tripById(existing.tripId)) ?? existing;
  }

  Future<TripSessionModel?> _findTripForChannel(
    OfflineChannelModel channel,
    String normalizedCode,
  ) async {
    final db = await _database.database;
    if ((channel.tripId ?? '').isNotEmpty) {
      final linked = await db.query(
        'trip_sessions',
        where: 'trip_id = ?',
        whereArgs: [channel.tripId],
        limit: 1,
      );
      if (linked.isNotEmpty) return TripSessionModel.fromDb(linked.first);
    }
    final rows = await db.query(
      'trip_sessions',
      where:
          'mode IN (?, ?, ?) AND (offline_channel_id = ? OR active_channel_id = ? OR channel_code = ?)',
      whereArgs: [
        'offline',
        'hybrid',
        'online',
        channel.channelId,
        channel.channelId,
        normalizedCode,
      ],
      orderBy: "CASE status WHEN 'active' THEN 0 ELSE 1 END, "
          'COALESCE(last_opened_at, started_at, created_at) DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : TripSessionModel.fromDb(rows.first);
  }

  Future<LocalIdentityModel> _requireIdentity() async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      throw StateError('Create your TrailLink profile before using channels.');
    }
    return identity;
  }

  Future<TripSessionModel?> _tripById(String tripId) async {
    final db = await _database.database;
    final rows = await db.query(
      'trip_sessions',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    return rows.isEmpty ? null : TripSessionModel.fromDb(rows.first);
  }

  Future<OfflineChannelModel?> _channelById(String channelId) async {
    final channel = await _channelRepository.getChannel(channelId);
    if (channel != null) return channel;
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelModel.fromDb(rows.first);
  }

  Future<ChatRoomModel?> _chatById(String chatId) async {
    final db = await _database.database;
    final rows = await db.query(
      'chat_rooms',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      limit: 1,
    );
    return rows.isEmpty ? null : ChatRoomModel.fromDb(rows.first);
  }

  Future<String> _localMembershipStatus(String channelId) async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) return 'missing';
    final db = await _database.database;
    final rows = await db.query(
      'offline_channel_members',
      columns: ['membership_status', 'status'],
      where: 'channel_id = ? AND user_id = ?',
      whereArgs: [channelId, identity.localUserId],
      limit: 1,
    );
    if (rows.isEmpty) return 'active';
    return rows.first['membership_status']?.toString() ??
        rows.first['status']?.toString() ??
        'active';
  }

  Future<OfflineChannelModel?> _resolveChannelForTrip(
    TripSessionModel trip,
  ) async {
    final db = await _database.database;
    final channelId = trip.activeChannelId ?? trip.offlineChannelId;
    if (channelId != null && channelId.isNotEmpty) {
      final channel = await _channelRepository.getChannel(channelId);
      if (channel != null) return channel;
    }
    final rows = await db.query(
      'offline_channels',
      where: 'trip_id = ? AND channel_status IN (?, ?)',
      whereArgs: [trip.tripId, 'active', 'inactive'],
      orderBy: 'is_active DESC, is_primary DESC, created_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : OfflineChannelModel.fromDb(rows.first);
  }

  String _inClause(String column, int count) {
    return '$column IN (${List.filled(count, '?').join(', ')})';
  }

  Future<ChatRoomModel?> _resolveChatForTrip(
    TripSessionModel trip,
    OfflineChannelModel? channel,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'chat_rooms',
      where:
          'trip_id = ? AND COALESCE(channel_id, "") = ? AND chat_status IN (?, ?, ?)',
      whereArgs: [
        trip.tripId,
        channel?.channelId ?? '',
        'active',
        'inactive',
        'read_only'
      ],
      orderBy: 'is_active DESC, is_default DESC, created_at ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChatRoomModel.fromDb(rows.first);
  }

  Future<ChatRoomModel?> _defaultChatForChannel(
    String tripId,
    String channelId,
  ) async {
    final db = await _database.database;
    final rows = await db.query(
      'chat_rooms',
      where: 'trip_id = ? AND channel_id = ? AND is_default = 1',
      whereArgs: [tripId, channelId],
      limit: 1,
    );
    return rows.isEmpty ? null : ChatRoomModel.fromDb(rows.first);
  }

  Future<void> _ensureDefaultChat({
    required TripSessionModel trip,
    required OfflineChannelModel? channel,
    required bool isActive,
  }) async {
    final db = await _database.database;
    final chatType = channel != null
        ? 'offline_channel'
        : (trip.cloudGroupId ?? '').isNotEmpty
            ? 'cloud_group'
            : 'trip_general';
    final rows = await db.query(
      'chat_rooms',
      where:
          'trip_id = ? AND COALESCE(channel_id, "") = ? AND chat_type = ? AND is_default = 1',
      whereArgs: [trip.tripId, channel?.channelId ?? '', chatType],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'chat_rooms',
      {
        'chat_id': _uuid.v4(),
        'trip_id': trip.tripId,
        'channel_id': channel?.channelId,
        'cloud_group_id': trip.cloudGroupId,
        'chat_name': 'General',
        'chat_type': chatType,
        'is_default': 1,
        'is_active': isActive ? 1 : 0,
        'chat_status': 'active',
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
