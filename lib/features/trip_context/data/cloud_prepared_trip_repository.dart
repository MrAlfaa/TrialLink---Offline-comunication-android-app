import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../../core/identity/local_identity_model.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../trip/data/trip_session_repository.dart';
import 'cloud_prepared_trip_api.dart';
import 'models/cloud_prepared_trip_metadata.dart';
import 'trip_member_device_roster_repository.dart';

final cloudPreparedTripRepositoryProvider =
    Provider<CloudPreparedTripRepository>((ref) {
  return CloudPreparedTripRepository(
    api: CloudPreparedTripApi(),
    database: LocalDatabase.instance,
    identityRepository: ref.read(localIdentityRepositoryProvider),
    rosterRepository: ref.read(tripMemberDeviceRosterRepositoryProvider),
  );
});

class CloudPreparedTripRepository {
  CloudPreparedTripRepository({
    required CloudPreparedTripApi api,
    required LocalDatabase database,
    required LocalIdentityRepository identityRepository,
    required TripMemberDeviceRosterRepository rosterRepository,
  })  : _api = api,
        _database = database,
        _identityRepository = identityRepository,
        _rosterRepository = rosterRepository;

  final CloudPreparedTripApi _api;
  final LocalDatabase _database;
  final LocalIdentityRepository _identityRepository;
  final TripMemberDeviceRosterRepository _rosterRepository;

  Future<CloudPreparedTripMetadata> createCloudPreparedTrip({
    required String tripName,
    String? description,
  }) async {
    final identity = await _requireIdentity();
    final session = await _database.ensureSession();
    final metadata = await _api.createCloudPreparedTrip(
      tripName: tripName,
      description: description,
      localUserId: identity.localUserId,
      appDeviceId: session['session_id'].toString(),
    );
    await _cacheMetadata(metadata, localIdentityId: identity.localUserId);
    return metadata;
  }

  Future<CloudPreparedTripMetadata> joinCloudPreparedTrip(
    String tripCode,
  ) async {
    final identity = await _requireIdentity();
    final session = await _database.ensureSession();
    final metadata = await _api.joinCloudPreparedTrip(
      tripCode: tripCode,
      localUserId: identity.localUserId,
      appDeviceId: session['session_id'].toString(),
    );
    await _cacheMetadata(metadata, localIdentityId: identity.localUserId);
    return metadata;
  }

  Future<CloudPreparedTripMetadata> refreshCloudPreparedMetadata(
    String tripId,
  ) async {
    final identity = await _requireIdentity();
    final metadata = await _api.getCloudPreparedTripMetadata(tripId);
    await _cacheMetadata(metadata, localIdentityId: identity.localUserId);
    return metadata;
  }

