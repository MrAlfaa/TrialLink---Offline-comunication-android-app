import 'p2p_session_state.dart';

class P2PSessionModel {
  const P2PSessionModel({
    this.id,
    required this.sessionId,
    required this.tripId,
    required this.channelId,
    required this.channelCode,
    required this.localUserId,
    required this.state,
    required this.startedAt,
    this.endedAt,
    this.lastActivityAt,
    this.errorMessage,
    required this.isActive,
  });

  final int? id;
  final String sessionId;
  final String tripId;
  final String channelId;
  final String channelCode;
  final String localUserId;
  final P2PSessionState state;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? lastActivityAt;
  final String? errorMessage;
  final bool isActive;

  bool get blocksTripSwitch => isActive && state.blocksTripSwitch;

  factory P2PSessionModel.fromDb(Map<String, Object?> row) {
    return P2PSessionModel(
      id: row['id'] as int?,
      sessionId: row['session_id'].toString(),
      tripId: row['trip_id'].toString(),
      channelId: row['channel_id'].toString(),
      channelCode: row['channel_code'].toString(),
      localUserId: row['local_user_id'].toString(),
      state: P2PSessionState.parse(row['state']?.toString() ?? 'idle'),
      startedAt: DateTime.tryParse(row['started_at']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(row['ended_at']?.toString() ?? ''),
      lastActivityAt:
          DateTime.tryParse(row['last_activity_at']?.toString() ?? ''),
      errorMessage: row['error_message']?.toString(),
      isActive: row['is_active'] == 1,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'trip_id': tripId,
      'channel_id': channelId,
      'channel_code': channelCode,
      'local_user_id': localUserId,
      'state': state.name,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'last_activity_at': lastActivityAt?.toIso8601String(),
      'error_message': errorMessage,
      'is_active': isActive ? 1 : 0,
    };
  }
}
