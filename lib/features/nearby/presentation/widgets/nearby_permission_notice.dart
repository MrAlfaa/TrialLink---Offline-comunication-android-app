import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class NearbyPermissionNotice extends StatelessWidget {
  const NearbyPermissionNotice({
    required this.message,
    required this.onRequest,
    super.key,
  });

  final String message;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bluetooth_searching_rounded,
                color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby permissions needed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onRequest,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('Grant Permissions'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
