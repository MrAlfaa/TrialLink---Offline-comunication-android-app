import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/offline_text_only_flags.dart';
import '../../core/constants/app_colors.dart';
import '../../core/mode/mode_models.dart';
import 'mode_center_button.dart';

class TrailBottomNav extends StatelessWidget {
  const TrailBottomNav({
    required this.location,
    required this.mode,
    required this.onModePressed,
    required this.modeButtonEnabled,
    this.effectiveMode = EffectiveMode.online,
    super.key,
  });

  final String location;
  final UserMode mode;
  final EffectiveMode effectiveMode;
  final VoidCallback onModePressed;
  final bool modeButtonEnabled;

  @override
  Widget build(BuildContext context) {
    final offlineTextOnly =
        OfflineTextOnlyFlags.enabled && effectiveMode == EffectiveMode.offline;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 86,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 14,
              right: 14,
              bottom: 8,
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.deepForest,
                  borderRadius: BorderRadius.circular(26),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.deepForest.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      label: 'Home',
                      icon: Icons.home_rounded,
                      selected: _matches('/home'),
                      onTap: () => context.go('/home'),
                    ),
                    _NavItem(
                      label: 'Messages',
                      icon: Icons.forum_rounded,
                      selected: _isMessages,
                      onTap: () => context.go('/chat'),
                    ),
                    const SizedBox(width: 64),
                    if (offlineTextOnly) ...[
                      _NavItem(
                        label: 'Nearby',
                        icon: Icons.radar_rounded,
                        selected: _matches('/nearby-peers'),
                        onTap: () => context.go('/nearby-peers'),
                      ),
                      _NavItem(
                        label: 'Channels',
                        icon: Icons.hub_rounded,
                        selected: _matches('/offline-channel'),
                        onTap: () => context.go('/offline-channel'),
                      ),
                    ] else ...[
                      _NavItem(
                        label: 'Map',
                        icon: Icons.map_rounded,
                        selected: _matches('/map') || location.contains('/map'),
                        onTap: () => context.go('/map'),
                      ),
                      _NavItem(
                        label: 'SOS',
                        icon: Icons.sos_rounded,
                        selected: _matches('/sos') || location.contains('/sos'),
                        color: AppColors.danger,
                        onTap: () => context.go('/sos'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 3,
              child: ModeCenterButton(
                mode: mode,
                onPressed: onModePressed,
                enabled: modeButtonEnabled,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matches(String path) {
    return location == path || location.startsWith('$path/');
  }

  bool get _isMessages {
    return _matches('/chat') ||
        location.contains('/chat') ||
        location.contains('/groups/');
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color = AppColors.signalOrange,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.62),
                size: selected ? 23 : 21,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? Padding(
                        key: ValueKey(label),
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
