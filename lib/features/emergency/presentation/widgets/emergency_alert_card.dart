import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/emergency_event_model.dart';

class EmergencyAlertCard extends StatelessWidget {
  const EmergencyAlertCard({
    required this.event,
    this.onAcknowledge,
    this.onViewMap,
    super.key,
  });

  final EmergencyEventModel event;
  final VoidCallback? onAcknowledge;
  final VoidCallback? onViewMap;

  @override
  Widget build(BuildContext context) {
    final hasLocation = event.latitude != null && event.longitude != null;
    final isAcknowledged =
        event.status == 'acknowledged' || event.ackStatus == 'acknowledged';
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency_share_rounded,
                    color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Emergency Alert',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(
                    label:
                        Text(isAcknowledged ? 'acknowledged' : event.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                event.message?.isEmpty == false ? event.message! : 'Need help'),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMd().add_jm().format(event.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (hasLocation) ...[
              const SizedBox(height: 8),
              Text(
                'Location: ${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isAcknowledged ? null : onAcknowledge,
                    icon: const Icon(Icons.check_circle_rounded),
                    label:
                        Text(isAcknowledged ? 'Acknowledged' : 'Acknowledge'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasLocation ? onViewMap : null,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('View Map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
