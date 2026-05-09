class EmergencyAckModel {
  const EmergencyAckModel({
    required this.ackId,
    required this.localEventId,
    required this.ackFromUserId,
    required this.ackMode,
    required this.receivedAt,
    this.ackFromName,
  });

  final String ackId;
  final String localEventId;
  final String ackFromUserId;
  final String? ackFromName;
  final String ackMode;
  final DateTime receivedAt;

  Map<String, Object?> toDbMap() {
    return {
      'ack_id': ackId,
      'local_event_id': localEventId,
      'ack_from_user_id': ackFromUserId,
      'ack_from_name': ackFromName,
      'ack_mode': ackMode,
      'received_at': receivedAt.toIso8601String(),
    };
  }
}
