import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/nearby_connection_status.dart';

class PeerStatusChip extends StatelessWidget {
  const PeerStatusChip({required this.status, super.key});

  final PeerConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PeerConnectionStatus.connected => AppColors.success,
      PeerConnectionStatus.connecting => AppColors.skyBlue,
      PeerConnectionStatus.failed => AppColors.danger,
      PeerConnectionStatus.lost => AppColors.warning,
      PeerConnectionStatus.disconnected => AppColors.muted,
      PeerConnectionStatus.discovered => AppColors.signalOrange,
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.24)),
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text(
        status.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
