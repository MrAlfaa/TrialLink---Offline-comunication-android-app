import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OfflineModeNotice extends StatelessWidget {
  const OfflineModeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.signalOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_rounded, color: AppColors.signalOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Offline channels work like walkie-talkie codes. Users who enter the same channel code can communicate when nearby device discovery is available.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
