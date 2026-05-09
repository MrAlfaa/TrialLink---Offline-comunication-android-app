import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/compact_status_chip.dart';
import '../../data/models/offline_channel_model.dart';

class OfflineChannelCard extends StatelessWidget {
  const OfflineChannelCard({
    required this.channel,
    required this.onTap,
    required this.onSetActive,
    super.key,
  });

  final OfflineChannelModel channel;
  final VoidCallback onTap;
  final VoidCallback onSetActive;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        channel.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (channel.isActive)
                      const CompactStatusChip(
                        label: 'Active',
                        color: AppColors.success,
                        icon: Icons.radio_button_checked_rounded,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Channel Code: ${channel.channelCode}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.deepForest,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text('Created ${DateFormat.yMMMd().format(channel.createdAt)}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const CompactStatusChip(
                      label: 'Offline ready',
                      color: AppColors.offlinePurple,
                      icon: Icons.settings_input_antenna_rounded,
                      dense: true,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: channel.isActive ? null : onSetActive,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Set Active'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
