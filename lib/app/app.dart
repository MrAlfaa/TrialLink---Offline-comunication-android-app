import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/database/local_database.dart';
import '../core/connectivity/connection_mode_provider.dart';
import '../core/mode/mode_controller.dart';
import '../core/offline/offline_packet_router.dart';
import '../features/app_lock/presentation/app_lock_controller.dart';
import '../features/cloud_identity/presentation/cloud_account_progress_overlay.dart';
import 'router.dart';
import 'theme.dart';

class TrailLinkApp extends ConsumerStatefulWidget {
  const TrailLinkApp({super.key});

  @override
  ConsumerState<TrailLinkApp> createState() => _TrailLinkAppState();
}

class _TrailLinkAppState extends ConsumerState<TrailLinkApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocalDatabase.instance.initialize();
      await LocalDatabase.instance.ensureSession();
      if (!mounted) return;
      await ref.read(appLockControllerProvider.notifier).initialize();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(appLockControllerProvider.notifier).handleAppBackgrounded();
      return;
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(appLockControllerProvider.notifier).handleAppResumed().then((_) {
        if (!mounted) return;
        final lockState = ref.read(appLockControllerProvider);
        if (lockState.appLockEnabled && lockState.isLocked) {
          ref.read(appRouterProvider).go('/unlock');
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLockControllerProvider);
    return MaterialApp.router(
      title: 'TrailLink',
      debugShowCheckedModeBanner: false,
      theme: buildTrailLinkTheme(),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => CloudAccountProgressOverlay(
        child: _RuntimeServiceStarter(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _RuntimeServiceStarter extends ConsumerStatefulWidget {
  const _RuntimeServiceStarter({required this.child});

  final Widget child;

  @override
  ConsumerState<_RuntimeServiceStarter> createState() =>
      _RuntimeServiceStarterState();
}

class _RuntimeServiceStarterState
    extends ConsumerState<_RuntimeServiceStarter> {
  bool _listenForPackets = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(connectionModeProvider);
      ref.read(modeControllerProvider);
      ref.read(offlinePacketRouterProvider);
      setState(() => _listenForPackets = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_listenForPackets) return widget.child;
    return _PacketNoticeListener(child: widget.child);
  }
}

class _PacketNoticeListener extends ConsumerWidget {
  const _PacketNoticeListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(offlinePacketRouterProvider, (previous, next) {
      final alert = next.lastEmergencyAlert;
      if (alert == null || identical(alert, previous?.lastEmergencyAlert)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.vibrate();
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'Emergency alert',
          barrierColor: Colors.black.withValues(alpha: 0.78),
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (dialogContext, animation, secondaryAnimation) {
            return _IncomingSosDialog(
              alert: alert,
              onAcknowledge: () async {
                await ref
                    .read(offlinePacketRouterProvider.notifier)
                    .acknowledgeLatestSos();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
              },
              onTrack: () {
                final event = alert.event;
                if (event.latitude == null || event.longitude == null) return;
                Navigator.of(dialogContext, rootNavigator: true).pop();
                ref.read(appRouterProvider).go(
                  '/map',
                  extra: {
                    'latitude': event.latitude,
                    'longitude': event.longitude,
                    'title': 'SOS from ${alert.senderName}',
                    'subtitle': event.message ?? 'Emergency alert',
                    'isEmergency': true,
                  },
                );
                ref
                    .read(offlinePacketRouterProvider.notifier)
                    .clearEmergencyNotice();
              },
              onDismiss: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                ref
                    .read(offlinePacketRouterProvider.notifier)
                    .clearEmergencyNotice();
              },
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
        );
      });
    });
    return child;
  }
}

class _IncomingSosDialog extends StatelessWidget {
  const _IncomingSosDialog({
    required this.alert,
    required this.onAcknowledge,
    required this.onTrack,
    required this.onDismiss,
  });

  final ReceivedSosAlert alert;
  final Future<void> Function() onAcknowledge;
  final VoidCallback onTrack;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final event = alert.event;
    final hasLocation = event.latitude != null && event.longitude != null;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.danger, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.28),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.danger.withValues(alpha: 0.32),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emergency_share_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'SOS ALERT RECEIVED',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      alert.senderName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.message?.isNotEmpty == true
                          ? event.message!
                          : 'Need help',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    _SosDetailRow(
                      icon: Icons.hub_rounded,
                      label: 'Channel',
                      value: alert.channelCode,
                    ),
                    _SosDetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Received',
                      value:
                          DateFormat.yMMMd().add_jm().format(alert.receivedAt),
                    ),
                    if (hasLocation)
                      _SosDetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value:
                            '${event.latitude!.toStringAsFixed(6)}, ${event.longitude!.toStringAsFixed(6)}',
                      )
                    else
                      const _SosDetailRow(
                        icon: Icons.location_off_rounded,
                        label: 'Location',
                        value: 'No location attached',
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: onAcknowledge,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Acknowledge'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: hasLocation ? onTrack : null,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Track on Map'),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: onDismiss,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Dismiss Locally'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SosDetailRow extends StatelessWidget {
  const _SosDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
