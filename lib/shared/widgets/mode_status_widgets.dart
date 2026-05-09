import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/mode/mode_models.dart';
import 'compact_status_chip.dart';

enum SyncChipStatus {
  ready,
  paused,
  queued,
  savedLocal,
}

class ModeStatusChip extends StatelessWidget {
  const ModeStatusChip({
    required this.state,
    this.dense = true,
    super.key,
  });

  final ModeState state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final label = _modeLabel(state);
    final color = _modeColor(state);
    return CompactStatusChip(
      label: label,
      color: color,
      icon: _modeIcon(state),
      dense: dense,
    );
  }

  String _modeLabel(ModeState state) {
    if (state.connectionState == DetectedConnectionState.unstable) {
      return 'Unstable';
    }
    if (state.effectiveMode == EffectiveMode.hybridLimited ||
        state.connectionState == DetectedConnectionState.reconnecting) {
      return 'Reconnecting';
    }
    if (state.modeControlType == ModeControlType.auto) return 'Auto';
    return state.effectiveMode == EffectiveMode.online ? 'Online' : 'Offline';
  }

  Color _modeColor(ModeState state) {
    if (state.connectionState == DetectedConnectionState.unstable) {
      return AppColors.warning;
    }
    return switch (state.effectiveMode) {
      EffectiveMode.online => AppColors.success,
      EffectiveMode.offline => AppColors.offlinePurple,
      EffectiveMode.hybridLimited => AppColors.skyBlue,
    };
  }

  IconData _modeIcon(ModeState state) {
    if (state.connectionState == DetectedConnectionState.unstable) {
      return Icons.warning_amber_rounded;
    }
    return switch (state.effectiveMode) {
      EffectiveMode.online => Icons.cloud_done_rounded,
      EffectiveMode.offline => Icons.settings_input_antenna_rounded,
      EffectiveMode.hybridLimited => Icons.sync_rounded,
    };
  }
}

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    required this.status,
    this.dense = true,
    super.key,
  });

  final SyncChipStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return CompactStatusChip(
      label: switch (status) {
        SyncChipStatus.ready => 'Sync ready',
        SyncChipStatus.paused => 'Sync paused',
        SyncChipStatus.queued => 'Queued',
        SyncChipStatus.savedLocal => 'Saved locally',
      },
      color: switch (status) {
        SyncChipStatus.ready => AppColors.success,
        SyncChipStatus.paused => AppColors.offlinePurple,
        SyncChipStatus.queued => AppColors.warning,
        SyncChipStatus.savedLocal => AppColors.offlinePurple,
      },
      icon: switch (status) {
        SyncChipStatus.ready => Icons.cloud_done_rounded,
        SyncChipStatus.paused => Icons.cloud_off_rounded,
        SyncChipStatus.queued => Icons.schedule_rounded,
        SyncChipStatus.savedLocal => Icons.save_rounded,
      },
      dense: dense,
    );
  }
}

class PeerStatusChip extends StatelessWidget {
  const PeerStatusChip({
    required this.count,
    this.dense = true,
    super.key,
  });

  final int count;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return CompactStatusChip(
      label: switch (count) {
        0 => 'No peers',
        1 => '1 peer',
        _ => '$count peers',
      },
      color: count > 0 ? AppColors.success : AppColors.muted,
      icon: count > 0
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded,
      dense: dense,
    );
  }
}

class CompactStatusRow extends StatelessWidget {
  const CompactStatusRow({
    required this.children,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}

class InlineInfoNotice extends StatelessWidget {
  const InlineInfoNotice({
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.deepForest),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            action!,
          ],
        ],
      ),
    );
  }
}

class SmallWarningStrip extends StatelessWidget {
  const SmallWarningStrip({
    required this.message,
    this.icon = Icons.warning_amber_rounded,
    this.color = AppColors.warning,
    super.key,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
