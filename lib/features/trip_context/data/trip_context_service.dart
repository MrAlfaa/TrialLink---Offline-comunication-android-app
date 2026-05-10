import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_channel/data/offline_channel_repository.dart';
import '../../trip/data/trip_session_model.dart';
import '../../trip/data/trip_session_repository.dart';
import 'models/active_trip_context.dart';
import 'models/chat_room_model.dart';

final tripContextServiceProvider = Provider<TripContextService>((ref) {
  return TripContextService(
    identityRepository: ref.read(localIdentityRepositoryProvider),
    tripRepository: ref.read(tripSessionRepositoryProvider),
    channelRepository: OfflineChannelRepository(),
  );
});

final activeTripContextProvider = FutureProvider<ActiveTripContext?>((ref) {
  return ref.read(tripContextServiceProvider).getActiveTripContext();
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
    Uuid? uuid,
  })  : _database = database ?? LocalDatabase.instance,
        _identityRepository = identityRepository ?? LocalIdentityRepository(),
        _tripRepository = tripRepository ?? TripSessionRepository(),
        _channelRepository = channelRepository ?? OfflineChannelRepository(),
        _uuid = uuid ?? const Uuid();

  final LocalDatabase _database;
  final LocalIdentityRepository _identityRepository;
  final TripSessionRepository _tripRepository;
  final OfflineChannelRepository _channelRepository;
  final Uuid _uuid;

  Future<ActiveTripContext?> getActiveTripContext() async {
    await _normalizeActiveTrips();
    var trip = await _tripRepository.getActiveTrip();
    trip ??= await _repairOrphanActiveChannel();
    if (trip == null || trip.status != 'active') return null;
    await ensureDefaultChannelAndChat(trip.tripId);
    trip = await _tripRepository.getActiveTrip() ?? trip;
    final channel = await _resolveChannelForTrip(trip);
    final chat = await _resolveChatForTrip(trip, channel);
    return ActiveTripContext(
      trip: trip,
      activeChannel: channel,
      activeChat: chat,
    );
  }

  Future<void> activateTrip(String tripId) async {
    await _tripRepository.setActiveTrip(tripId);
    await ensureDefaultChannelAndChat(tripId);
  }

  Future<void> deactivateTrip(String tripId) async {
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
    final context = await getActiveTripContext();
    if (context == null) throw StateError('Active trip context not created.');
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
    final db = await _database.database;
    final rows = await db.query(
      'offline_channels',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Offline channel not found.');
    final channel = OfflineChannelModel.fromDb(rows.first);
    final tripId =
        channel.tripId ?? (await _tripRepository.getActiveTrip())?.tripId;
    if (tripId == null || tripId.isEmpty) {
      throw StateError('Create or activate a trip before switching channels.');
    }
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('offline_channels', {'is_active': 0});
      await txn.update(
        'offline_channels',
        {
          'trip_id': tripId,
          'is_active': 1,
          'channel_status': 'active',
          'updated_at': now,
          'last_opened_at': now,
        },
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
      await txn.update(
        'trip_sessions',
        {
          'active_channel_id': channelId,
          'offline_channel_id': channelId,
          'channel_code': channel.channelCode,
          'channel_name': channel.channelName,
          'updated_at': now,
          'last_opened_at': now,
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
    });
    await _database.upsertSetting('active_offline_channel_id', channelId);
    await ensureDefaultChannelAndChat(tripId);
    final chat = await _defaultChatForChannel(tripId, channelId);
    if (chat != null) await switchActiveChat(chat.chatId);
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
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      throw StateError(
          'Create your TrailLink profile before creating channels.');
    }
    final channel = await _channelRepository.createChannelForIdentity(
      identity: identity,
      channelName: channelName,
      description: description,
      customCode: customCode,
    );
    final db = await _database.database;
    await db.update(
      'offline_channels',
      {
        'trip_id': tripId,
        'is_primary': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'channel_id = ?',
      whereArgs: [channel.channelId],
    );
    await ensureDefaultChannelAndChat(tripId);
    return (await _channelRepository.getChannel(channel.channelId)) ?? channel;
  }

  Future<void> archiveTrip(String tripId) =>
      _tripRepository.archiveTrip(tripId);

  Future<void> _normalizeActiveTrips() async {
    final db = await _database.database;
    final activeRows = await db.query(
      'trip_sessions',
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'COALESCE(last_opened_at, started_at, created_at) DESC',
    );
    if (activeRows.length <= 1) return;
    final keep = activeRows.first['trip_id']?.toString();
    if (keep == null) return;
    await db.update(
      'trip_sessions',
      {'status': 'inactive', 'updated_at': DateTime.now().toIso8601String()},
      where: 'status = ? AND trip_id != ?',
      whereArgs: ['active', keep],
    );
  }

  Future<TripSessionModel?> _repairOrphanActiveChannel() async {
    final channel = await _channelRepository.getActiveChannel();
    if (channel == null || !channel.isUsable) return null;
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) return null;
    return _tripRepository.activateOfflineChannelTrip(
      channel: channel,
      identity: identity,
      tripName: channel.channelName,
    );
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
