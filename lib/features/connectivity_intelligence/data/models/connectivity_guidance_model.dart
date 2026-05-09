class ConnectivityGuidanceModel {
  const ConnectivityGuidanceModel({
    required this.guidanceType,
    required this.message,
    required this.createdAt,
    this.channelId,
    this.channelCode,
    this.relatedEndpointId,
  });

  final String? channelId;
  final String? channelCode;
  final String guidanceType;
  final String message;
  final String? relatedEndpointId;
  final DateTime createdAt;

  factory ConnectivityGuidanceModel.fromDb(Map<String, Object?> row) {
    return ConnectivityGuidanceModel(
      channelId: row['channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      guidanceType: row['guidance_type']?.toString() ?? 'no_peers',
      message: row['message']?.toString() ?? '',
      relatedEndpointId: row['related_endpoint_id']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'channel_id': channelId,
      'channel_code': channelCode,
      'guidance_type': guidanceType,
      'message': message,
      'related_endpoint_id': relatedEndpointId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
