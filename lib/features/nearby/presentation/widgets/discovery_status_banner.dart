import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class DiscoveryStatusBanner extends StatelessWidget {
  const DiscoveryStatusBanner({
    required this.isAdvertising,
    required this.isDiscovering,
    required this.connectedCount,
    this.lastScanAt,
    super.key,
  });

  final bool isAdvertising;
  final bool isDiscovering;
  final int connectedCount;
  final DateTime? lastScanAt;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discovery Status',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusPill(
                  label: 'Advertising ${isAdvertising ? "On" : "Off"}',
                  active: isAdvertising,
                ),
                _StatusPill(
                  label: 'Discovery ${isDiscovering ? "On" : "Off"}',
                  active: isDiscovering,
                ),
                _StatusPill(
                  label: '$connectedCount Connected',
                  active: connectedCount > 0,
                ),
              ],
            ),
            if (lastScanAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Last scan ${DateFormat('HH:mm:ss').format(lastScanAt!)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.muted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
