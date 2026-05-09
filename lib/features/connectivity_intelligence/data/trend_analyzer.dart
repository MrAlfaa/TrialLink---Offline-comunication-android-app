import 'peer_quality_calculator.dart';
import 'models/peer_metric_sample_model.dart';
import 'models/trend_direction.dart';

class TrendAnalyzer {
  TrendAnalyzer({PeerQualityCalculator? calculator})
      : _calculator = calculator ?? PeerQualityCalculator();

  final PeerQualityCalculator _calculator;

  TrendDirection analyze(List<PeerMetricSampleModel> samples) {
    if (samples.length < 4) return TrendDirection.unknown;
    final ordered = [...samples]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final midpoint = (ordered.length / 2).floor();
    final early = ordered.take(midpoint).toList();
    final recent = ordered.skip(midpoint).toList();
    final earlyScore = _calculator.calculate(early).score;
    final recentScore = _calculator.calculate(recent).score;
    final delta = recentScore - earlyScore;
    if (delta >= 10) return TrendDirection.improving;
    if (delta <= -10) return TrendDirection.degrading;
    return TrendDirection.stable;
  }
}
