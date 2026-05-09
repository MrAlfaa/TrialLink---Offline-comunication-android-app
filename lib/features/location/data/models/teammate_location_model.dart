import 'location_freshness.dart';

class TeammateLocationModel {
  const TeammateLocationModel({
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    required this.receivedAt,
    required this.source,
    required this.freshness,
    this.groupId,
    this.offlineChannelId,
    this.channelCode,
    this.accuracy,
  });

  final String userId;
  final String userName;
  final String? groupId;
  final String? offlineChannelId;
  final String? channelCode;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime capturedAt;
  final DateTime receivedAt;
  final String source;
  final LocationFreshness freshness;

  factory TeammateLocationModel.fromDb(Map<String, Object?> row) {
    final capturedAt =
        DateTime.tryParse(row['captured_at']?.toString() ?? '') ??
            DateTime.now();
    return TeammateLocationModel(
      userId: row['user_id'].toString(),
      userName: row['user_name']?.toString() ?? 'TrailLink User',
      groupId: row['group_id']?.toString(),
      offlineChannelId: row['offline_channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      latitude: double.parse(row['latitude'].toString()),
      longitude: double.parse(row['longitude'].toString()),
      accuracy: row['accuracy'] == null
          ? null
          : double.tryParse(row['accuracy'].toString()),
      capturedAt: capturedAt,
      receivedAt: DateTime.tryParse(row['received_at']?.toString() ?? '') ??
          DateTime.now(),
      source: row['source']?.toString() ?? 'peer',
      freshness: calculateLocationFreshness(capturedAt),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'user_id': userId,
      'user_name': userName,
      'group_id': groupId,
      'offline_channel_id': offlineChannelId,
      'channel_code': channelCode,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'captured_at': capturedAt.toIso8601String(),
      'received_at': receivedAt.toIso8601String(),
      'source': source,
      'freshness': freshness.name,
    };
  }
}
