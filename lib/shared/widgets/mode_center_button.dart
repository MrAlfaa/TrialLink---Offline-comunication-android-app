import 'package:flutter/material.dart';

import '../../core/mode/mode_models.dart';

class ModeCenterButton extends StatefulWidget {
  const ModeCenterButton({
    required this.mode,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final UserMode mode;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<ModeCenterButton> createState() => _ModeCenterButtonState();
}

class _ModeCenterButtonState extends State<ModeCenterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.mode.color;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Communication mode',
      child: ScaleTransition(
        scale: widget.enabled ? _scale : const AlwaysStoppedAnimation(1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.enabled ? widget.onPressed : null,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.enabled ? color : Colors.grey.shade500,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: (widget.enabled ? color : Colors.grey)
                        .withValues(alpha: 0.20),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                widget.enabled ? widget.mode.icon : Icons.sync_lock_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
