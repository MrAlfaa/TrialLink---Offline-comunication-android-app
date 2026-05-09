import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class QuickSosLockedCard extends StatelessWidget {
  const QuickSosLockedCard({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Card(
      color: AppColors.dangerSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Emergency Access',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'SOS can be sent without opening private messages, maps, or trip data.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: onPressed,
              icon: const Icon(Icons.emergency_share_rounded),
              label: const Text('Emergency SOS'),
            ),
          ],
        ),
      ),
    );
  }
}
