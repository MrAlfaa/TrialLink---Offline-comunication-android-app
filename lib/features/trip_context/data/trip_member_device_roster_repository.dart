import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/cloud_prepared_trip_metadata.dart';

final tripMemberDeviceRosterRepositoryProvider =
    Provider<TripMemberDeviceRosterRepository>((ref) {
  return TripMemberDeviceRosterRepository();
});

class TripMemberDeviceRosterRepository {
  TripMemberDeviceRosterRepository({LocalDatabase? database})
      : _database = database ?? LocalDatabase.instance;

  final LocalDatabase _database;

  Future<void> replaceRoster(
    CloudPreparedTripMetadata metadata, {
    Transaction? txn,
  }) async {
    final DatabaseExecutor db = txn ?? await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.delete(
      'cloud_trip_member_devices',
      where: 'trip_id = ?',
      whereArgs: [metadata.trip.tripId],
    );
    for (final member in metadata.roster) {
      await db.insert(
        'cloud_trip_member_devices',
        {
          'trip_id': metadata.trip.tripId,
          'channel_id': metadata.channel.channelId,
          'cloud_group_id': metadata.group.id,
          'user_id': member.userId,
          'public_user_id': member.publicUserId,
          'local_user_id': member.localUserId,
          'app_device_id': member.appDeviceId,
          'display_name': member.displayName,
          'phone_number': member.phoneNumber,
          'capabilities_json': jsonEncode(member.capabilities),
          'last_seen_at': member.lastSeenAt?.toIso8601String(),
          'verification_source': 'cloud_roster',
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<Map<String, Object?>?> findMatchingDevice({
    required String tripId,
    required NearbyPeerModel peer,
  }) async {
    final db = await _database.database;
    final rows = await db.query(
      'cloud_trip_member_devices',
      where: '''
        trip_id = ? AND (
          (public_user_id IS NOT NULL AND public_user_id != '' AND ? LIKE public_user_id || '%')
          OR (local_user_id IS NOT NULL AND local_user_id != '' AND ? LIKE local_user_id || '%')
          OR (app_device_id IS NOT NULL AND app_device_id != '' AND ? LIKE app_device_id || '%')
          OR (public_user_id IS NOT NULL AND public_user_id != '' AND public_user_id LIKE ? || '%')
          OR (local_user_id IS NOT NULL AND local_user_id != '' AND local_user_id LIKE ? || '%')
          OR (app_device_id IS NOT NULL AND app_device_id != '' AND app_device_id LIKE ? || '%')
        )
      ''',
      whereArgs: [
        tripId,
        peer.publicUserId ?? '',
        peer.userId,
        peer.appDeviceId ?? '',
        peer.publicUserId ?? '',
        peer.userId,
        peer.appDeviceId ?? '',
      ],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> countMembers(String tripId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT COALESCE(public_user_id, local_user_id, user_id, display_name)) AS total FROM cloud_trip_member_devices WHERE trip_id = ?',
      [tripId],
    );
    return int.tryParse(rows.first['total']?.toString() ?? '') ?? 0;
  }

  Future<int> countDevices(String tripId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM cloud_trip_member_devices WHERE trip_id = ?',
      [tripId],
    );
    return int.tryParse(rows.first['total']?.toString() ?? '') ?? 0;
  }
}