  Future<void> _cacheMetadata(
    CloudPreparedTripMetadata metadata, {
    required String localIdentityId,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    final currentMemberRole = _currentMemberRole(metadata, localIdentityId);
    await db.transaction((txn) async {
      await txn.update(
        'trip_sessions',
        {'status': 'inactive', 'updated_at': now},
        where: 'status = ? AND mode IN (?, ?) AND trip_id != ?',
        whereArgs: ['active', 'online', 'hybrid', metadata.trip.tripId],
      );
      await txn.update(
        'chat_rooms',
        {'is_active': 0, 'updated_at': now},
        where: 'cloud_group_id IS NOT NULL',
      );

      await txn.insert(
        'local_groups',
        {
          'group_id': metadata.group.id,
          'group_name': metadata.group.groupName,
          'group_code': metadata.group.groupCode,
          'description': null,
          'member_role': currentMemberRole,
          'member_count': metadata.roster.length,
          'status': metadata.group.status,
          'source': 'cloud_prepared',
          'sync_state': 'synced',
          'last_synced_at': now,
          'created_at': metadata.trip.createdAt?.toIso8601String() ?? now,
          'updated_at': metadata.trip.updatedAt?.toIso8601String() ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'trip_sessions',
        {
          'trip_id': metadata.trip.tripId,
          'trip_name': metadata.trip.tripName,
          'mode': 'hybrid',
          'cloud_group_id': metadata.group.id,
          'cloud_group_name': metadata.group.groupName,
          'offline_channel_id': metadata.channel.channelId,
          'active_channel_id': metadata.channel.channelId,
          'primary_channel_id': metadata.channel.channelId,
          'channel_code': metadata.channel.channelCode,
          'channel_name': metadata.channel.channelName,
          'local_identity_id': localIdentityId,
          'status': 'active',
          'started_at': metadata.trip.createdAt?.toIso8601String() ?? now,
          'ended_at': null,
          'sync_state': 'server_synced',
          'created_at': metadata.trip.createdAt?.toIso8601String() ?? now,
          'last_opened_at': now,
          'updated_at': now,
          'offline_backup_ready': 1,
          'cloud_prepared_at':
              metadata.trip.cloudPreparedAt?.toIso8601String() ?? now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'offline_channels',
        {
          'channel_id': metadata.channel.channelId,
          'channel_code': metadata.channel.channelCode,
          'channel_name': metadata.channel.channelName,
          'trip_id': metadata.trip.tripId,
          'description':
              'Offline support channel prepared from TrailLink cloud.',
          'created_by_user_id': metadata.trip.ownerUserId ?? localIdentityId,
          'created_by_name': metadata.group.groupName,
          'channel_key_hash': metadata.channel.channelKeyHash,
          'is_primary': 1,
          'is_active': 0,
          'channel_status': 'active',
          'created_at': metadata.channel.createdAt?.toIso8601String() ?? now,
          'updated_at': now,
          'last_opened_at': now,
          'offline_backup_ready': 1,
          'cloud_prepared_at': now,
          'primary_channel_id': metadata.channel.channelId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'chat_rooms',
        {
          'chat_id': metadata.chatRoom.chatId,
          'trip_id': metadata.trip.tripId,
          'channel_id': metadata.channel.channelId,
          'cloud_group_id': metadata.group.id,
          'chat_name': metadata.chatRoom.chatName,
          'chat_type': metadata.chatRoom.chatType,
          'is_default': 1,
          'is_active': 1,
          'chat_status': 'active',
          'created_at': metadata.chatRoom.createdAt?.toIso8601String() ?? now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'local_group_members',
        where: 'group_id = ?',
        whereArgs: [metadata.group.id],
      );
      await txn.delete(
        'offline_channel_members',
        where: 'channel_id = ?',
        whereArgs: [metadata.channel.channelId],
      );
      for (final member in metadata.roster) {
        final memberRole = _cloudMemberRole(metadata, member);
        await txn.insert(
          'local_group_members',
          {
            'group_id': metadata.group.id,
            'user_id': member.userId,
            'local_user_id': member.localUserId,
            'display_name': member.displayName,
            'email': null,
            'phone_number': member.phoneNumber,
            'role': memberRole,
            'membership_status': 'active',
            'presence_status': 'recently_active',
            'last_seen_at': member.lastSeenAt?.toIso8601String(),
            'source': 'cloud_roster',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'offline_channel_members',
          {
            'channel_id': metadata.channel.channelId,
            'user_id':
                member.localUserId ?? member.publicUserId ?? member.userId,
            'display_name': member.displayName,
            'member_role': memberRole,
            'source': 'cloud_roster',
            'status': 'active',
            'joined_at': now,
            'last_seen_at': member.lastSeenAt?.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await _rosterRepository.replaceRoster(metadata, txn: txn);
    });

    await _database.upsertSetting(
      TripSessionRepository.activeOnlineTripSettingKey,
      metadata.trip.tripId,
    );
    await _database.upsertSetting(
      'peer_validation_policy_${metadata.trip.tripId}',
      'known_members_only',
    );
  }

  Future<LocalIdentityModel> _requireIdentity() async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      throw StateError(
          'Create your TrailLink profile before using cloud trips.');
    }
    return identity;
  }

  String _cloudMemberRole(
    CloudPreparedTripMetadata metadata,
    MemberDeviceProfileMetadata member,
  ) {
    final ownerIds = {
      metadata.group.createdBy,
      metadata.trip.ownerUserId,
    }.whereType<String>().where((value) => value.isNotEmpty).toSet();
    final memberIds = {
      member.userId,
      member.publicUserId,
      member.localUserId,
    }.whereType<String>().where((value) => value.isNotEmpty);
    return memberIds.any(ownerIds.contains) ? 'owner' : 'member';
  }

  String _currentMemberRole(
    CloudPreparedTripMetadata metadata,
    String localIdentityId,
  ) {
    for (final member in metadata.roster) {
      final matchesLocalIdentity = member.localUserId == localIdentityId ||
          member.publicUserId == localIdentityId ||
          member.userId == localIdentityId;
      if (matchesLocalIdentity) return _cloudMemberRole(metadata, member);
    }
    return 'member';
  }
}
