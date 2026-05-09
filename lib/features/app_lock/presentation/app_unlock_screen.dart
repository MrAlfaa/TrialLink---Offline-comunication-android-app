import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../data/models/app_lock_status.dart';
import 'app_lock_controller.dart';
import 'widgets/app_lock_header.dart';
import 'widgets/quick_sos_locked_card.dart';
import 'widgets/unlock_method_button.dart';

class AppUnlockScreen extends ConsumerWidget {
  const AppUnlockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(appLockControllerProvider);
    final from = GoRouterState.of(context).uri.queryParameters['from'] ??
        lockState.intendedRoute ??
        '/home';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 26),
            const AppLockHeader(
              title: 'TrailLink',
              subtitle: 'Secure outdoor communication',
            ),
            const SizedBox(height: 26),
            Text(
              'Your trip data is protected.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 22),
            if (lockState.status == AppLockStatus.setupRequired) ...[
              const _LockMessage(
                message:
                    'App Lock is enabled but setup is not complete. Configure a TrailLink PIN to continue.',
                color: AppColors.warning,
              ),
              const SizedBox(height: 14),
              UnlockMethodButton(
                icon: Icons.lock_reset_rounded,
                label: 'Configure App Lock',
                filled: true,
                onPressed: () => context.go('/settings/app-lock/setup'),
              ),
            ] else ...[
              if (lockState.biometricEnabled) ...[
                UnlockMethodButton(
                  icon: Icons.fingerprint_rounded,
                  label: lockState.biometricAvailable
                      ? 'Unlock with Fingerprint / Device PIN'
                      : 'Biometric unlock unavailable on this device',
                  filled: true,
                  onPressed: lockState.biometricAvailable
                      ? () async {
                          final ok = await ref
                              .read(appLockControllerProvider.notifier)
                              .unlockWithBiometric();
                          if (ok && context.mounted) {
                            context.go(_safeReturnRoute(from));
                          }
                        }
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              if (lockState.trailPinEnabled) ...[
                UnlockMethodButton(
                  icon: Icons.pin_rounded,
                  label: 'Use TrailLink PIN',
                  onPressed: () => context.go(
                    '/app-lock/pin?from=${Uri.encodeComponent(from)}',
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (lockState.message != null) ...[
              const SizedBox(height: 8),
              _LockMessage(message: lockState.message!),
            ],
            const SizedBox(height: 22),
            QuickSosLockedCard(
              enabled: lockState.quickSosEnabled,
              onPressed: () => context.go('/locked/sos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockMessage extends StatelessWidget {
  const _LockMessage({
    required this.message,
    this.color = AppColors.warning,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _safeReturnRoute(String route) {
  if (route.isEmpty ||
      route == '/unlock' ||
      route.startsWith('/unlock?') ||
      route == '/app-lock/pin' ||
      route.startsWith('/app-lock/pin') ||
      route == '/locked/sos') {
    return '/home';
  }
  return route;
}
