import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    super.key,
  });

  final Widget child;

  static const _tabs = [
    _NavTab('Home', Icons.home_rounded, '/home'),
    _NavTab('Chat', Icons.forum_rounded, '/chat'),
    _NavTab('Offline', Icons.hub_rounded, '/offline-channel'),
    _NavTab('SOS', Icons.sos_rounded, '/sos'),
    _NavTab('Map', Icons.map_rounded, '/map'),
    _NavTab('Connect', Icons.wifi_tethering_rounded, '/connectivity'),
    _NavTab('Settings', Icons.settings_rounded, '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _tabs
        .indexWhere((tab) {
          return location == tab.path || location.startsWith('${tab.path}/');
        })
        .clamp(0, _tabs.length - 1)
        .toInt();

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.deepForest,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepForest.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 68,
              backgroundColor: Colors.transparent,
              indicatorColor: _indicatorColor(_tabs[selectedIndex]),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.62),
                  fontSize: selected ? 12 : 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.58),
                  size: selected ? 26 : 24,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) => context.go(_tabs[index].path),
              destinations: _tabs
                  .map(
                    (tab) => NavigationDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: _SelectedNavIcon(tab: tab),
                      label: tab.label,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Color _indicatorColor(_NavTab tab) {
    if (tab.path == '/sos') {
      return AppColors.danger.withValues(alpha: 0.82);
    }
    return AppColors.signalOrange.withValues(alpha: 0.74);
  }
}

class _NavTab {
  const _NavTab(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

class _SelectedNavIcon extends StatelessWidget {
  const _SelectedNavIcon({required this.tab});

  final _NavTab tab;

  @override
  Widget build(BuildContext context) {
    final isSos = tab.path == '/sos';
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: 1.08,
      child: Icon(
        tab.icon,
        color: isSos ? Colors.white : Colors.white,
      ),
    );
  }
}
