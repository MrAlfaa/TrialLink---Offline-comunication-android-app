import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/peer_quality_model.dart';
import '../../data/models/signal_quality_label.dart';
import '../../data/models/trend_direction.dart';

class PeerQualityCard extends StatelessWidget {
  const PeerQualityCard({required this.peer, super.key});

  final PeerQualityModel peer;

  @override
  Widget build(BuildContext context) {
    final color = _qualityColor(peer.qualityLabel);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.person_pin_circle_rounded, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    peer.displayName ?? 'Nearby peer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(
                  label: Text(peer.qualityLabel.displayName),
                  backgroundColor: color.withValues(alpha: 0.12),
                  side: BorderSide(color: color.withValues(alpha: 0.28)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: peer.qualityScore / 100,
                color: color,
                backgroundColor: AppColors.muted.withValues(alpha: 0.16),
              ),
            ),
            const SizedBox(height: 8),
            Text('${peer.qualityScore.toStringAsFixed(0)}% quality'),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_trendIcon(peer.trendDirection), size: 18),
                const SizedBox(width: 6),
                Text(peer.trendDirection.displayName),
                const Spacer(),
                if (peer.lastAckRttMs != null)
                  Text('${peer.lastAckRttMs} ms ACK'),
              ],
            ),
            if ((peer.recommendedAction ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(peer.recommendedAction!),
            ],
          ],
        ),
      ),
    );
  }

  Color _qualityColor(SignalQualityLabel label) {
    return switch (label) {
      SignalQualityLabel.excellent => AppColors.success,
      SignalQualityLabel.good => AppColors.skyBlue,
      SignalQualityLabel.fair => AppColors.warning,
      SignalQualityLabel.weak => AppColors.signalOrange,
      SignalQualityLabel.lost => AppColors.danger,
    };
  }

  IconData _trendIcon(TrendDirection trend) {
    return switch (trend) {
      TrendDirection.improving => Icons.trending_up_rounded,
      TrendDirection.stable => Icons.trending_flat_rounded,
      TrendDirection.degrading => Icons.trending_down_rounded,
      TrendDirection.unknown => Icons.help_outline_rounded,
    };
  }
}
