import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/connectivity_guidance_model.dart';

class GuidanceBanner extends StatelessWidget {
  const GuidanceBanner({required this.guidance, super.key});

  final ConnectivityGuidanceModel guidance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.signalOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.signalOrange.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.explore_rounded, color: AppColors.signalOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              guidance.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
