import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class PushToTalkButton extends StatefulWidget {
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
  State<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<PushToTalkButton> {
  bool _pressed = false;

  void _press() {
    if (!widget.enabled || _pressed) return;
    _pressed = true;
    widget.onPress();
  }

  void _release() {
    if (!_pressed && !widget.isRecording) return;
    _pressed = false;
    widget.onRelease();
  }

  @override
  void didUpdateWidget(PushToTalkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && !widget.isRecording && !widget.isWaiting) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isRecording ? AppColors.danger : AppColors.signalOrange;
    final secondary =
        widget.isRecording ? AppColors.signalOrange : AppColors.offlinePurple;
    final label = widget.isWaiting
        ? widget.waitingLabel
        : widget.isRecording
            ? widget.activeLabel
            : widget.idleLabel;
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: widget.isRecording ? 1.06 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 178,
          height: 178,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.enabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color, secondary],
                  )
                : null,
            color: widget.enabled ? null : AppColors.muted,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.58),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    color.withValues(alpha: widget.isRecording ? 0.42 : 0.20),
                blurRadius: widget.isRecording ? 38 : 20,
                spreadRadius: widget.isRecording ? 8 : 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isRecording)
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
                  Icon(widget.icon, color: Colors.white, size: 44),
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
