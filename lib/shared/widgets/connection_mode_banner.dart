import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connection_mode_provider.dart';
import '../../core/mode/mode_controller.dart';
import '../../core/mode/mode_models.dart';

class ConnectionModeBanner extends ConsumerWidget {
  const ConnectionModeBanner({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeState = ref.watch(modeControllerProvider);
    final controller = ref.read(connectionModeProvider.notifier);
    return ConnectionModeBannerView(
      state: modeState,
      compact: compact,
      onRefresh: controller.checkNow,
    );
  }
}

class ConnectionModeBannerView extends StatelessWidget {
  const ConnectionModeBannerView({
    required this.state,
    required this.onRefresh,
    this.compact = false,
    super.key,
  });

  final ModeState state;
  final Future<void> Function() onRefresh;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = state.warningMessage == null
        ? state.userMode.color
        : Theme.of(context).colorScheme.error;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _PulsingDot(color: color),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey(
                    '${state.userMode.name}-${state.effectiveMode.name}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.effectiveMode == EffectiveMode.hybridLimited
                        ? 'Hybrid Limited'
                        : state.userMode.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      state.warningMessage ??
                          state.statusMessage ??
                          state.effectiveMode.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Check connection',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: color),
          ),
        ],
      ),
    );
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
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.45,
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
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
