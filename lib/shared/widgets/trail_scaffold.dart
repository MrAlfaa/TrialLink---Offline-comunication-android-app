import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/mode/mode_controller.dart';
import '../../core/mode/mode_models.dart';
import '../../features/trip/data/trip_session_model.dart';
import '../../features/trip/data/trip_session_service.dart';
import 'mode_bottom_sheet.dart';
import 'trail_bottom_nav.dart';

class TrailScaffold extends ConsumerStatefulWidget {
  const TrailScaffold({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<TrailScaffold> createState() => _TrailScaffoldState();
}

class _TrailScaffoldState extends ConsumerState<TrailScaffold> {
  DateTime? _lastRootBackAt;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final modeState = ref.watch(modeControllerProvider);
    final activeTrip = ref.watch(activeTripProvider).asData?.value;
    final mode = _bottomNavMode(modeState, activeTrip);
    final modeButtonEnabled =
        modeState.modeControlType == ModeControlType.manual;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(location);
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: TrailBottomNav(
          location: location,
          mode: mode,
          effectiveMode: modeState.effectiveMode,
          modeButtonEnabled: modeButtonEnabled,
          onModePressed: () {
            if (!modeButtonEnabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Auto Mode is active. Change to Manual Mode in Settings to switch manually.',
                  ),
                ),
              );
              return;
            }
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              builder: (_) => const ModeBottomSheet(),
            );
          },
        ),
      ),
    );
  }

  void _handleBack(String location) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    if (location.startsWith('/settings/') && location != '/settings') {
      context.go('/settings');
      return;
    }
    const rootTabs = {
      '/home',
      '/chat',
      '/map',
      '/sos',
      '/nearby-peers',
      '/offline-channel',
    };
    if (!rootTabs.contains(location)) {
      context.go('/home');
      return;
    }
    final now = DateTime.now();
    final shouldExit = _lastRootBackAt != null &&
        now.difference(_lastRootBackAt!) < const Duration(seconds: 2);
    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }
    _lastRootBackAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Press back again to exit')),
    );
  }
}

UserMode _bottomNavMode(ModeState modeState, TripSessionModel? activeTrip) {
  if (activeTrip?.mode == 'offline') return UserMode.offline;
  if (activeTrip?.mode == 'online') return UserMode.online;
  if (activeTrip?.mode == 'hybrid') {
    return modeState.effectiveMode == EffectiveMode.online
        ? UserMode.online
        : UserMode.offline;
  }
  return modeState.userMode;
}
