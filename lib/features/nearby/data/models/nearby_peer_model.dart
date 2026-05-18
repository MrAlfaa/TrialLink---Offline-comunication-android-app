import 'nearby_connection_status.dart';

class NearbyPeerModel {
  const NearbyPeerModel({
    required this.endpointId,
    required this.userId,
    required this.displayName,
    required this.deviceName,
    required this.activeChannelId,
    required this.activeChannelCode,
    required this.status,
    required this.discoveredAt,
    required this.lastSeenAt,
    this.rssi,
    this.isSameChannel = true,
    this.tripId,
    this.publicUserId,
    this.appDeviceId,
    this.verificationStatus = 'unknown_same_channel',
  });

  final String endpointId;
  final String userId;
  final String displayName;
  final String deviceName;
  final String activeChannelId;
  final String activeChannelCode;
  final PeerConnectionStatus status;
  final DateTime discoveredAt;
  final DateTime lastSeenAt;
  final int? rssi;
  final bool isSameChannel;
  final String? tripId;
  final String? publicUserId;
  final String? appDeviceId;
  final String verificationStatus;

  NearbyPeerModel copyWith({
    String? endpointId,
    String? userId,
    String? displayName,
    String? deviceName,
    String? activeChannelId,
    String? activeChannelCode,
    PeerConnectionStatus? status,
    DateTime? discoveredAt,
    DateTime? lastSeenAt,
    int? rssi,
    bool? isSameChannel,
    String? tripId,
    String? publicUserId,
    String? appDeviceId,
    String? verificationStatus,
  }) {
    return NearbyPeerModel(
      endpointId: endpointId ?? this.endpointId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      deviceName: deviceName ?? this.deviceName,
      activeChannelId: activeChannelId ?? this.activeChannelId,
      activeChannelCode: activeChannelCode ?? this.activeChannelCode,
      status: status ?? this.status,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rssi: rssi ?? this.rssi,
      isSameChannel: isSameChannel ?? this.isSameChannel,
      tripId: tripId ?? this.tripId,
      publicUserId: publicUserId ?? this.publicUserId,
      appDeviceId: appDeviceId ?? this.appDeviceId,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  factory NearbyPeerModel.fromDb(Map<String, Object?> row) {
    return NearbyPeerModel(
      endpointId: row['endpoint_id'].toString(),
      userId: row['user_id'].toString(),
      displayName: row['display_name'].toString(),
      deviceName: row['device_name']?.toString() ?? 'Android Device',
      activeChannelId: row['active_channel_id'].toString(),
      activeChannelCode: row['active_channel_code'].toString(),
      status: PeerConnectionStatusX.fromString(
        row['connection_status']?.toString() ?? 'discovered',
      ),
      discoveredAt: DateTime.tryParse(
            row['discovered_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
      lastSeenAt: DateTime.tryParse(row['last_seen_at']?.toString() ?? '') ??
          DateTime.now(),
      rssi: row['rssi'] is int ? row['rssi'] as int : null,
      isSameChannel: row['is_same_channel'] == 1,
      tripId: row['trip_id']?.toString(),
      publicUserId: row['public_user_id']?.toString(),
      appDeviceId: row['app_device_id']?.toString(),
      verificationStatus:
          row['verification_status']?.toString() ?? 'unknown_same_channel',
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'endpoint_id': endpointId,
      'user_id': userId,
      'display_name': displayName,
      'device_name': deviceName,
      'active_channel_id': activeChannelId,
      'active_channel_code': activeChannelCode,
      'connection_status': status.name,
      'discovered_at': discoveredAt.toIso8601String(),
      'last_seen_at': lastSeenAt.toIso8601String(),
      'rssi': rssi,
      'is_same_channel': isSameChannel ? 1 : 0,
      'trip_id': tripId,
      'public_user_id': publicUserId,
      'app_device_id': appDeviceId,
      'verification_status': verificationStatus,
    };
  }
}
