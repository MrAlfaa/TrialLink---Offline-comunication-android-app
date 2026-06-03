class NetworkSpeedSampleModel {
  const NetworkSpeedSampleModel({
    required this.sampleId,
    required this.createdAt,
    required this.networkType,
    required this.backendReachable,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.heading,
    this.movementSpeedMps,
    this.pingMs,
    this.downloadMbps,
    this.uploadMbps,
    this.errorMessage,
  });

  final String sampleId;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? heading;
  final double? movementSpeedMps;
  final String networkType;
  final int? pingMs;
  final double? downloadMbps;
  final double? uploadMbps;
  final bool backendReachable;
  final String? errorMessage;

  String get qualityLabel {
    if (!backendReachable || downloadMbps == null) return 'No internet';
    final speed = downloadMbps!;
    if (speed >= 10) return 'Strong';
    if (speed >= 4) return 'Good';
    if (speed >= 1.2) return 'Usable';
    return 'Weak';
  }

  bool get hasLocation => latitude != null && longitude != null;

  factory NetworkSpeedSampleModel.fromDb(Map<String, Object?> row) {
    return NetworkSpeedSampleModel(
      sampleId: row['sample_id'].toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      latitude: _double(row['latitude']),
      longitude: _double(row['longitude']),
      accuracy: _double(row['accuracy']),
      heading: _double(row['heading']),
      movementSpeedMps: _double(row['movement_speed_mps']),
      networkType: row['network_type']?.toString() ?? 'unknown',
      pingMs: int.tryParse(row['ping_ms']?.toString() ?? ''),
      downloadMbps: _double(row['download_mbps']),
      uploadMbps: _double(row['upload_mbps']),
      backendReachable: row['backend_reachable'] == 1,
      errorMessage: row['error_message']?.toString(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'sample_id': sampleId,
      'created_at': createdAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'heading': heading,
      'movement_speed_mps': movementSpeedMps,
      'network_type': networkType,
      'ping_ms': pingMs,
      'download_mbps': downloadMbps,
      'upload_mbps': uploadMbps,
      'backend_reachable': backendReachable ? 1 : 0,
      'error_message': errorMessage,
    };
  }

  static double? _double(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
