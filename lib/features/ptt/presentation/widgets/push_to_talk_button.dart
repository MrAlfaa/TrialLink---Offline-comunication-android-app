import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class PushToTalkButton extends StatelessWidget {
  const PushToTalkButton({
    required this.isRecording,
    required this.isWaiting,
    required this.enabled,
    required this.onPress,
    required this.onRelease,
    this.idleLabel = 'Hold to Talk',
    this.activeLabel = 'Release to Send',
    this.waitingLabel = 'Waiting...',
    this.icon = Icons.mic_rounded,
    super.key,
  });

  final bool isRecording;
  final bool isWaiting;
  final bool enabled;
  final VoidCallback onPress;
  final VoidCallback onRelease;
  final String idleLabel;
  final String activeLabel;
  final String waitingLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? AppColors.danger : AppColors.signalOrange;
    final secondary =
        isRecording ? AppColors.signalOrange : AppColors.offlinePurple;
    final label = isWaiting
        ? waitingLabel
        : isRecording
            ? activeLabel
            : idleLabel;
    return GestureDetector(
      onLongPressStart: enabled ? (_) => onPress() : null,
      onLongPressEnd: enabled ? (_) => onRelease() : null,
      onTapDown: enabled ? (_) => onPress() : null,
      onTapUp: enabled ? (_) => onRelease() : null,
      onTapCancel: enabled ? onRelease : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: isRecording ? 1.06 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 178,
          height: 178,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, secondary],
                  )
                : null,
            color: enabled ? null : AppColors.muted,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.58),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isRecording ? 0.42 : 0.20),
                blurRadius: isRecording ? 38 : 20,
                spreadRadius: isRecording ? 8 : 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isRecording)
                Container(
                  width: 154,
                  height: 154,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.32),
                      width: 2,
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 44),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
