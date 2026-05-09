import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OfflineDeliveryStatus extends StatelessWidget {
  const OfflineDeliveryStatus({
    required this.status,
    required this.ackStatus,
    super.key,
  });

  final String status;
  final String ackStatus;

  @override
  Widget build(BuildContext context) {
    final label = ackStatus == 'timeout' ? 'ack timeout' : status;
    final color = switch (label) {
      'delivered' => AppColors.success,
      'sent' => AppColors.skyBlue,
      'sending' => AppColors.skyBlue,
      'failed' => AppColors.danger,
      'ack timeout' => AppColors.warning,
      'received' => AppColors.muted,
      _ => AppColors.warning,
    };
    final icon = switch (label) {
      'delivered' => Icons.done_all_rounded,
      'sent' => Icons.done_rounded,
      'failed' => Icons.error_outline_rounded,
      'ack timeout' => Icons.schedule_rounded,
      _ => Icons.access_time_rounded,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
