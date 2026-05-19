import 'p2p_session_state.dart';

class P2PPeerConnectionModel {
  const P2PPeerConnectionModel({
    this.id,
    required this.sessionId,
    required this.tripId,
    required this.channelId,
    required this.channelCode,
    this.endpointId,
    this.peerLocalId,
    this.peerPublicUserId,
    this.peerDisplayName,
    required this.connectionState,
    this.lastSeenAt,
    this.lastHeartbeatAt,
    required this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String sessionId;
  final String tripId;
  final String channelId;
  final String channelCode;
  final String? endpointId;
  final String? peerLocalId;
  final String? peerPublicUserId;
  final String? peerDisplayName;
  final P2PPeerConnectionState connectionState;
  final DateTime? lastSeenAt;
  final DateTime? lastHeartbeatAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  factory P2PPeerConnectionModel.fromDb(Map<String, Object?> row) {
    return P2PPeerConnectionModel(
      id: row['id'] as int?,
      sessionId: row['session_id'].toString(),
      tripId: row['trip_id'].toString(),
      channelId: row['channel_id'].toString(),
      channelCode: row['channel_code'].toString(),
      endpointId: row['endpoint_id']?.toString(),
      peerLocalId: row['peer_local_id']?.toString(),
      peerPublicUserId: row['peer_public_user_id']?.toString(),
      peerDisplayName: row['peer_display_name']?.toString(),
      connectionState: P2PPeerConnectionState.parse(
        row['connection_state']?.toString() ?? 'disconnected',
      ),
      lastSeenAt: DateTime.tryParse(row['last_seen_at']?.toString() ?? ''),
      lastHeartbeatAt:
          DateTime.tryParse(row['last_heartbeat_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'trip_id': tripId,
      'channel_id': channelId,
      'channel_code': channelCode,
      'endpoint_id': endpointId,
      'peer_local_id': peerLocalId,
      'peer_public_user_id': peerPublicUserId,
      'peer_display_name': peerDisplayName,
      'connection_state': connectionState.name,
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'last_heartbeat_at': lastHeartbeatAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
