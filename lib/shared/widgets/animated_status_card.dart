import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/system_status_service.dart';

class AnimatedStatusCard extends StatefulWidget {
  const AnimatedStatusCard({
    required this.title,
    required this.message,
    required this.state,
    this.detail,
    this.icon = Icons.check_circle_outline_rounded,
    this.delay = Duration.zero,
    super.key,
  });

  final String title;
  final String message;
  final String? detail;
  final SystemCheckState state;
  final IconData icon;
  final Duration delay;

  @override
  State<AnimatedStatusCard> createState() => _AnimatedStatusCardState();
}

class _AnimatedStatusCardState extends State<AnimatedStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(widget.state);

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PulsingStatusIndicator(color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(widget.icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(widget.message),
                      if (widget.detail != null && widget.detail!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            widget.detail!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PulsingStatusIndicator extends StatefulWidget {
  const PulsingStatusIndicator({
    required this.color,
    this.size = 12,
    super.key,
  });

  final Color color;
  final double size;

  @override
  State<PulsingStatusIndicator> createState() => _PulsingStatusIndicatorState();
}

class _PulsingStatusIndicatorState extends State<PulsingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.78, end: 1.1).animate(
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
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        margin: const EdgeInsets.only(top: 7),
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.26),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(SystemCheckState state) {
  switch (state) {
    case SystemCheckState.success:
      return AppColors.success;
    case SystemCheckState.warning:
      return AppColors.warning;
    case SystemCheckState.error:
      return AppColors.danger;
    case SystemCheckState.loading:
      return AppColors.skyBlue;
    case SystemCheckState.idle:
      return AppColors.muted;
  }
}
