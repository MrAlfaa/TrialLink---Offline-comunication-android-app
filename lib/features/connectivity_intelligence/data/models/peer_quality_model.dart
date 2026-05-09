import 'signal_quality_label.dart';
import 'trend_direction.dart';

class PeerQualityModel {
  const PeerQualityModel({
    required this.endpointId,
    required this.qualityScore,
    required this.qualityLabel,
    required this.trendDirection,
    required this.lastCalculatedAt,
    this.userId,
    this.displayName,
    this.channelId,
    this.channelCode,
    this.recommendedAction,
    this.lastAckRttMs,
    this.retryCount = 0,
  });

  final String endpointId;
  final String? userId;
  final String? displayName;
  final String? channelId;
  final String? channelCode;
  final double qualityScore;
  final SignalQualityLabel qualityLabel;
  final TrendDirection trendDirection;
  final String? recommendedAction;
  final DateTime lastCalculatedAt;
  final int? lastAckRttMs;
  final int retryCount;

  factory PeerQualityModel.fromDb(Map<String, Object?> row) {
    return PeerQualityModel(
      endpointId: row['endpoint_id'].toString(),
      userId: row['user_id']?.toString(),
      displayName: row['display_name']?.toString(),
      channelId: row['channel_id']?.toString(),
      channelCode: row['channel_code']?.toString(),
      qualityScore:
          double.tryParse(row['quality_score']?.toString() ?? '') ?? 0,
      qualityLabel: SignalQualityLabelX.fromString(
        row['quality_label']?.toString() ?? 'lost',
      ),
      trendDirection: TrendDirectionX.fromString(
        row['trend_direction']?.toString() ?? 'unknown',
      ),
      recommendedAction: row['recommended_action']?.toString(),
      lastCalculatedAt: DateTime.tryParse(
            row['last_calculated_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'endpoint_id': endpointId,
      'user_id': userId,
      'display_name': displayName,
      'channel_id': channelId,
      'channel_code': channelCode,
      'quality_score': qualityScore,
      'quality_label': qualityLabel.name,
      'trend_direction': trendDirection.name,
      'recommended_action': recommendedAction,
      'last_calculated_at': lastCalculatedAt.toIso8601String(),
    };
  }
}
