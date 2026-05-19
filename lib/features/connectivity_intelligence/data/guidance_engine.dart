import 'models/connectivity_guidance_model.dart';
import 'models/peer_quality_model.dart';
import 'models/signal_quality_label.dart';
import 'models/trend_direction.dart';

class GuidanceEngine {
  ConnectivityGuidanceModel build({
    required String? channelId,
    required String? channelCode,
    required List<PeerQualityModel> peers,
    required int pendingOfflineMessages,
    bool emergencyActive = false,
  }) {
    final now = DateTime.now();
    if (channelCode == null || channelCode.isEmpty) {
      return ConnectivityGuidanceModel(
        guidanceType: 'no_peers',
        message:
            'Create or join an offline channel before using connectivity guidance.',
        createdAt: now,
      );
    }

    if (peers.isEmpty) {
      return ConnectivityGuidanceModel(
        channelId: channelId,
        channelCode: channelCode,
        guidanceType: pendingOfflineMessages > 0 ? 'reconnect' : 'no_peers',
        message: pendingOfflineMessages > 0
            ? 'Messages are waiting to send. Reconnect with a nearby phone to forward them.'
            : 'No nearby phones found. Move closer to your group or open Connect Phones.',
        createdAt: now,
      );
    }

    final sorted = [...peers]
      ..sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
    final best = sorted.first;
    final name = best.displayName ?? 'this phone';

    if (emergencyActive &&
        (best.qualityLabel == SignalQualityLabel.weak ||
            best.qualityLabel == SignalQualityLabel.lost)) {
      return ConnectivityGuidanceModel(
        channelId: channelId,
        channelCode: channelCode,
        relatedEndpointId: best.endpointId,
        guidanceType: 'move_closer',
        message:
            'Emergency alert not confirmed. Move toward a stronger phone connection if possible.',
        createdAt: now,
      );
    }

    if (best.trendDirection == TrendDirection.improving) {
      return ConnectivityGuidanceModel(
        channelId: channelId,
        channelCode: channelCode,
        relatedEndpointId: best.endpointId,
        guidanceType: 'signal_improving',
        message:
            'Signal to $name is improving. Continue moving in this direction.',
        createdAt: now,
      );
    }

    if (best.trendDirection == TrendDirection.degrading) {
      return ConnectivityGuidanceModel(
        channelId: channelId,
        channelCode: channelCode,
        relatedEndpointId: best.endpointId,
        guidanceType: 'signal_degrading',
        message:
            'Signal to $name is getting weaker. Move back toward the previous position.',
        createdAt: now,
      );
    }

    if (sorted.every((peer) =>
        peer.qualityLabel == SignalQualityLabel.weak ||
        peer.qualityLabel == SignalQualityLabel.lost)) {
      return ConnectivityGuidanceModel(
        channelId: channelId,
        channelCode: channelCode,
        guidanceType: 'move_closer',
        message:
            'Connection is weak. Move to an open area or closer to teammates.',
        createdAt: now,
      );
    }

    return ConnectivityGuidanceModel(
      channelId: channelId,
      channelCode: channelCode,
      relatedEndpointId: best.endpointId,
      guidanceType: 'stay_position',
      message: 'Connection to $name is strong. Stay within this range.',
      createdAt: now,
    );
  }
}
