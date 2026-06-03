import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/identity/auth_access_controller.dart';
import '../../core/identity/local_identity_repository.dart';
import '../cloud_identity/data/cloud_sync_controller.dart';
import '../cloud_identity/presentation/local_identity_card.dart';
import '../../shared/widgets/settings_info_box.dart';

class LinkOfflineDataScreen extends ConsumerWidget {
  const LinkOfflineDataScreen({super.key});

  Future<void> _createCloudProfile(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(cloudSyncControllerProvider.notifier)
        .ensureCloudReadyBeforeOnlineMode();
    if (!result.success) return;

    var online = await ref
        .read(authAccessControllerProvider.notifier)
        .refreshFromBackendSession(clearOnFailure: true);
    if (!online) {
      final retry = await ref
          .read(cloudSyncControllerProvider.notifier)
          .retryCloudBootstrap();
      if (!retry.success) return;
      online = await ref
          .read(authAccessControllerProvider.notifier)
          .refreshFromBackendSession(clearOnFailure: true);
    }
    if (!context.mounted || !online) return;

    final from = GoRouterState.of(context).uri.queryParameters['from'];
    context.go(_safeReturnPath(from));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Profile')),
      body: SafeArea(
        child: FutureBuilder(
          future:
              ref.read(localIdentityRepositoryProvider).getCurrentIdentity(),
          builder: (context, snapshot) {
            final identity = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SettingsInfoBox(
                  message:
                      'Create a TrailLink cloud profile when internet is available. Your local profile and offline features remain available if cloud setup fails.',
                  icon: Icons.cloud_sync_rounded,
                  color: AppColors.skyBlue,
                ),
                const SizedBox(height: 18),
                if (identity != null)
                  LocalIdentityCard(
                    identity: identity,
                    onCreateCloudProfile: () =>
                        _createCloudProfile(context, ref),
                  )
                else
                  const SettingsInfoBox(
                    message:
                        'No local TrailLink profile found. Create your profile before setting up cloud sync.',
                    icon: Icons.person_off_rounded,
                    color: AppColors.danger,
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: identity == null
                      ? null
                      : () => _createCloudProfile(context, ref),
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Create Cloud Profile Now'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/offline-channel'),
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('Continue Offline Chat'),
                ),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Stay Local Only'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _safeReturnPath(String? from) {
    if (from == null || from.isEmpty) return '/groups/create';
    final decoded = Uri.decodeComponent(from);
    if (!decoded.startsWith('/') || decoded.startsWith('//')) {
      return '/groups/create';
    }
    if (decoded == '/account/link-offline-data') {
      return '/groups/create';
    }
    return decoded;
  }
}
