import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/ptt_floor_state.dart';

class SpeakerLockBanner extends StatelessWidget {
  const SpeakerLockBanner({
    required this.floor,
    required this.isRecording,
    required this.isWaiting,
    super.key,
  });

  final PttFloorState? floor;
  final bool isRecording;
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    final text = isWaiting
        ? 'Waiting for floor'
        : isRecording
            ? 'You are speaking'
            : floor?.hasSpeaker == true
                ? '${floor!.currentSpeakerName ?? 'A teammate'} is speaking'
                : 'Channel free';
    final color = isRecording
        ? AppColors.danger
        : isWaiting
            ? AppColors.warning
            : floor?.hasSpeaker == true
                ? AppColors.signalOrange
                : AppColors.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.record_voice_over_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
