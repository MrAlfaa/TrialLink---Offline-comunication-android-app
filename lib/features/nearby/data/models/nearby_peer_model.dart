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
    };
  }
}
