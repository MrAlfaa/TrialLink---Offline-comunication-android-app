import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';

class ChannelCodeBox extends StatelessWidget {
  const ChannelCodeBox({
    required this.channelCode,
    super.key,
  });

  final String channelCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepForest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              channelCode,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.deepForest,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Copy channel code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: channelCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Channel code copied.')),
              );
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}
