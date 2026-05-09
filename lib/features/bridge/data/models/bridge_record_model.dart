class BridgeRecordModel {
  const BridgeRecordModel({
    required this.bridgeRecordId,
    required this.sourcePath,
    required this.direction,
    required this.channelCode,
    required this.bridgedByLocalId,
    required this.bridgedAt,
    required this.status,
    required this.payloadJson,
    required this.createdAt,
    this.originalPacketId,
    this.clientMessageId,
    this.tripId,
    this.groupId,
    this.channelId,
    this.originSenderId,
    this.originSenderLocalId,
    this.originDisplayName,
    this.bridgedByBackendId,
    this.bridgedByName,
    this.errorMessage,
    this.updatedAt,
  });

  factory BridgeRecordModel.fromDb(Map<String, Object?> row) {
    return BridgeRecordModel(
      bridgeRecordId: row['bridge_record_id'].toString(),
      originalPacketId: row['original_packet_id']?.toString(),
      clientMessageId: row['client_message_id']?.toString(),
      sourcePath: row['source_path'].toString(),
      direction: row['direction'].toString(),
      tripId: row['trip_id']?.toString(),
      groupId: row['group_id']?.toString(),
      channelId: row['channel_id']?.toString(),
      channelCode: row['channel_code'].toString(),
      originSenderId: row['origin_sender_id']?.toString(),
      originSenderLocalId: row['origin_sender_local_id']?.toString(),
      originDisplayName: row['origin_display_name']?.toString(),
      bridgedByLocalId: row['bridged_by_local_id'].toString(),
      bridgedByBackendId: row['bridged_by_backend_id']?.toString(),
      bridgedByName: row['bridged_by_name']?.toString(),
      bridgedAt: DateTime.tryParse(row['bridged_at']?.toString() ?? '') ??
          DateTime.now(),
      status: row['status'].toString(),
      payloadJson: row['payload_json'].toString(),
      errorMessage: row['error_message']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }

  final String bridgeRecordId;
  final String? originalPacketId;
  final String? clientMessageId;
  final String sourcePath;
  final String direction;
  final String? tripId;
  final String? groupId;
  final String? channelId;
  final String channelCode;
  final String? originSenderId;
  final String? originSenderLocalId;
  final String? originDisplayName;
  final String bridgedByLocalId;
  final String? bridgedByBackendId;
  final String? bridgedByName;
  final DateTime bridgedAt;
  final String status;
  final String payloadJson;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toDbMap() {
    return {
      'bridge_record_id': bridgeRecordId,
      'original_packet_id': originalPacketId,
      'client_message_id': clientMessageId,
      'source_path': sourcePath,
      'direction': direction,
      'trip_id': tripId,
      'group_id': groupId,
      'channel_id': channelId,
      'channel_code': channelCode,
      'origin_sender_id': originSenderId,
      'origin_sender_local_id': originSenderLocalId,
      'origin_display_name': originDisplayName,
      'bridged_by_local_id': bridgedByLocalId,
      'bridged_by_backend_id': bridgedByBackendId,
      'bridged_by_name': bridgedByName,
      'bridged_at': bridgedAt.toIso8601String(),
      'status': status,
      'payload_json': payloadJson,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
