import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class CloudSyncStatusBanner extends StatelessWidget {
  const CloudSyncStatusBanner({
    super.key,
    required this.message,
    this.publicUserId,
  });

  final String message;
  final String? publicUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.deepForest.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.deepForest.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded, color: AppColors.deepForest),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              publicUserId == null ? message : '$message\n$publicUserId',
            ),
          ),
        ],
      ),
    );
  }
}
