import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/mode/mode_controller.dart';
import '../../setup/data/setup_cloud_failure_recovery_service.dart';
import '../data/cloud_sync_controller.dart';
import '../data/cloud_identity_status_model.dart';

class CloudAccountProgressOverlay extends ConsumerWidget {
  const CloudAccountProgressOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudSyncControllerProvider);
    return Stack(
      children: [
        child,
        if (state.isActive)
          Positioned.fill(
            child: state.isBlocking
                ? _BlockingCloudOverlay(state: state)
                : _TopCloudBanner(state: state),
          ),
      ],
    );
  }
}

class _BlockingCloudOverlay extends ConsumerWidget {
  const _BlockingCloudOverlay({required this.state});

  final CloudSyncState state;

  Future<void> _continueOffline(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await ref
        .read(setupCloudFailureRecoveryServiceProvider)
        .continueOfflineAfterCloudFailure();
    await ref.read(modeControllerProvider.notifier).loadModeSettings();
    await ref.read(authAccessControllerProvider.notifier).refreshFromIdentity();
    ref.read(cloudSyncControllerProvider.notifier).clear();
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.deepForest.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          state.errorMessage == null
                              ? Icons.cloud_sync_rounded
                              : Icons.cloud_off_rounded,
                          color: state.errorMessage == null
                              ? AppColors.deepForest
                              : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage == null
                              ? 'Preparing cloud profile'
                              : state.emailConflict
                                  ? 'Email already linked'
                                  : 'Cloud setup unavailable',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.errorMessage == null) ...[
                    Text(
                      state.currentStep,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: state.progressPercent.clamp(0, 100) / 100,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Progress: ${state.progressPercent.clamp(0, 100)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      'Your local TrailLink profile is saved. You can continue in Offline Mode and connect your cloud profile later.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Details: ${state.errorMessage!}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _continueOffline(context, ref),
                            child: const Text('Continue Offline'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => ref
                                .read(cloudSyncControllerProvider.notifier)
                                .retryCloudBootstrap(),
                            child: Text(
                              state.emailConflict
                                  ? 'Try another email'
                                  : 'Retry Cloud Setup',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopCloudBanner extends ConsumerWidget {
  const _TopCloudBanner({required this.state});

  final CloudSyncState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.deepForest.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.successMessage == null
                          ? Icons.sync_rounded
                          : Icons.verified_rounded,
                      color: AppColors.deepForest,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.publicUserId == null
                            ? state.currentStep
                            : '${state.currentStep} - ${state.publicUserId}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(cloudSyncControllerProvider.notifier)
                          .clear(),
                      child: const Text('Continue'),
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
