import 'dart:math';

import 'models/peer_metric_sample_model.dart';
import 'models/signal_quality_label.dart';

class PeerQualityResult {
  const PeerQualityResult({
    required this.score,
    required this.label,
    this.lastAckRttMs,
    this.retryCount = 0,
  });

  final double score;
  final SignalQualityLabel label;
  final int? lastAckRttMs;
  final int retryCount;
}

class PeerQualityCalculator {
  PeerQualityResult calculate(List<PeerMetricSampleModel> samples) {
    if (samples.isEmpty) {
      return const PeerQualityResult(
        score: 0,
        label: SignalQualityLabel.lost,
      );
    }

    final latest = samples.last;
    final rssiSamples = samples.where((sample) => sample.rssi != null);
    double score = 50;

    if (rssiSamples.isNotEmpty) {
      final rssi = rssiSamples.last.rssi!;
      if (rssi >= -55) {
        score += 35;
      } else if (rssi >= -70) {
        score += 25;
      } else if (rssi >= -80) {
        score += 10;
      } else {
        score -= 10;
      }
    } else {
      if (latest.connectionStatus == 'connected') score += 20;
      final age = DateTime.now().difference(latest.lastSeenAt);
      if (age.inSeconds <= 10) {
        score += 15;
      } else if (age.inSeconds <= 30) {
        score += 8;
      } else if (age.inMinutes > 2) {
        score -= 20;
      }
    }

    final lastAck = samples.lastWhere(
      (sample) => sample.ackRttMs != null,
      orElse: () => latest,
    );
    final ackRtt = lastAck.ackRttMs;
    if (ackRtt != null) {
      if (ackRtt < 300) {
        score += 20;
      } else if (ackRtt <= 1000) {
        score += 10;
      } else {
        score -= 10;
      }
    }

    final successSamples = samples
        .where((sample) => sample.packetSuccessRate != null)
        .map((sample) => sample.packetSuccessRate!)
        .toList();
    if (successSamples.isNotEmpty) {
      final rate =
          successSamples.reduce((a, b) => a + b) / successSamples.length;
      if (rate >= 0.9) {
        score += 20;
      } else if (rate >= 0.6) {
        score += 10;
      } else {
        score -= 15;
      }
    }

    final retryCount =
        samples.map((sample) => sample.retryCount).fold<int>(0, max);
    if (retryCount > 2) score -= 10;
    final disconnectCount =
        samples.map((sample) => sample.disconnectCount).fold<int>(0, max);
    if (disconnectCount > 1) score -= 15;
    if (latest.connectionStatus == 'lost') score -= 35;

    final clamped = score.clamp(0, 100).toDouble();
    return PeerQualityResult(
      score: clamped,
      label: SignalQualityLabelX.fromScore(clamped),
      lastAckRttMs: ackRtt,
      retryCount: retryCount,
    );
  }
}
