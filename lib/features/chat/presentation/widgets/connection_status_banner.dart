import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/socket_service.dart';

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({
    required this.isOnline,
    required this.socketStatus,
    super.key,
  });

  final bool isOnline;
  final ChatSocketStatus socketStatus;

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          _PulsingDot(color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    if (!isOnline) return AppColors.warning;
    return socketStatus == ChatSocketStatus.connected
        ? AppColors.success
        : AppColors.signalOrange;
  }

  String get _label {
    if (!isOnline) return 'Offline - messages will be saved locally';
    switch (socketStatus) {
      case ChatSocketStatus.connected:
        return 'Online chat connected';
      case ChatSocketStatus.connecting:
        return 'Connecting to chat...';
      case ChatSocketStatus.reconnecting:
        return 'Reconnecting to chat...';
      case ChatSocketStatus.error:
        return 'Chat connection issue - messages stay local';
      case ChatSocketStatus.disconnected:
        return 'Chat disconnected - messages stay local';
    }
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 0.55,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
