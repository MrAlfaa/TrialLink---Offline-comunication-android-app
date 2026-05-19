import '../../nearby/data/models/nearby_peer_model.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import 'connectivity_metrics_local_data_source.dart';
import 'guidance_engine.dart';
import 'models/connectivity_guidance_model.dart';
import 'models/peer_metric_sample_model.dart';
import 'models/peer_quality_model.dart';
import 'models/signal_quality_label.dart';
import 'peer_quality_calculator.dart';
import 'trend_analyzer.dart';

class ConnectivityIntelligenceSummary {
  const ConnectivityIntelligenceSummary({
    required this.qualities,
    required this.guidance,
    required this.pendingOfflineMessages,
    required this.lastUpdatedAt,
  });

  final List<PeerQualityModel> qualities;
  final ConnectivityGuidanceModel guidance;
  final int pendingOfflineMessages;
  final DateTime lastUpdatedAt;

  String get overallLabel {
    if (qualities.isEmpty) return 'No phones';
    final best = qualities.first.qualityLabel.displayName;
    return best;
  }
}

class ConnectivityIntelligenceRepository {
  ConnectivityIntelligenceRepository({
    ConnectivityMetricsLocalDataSource? local,
    PeerQualityCalculator? calculator,
    TrendAnalyzer? trendAnalyzer,
    GuidanceEngine? guidanceEngine,
  })  : _local = local ?? ConnectivityMetricsLocalDataSource(),
        _calculator = calculator ?? PeerQualityCalculator(),
        _trendAnalyzer = trendAnalyzer ?? TrendAnalyzer(),
        _guidanceEngine = guidanceEngine ?? GuidanceEngine();

  final ConnectivityMetricsLocalDataSource _local;
  final PeerQualityCalculator _calculator;
  final TrendAnalyzer _trendAnalyzer;
  final GuidanceEngine _guidanceEngine;

  Future<void> recordPeerSample({
    required NearbyPeerModel peer,
    required String sampleSource,
    int? ackRttMs,
    double? packetSuccessRate,
    int retryCount = 0,
    int disconnectCount = 0,
  }) async {
    await recordSample(
      PeerMetricSampleModel(
        endpointId: peer.endpointId,
        userId: peer.userId,
        displayName: peer.displayName,
        channelId: peer.activeChannelId,
        channelCode: peer.activeChannelCode,
        rssi: peer.rssi,
        ackRttMs: ackRttMs,
        packetSuccessRate: packetSuccessRate,
        retryCount: retryCount,
        disconnectCount: disconnectCount,
        connectionStatus: peer.status.name,
        lastSeenAt: peer.lastSeenAt,
        sampleSource: sampleSource,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordSyntheticSample({
    required String endpointId,
    required String channelId,
    required String channelCode,
    required String connectionStatus,
    required String sampleSource,
    String? userId,
    String? displayName,
    int? ackRttMs,
    double? packetSuccessRate,
    int retryCount = 0,
    int disconnectCount = 0,
  }) async {
    await recordSample(
      PeerMetricSampleModel(
        endpointId: endpointId,
        userId: userId,
        displayName: displayName,
        channelId: channelId,
        channelCode: channelCode,
        ackRttMs: ackRttMs,
        packetSuccessRate: packetSuccessRate,
        retryCount: retryCount,
        disconnectCount: disconnectCount,
        connectionStatus: connectionStatus,
        lastSeenAt: DateTime.now(),
        sampleSource: sampleSource,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordSample(PeerMetricSampleModel sample) async {
    await _local.insertSample(sample);
    await _recalculateEndpoint(sample.endpointId);
  }

  Future<ConnectivityIntelligenceSummary> summary(
    OfflineChannelModel? channel,
  ) async {
    if (channel == null) {
      final guidance = _guidanceEngine.build(
        channelId: null,
        channelCode: null,
        peers: const [],
        pendingOfflineMessages: 0,
      );
      return ConnectivityIntelligenceSummary(
        qualities: const [],
        guidance: guidance,
        pendingOfflineMessages: 0,
        lastUpdatedAt: DateTime.now(),
      );
    }

    final qualities = await _local.qualityScores(channel.channelCode);
    final pending = await _local.pendingOfflinePacketCount(channel.channelId);
    final guidance = _guidanceEngine.build(
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      peers: qualities,
      pendingOfflineMessages: pending,
    );
    await _local.saveGuidance(guidance);
    return ConnectivityIntelligenceSummary(
      qualities: qualities,
      guidance: guidance,
      pendingOfflineMessages: pending,
      lastUpdatedAt: DateTime.now(),
    );
  }

  Future<void> _recalculateEndpoint(String endpointId) async {
    final samples = await _local.samplesForEndpoint(endpointId, limit: 10);
    if (samples.isEmpty) return;
    final latest = samples.last;
    final result = _calculator.calculate(samples);
    final trend = _trendAnalyzer.analyze(samples);
    await _local.upsertQuality(
      PeerQualityModel(
        endpointId: endpointId,
        userId: latest.userId,
        displayName: latest.displayName,
        channelId: latest.channelId,
        channelCode: latest.channelCode,
        qualityScore: result.score,
        qualityLabel: result.label,
        trendDirection: trend,
        recommendedAction: _recommendedAction(result.label.name, trend.name),
        lastCalculatedAt: DateTime.now(),
        lastAckRttMs: result.lastAckRttMs,
        retryCount: result.retryCount,
      ),
    );
  }

  String _recommendedAction(String label, String trend) {
    if (label == 'excellent' || label == 'good') {
      return trend == 'degrading'
          ? 'Signal is dropping; slow down and keep line of sight.'
          : 'Connection is usable. Stay within this range.';
    }
    if (label == 'fair') return 'Keep phones nearby and avoid obstacles.';
    return 'Move closer to a teammate or open Connect Phones again.';
  }
}

final connectivityIntelligenceRepository = ConnectivityIntelligenceRepository();
