import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/auth_access_state.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/setup/setup_progress_service.dart';
import '../../../shared/widgets/settings_info_box.dart';
import '../../groups/data/models/group_model.dart';
import '../../groups/presentation/group_controller.dart';
import '../data/trip_session_repository.dart';
import '../data/trip_session_service.dart';

enum TripSetupFlow { onboarding, postSetup }

class TripSetupScreen extends ConsumerWidget {
  const TripSetupScreen({
    super.key,
    this.flow = TripSetupFlow.onboarding,
  });

  final TripSetupFlow flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(authAccessControllerProvider);
    final groups = access.accessState.canUseBackendFeatures
        ? ref.watch(myGroupsProvider)
        : const AsyncData(<GroupModel>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          flow == TripSetupFlow.postSetup ? 'Create Trip' : 'Set up your trip',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'TrailLink works best when communication tools are connected to a trip session.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            _TripActionCard(
              title: 'Create Offline Trip',
              subtitle: 'Create a local trip and offline channel code.',
              icon: Icons.add_road_rounded,
              color: AppColors.offlinePurple,
              onTap: () => _showCreateOfflineTrip(context, ref),
            ),
            _TripActionCard(
              title: 'Join Offline Trip Code',
              subtitle: 'Use a teammate channel code without backend login.',
              icon: Icons.qr_code_2_rounded,
              color: AppColors.signalOrange,
              onTap: () => _showJoinOfflineTrip(context, ref),
            ),
            _TripActionCard(
              title: 'Link Existing Online Group',
              subtitle: access.accessState.canUseBackendFeatures
                  ? 'Choose one of your cloud groups.'
                  : 'Online group linking requires internet and login.',
              icon: Icons.groups_rounded,
              color: AppColors.skyBlue,
              enabled: access.accessState.canUseBackendFeatures,
              onTap: () => _showOnlineGroupPicker(context, ref, groups),
            ),
            if (flow == TripSetupFlow.onboarding)
              _TripActionCard(
                title: 'Skip for Now',
                subtitle: 'Dashboard will show a no active trip banner.',
                icon: Icons.skip_next_rounded,
                color: AppColors.mutedText,
                onTap: () => _finishWithoutTrip(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateOfflineTrip(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    final tripName = TextEditingController();
    final channelCode = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _TripFormSheet(
          title: 'Create Offline Trip',
          formKey: formKey,
          children: [
            TextFormField(
              controller: tripName,
              decoration: const InputDecoration(labelText: 'Trip name'),
              validator: _validateTripName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: channelCode,
              decoration: const InputDecoration(
                labelText: 'Custom channel code optional',
                helperText: 'Example: TL-OFF-8K2P',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                return _validateChannelCode(value);
              },
            ),
          ],
          onSubmit: () async {
            if (!formKey.currentState!.validate()) return;
            final saved = await _createOfflineTrip(
              sheetContext,
              ref,
              tripName: tripName.text,
              customChannelCode: channelCode.text,
            );
            if (saved && sheetContext.mounted) {
              Navigator.of(sheetContext).pop(true);
            }
          },
        );
      },
    );
    tripName.dispose();
    channelCode.dispose();
    if (created == true && context.mounted) {
      await _completeTripStep(context, ref);
    }
  }

  Future<void> _showJoinOfflineTrip(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    final tripName = TextEditingController();
    final channelCode = TextEditingController();
    final joined = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return _TripFormSheet(
          title: 'Join Offline Trip',
          formKey: formKey,
          children: [
            TextFormField(
              controller: channelCode,
              decoration: const InputDecoration(labelText: 'Channel code'),
              textCapitalization: TextCapitalization.characters,
              validator: _validateChannelCode,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: tripName,
              decoration: const InputDecoration(
                labelText: 'Trip name optional',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                return _validateTripName(value);
              },
            ),
          ],
          onSubmit: () async {
            if (!formKey.currentState!.validate()) return;
            final saved = await _joinOfflineTrip(
              sheetContext,
              ref,
              channelCode: channelCode.text,
              tripName: tripName.text,
            );
            if (saved && sheetContext.mounted) {
              Navigator.of(sheetContext).pop(true);
            }
          },
        );
      },
    );
    tripName.dispose();
    channelCode.dispose();
    if (joined == true && context.mounted) {
      await _completeTripStep(context, ref);
    }
  }

  Future<void> _showOnlineGroupPicker(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<GroupModel>> groupsValue,
  ) async {
    final groups = groupsValue.asData?.value ?? const <GroupModel>[];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No online groups found yet.')),
      );
      return;
    }
    final linked = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            shrinkWrap: true,
            children: [
              Text(
                'Select Online Group',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              for (final group in groups)
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: Text(group.groupName),
                  subtitle: Text(group.groupCode),
                  onTap: () async {
                    final saved =
                        await _createOnlineTrip(sheetContext, ref, group);
                    if (saved && sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(true);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
    if (linked == true && context.mounted) {
      await _completeTripStep(context, ref);
    }
  }

  Future<bool> _createOfflineTrip(
    BuildContext context,
    WidgetRef ref, {
    required String tripName,
    required String customChannelCode,
  }) async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    if (!context.mounted) return false;
    if (identity == null) {
      _showError(
          context, 'Create an offline identity before setting up a trip.');
      return false;
    }
    try {
      await ref.read(tripSessionRepositoryProvider).createOfflineTrip(
            tripName: tripName,
            identity: identity,
            customChannelCode:
                customChannelCode.trim().isEmpty ? null : customChannelCode,
          );
      return true;
    } catch (error) {
      if (context.mounted) _showError(context, error.toString());
      return false;
    }
  }

  Future<bool> _joinOfflineTrip(
    BuildContext context,
    WidgetRef ref, {
    required String channelCode,
    required String tripName,
  }) async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    if (!context.mounted) return false;
    if (identity == null) {
      _showError(context, 'Create an offline identity before joining a trip.');
      return false;
    }
    try {
      await ref.read(tripSessionRepositoryProvider).joinOfflineTrip(
            channelCode: channelCode,
            identity: identity,
            tripName: tripName.trim().isEmpty ? null : tripName,
          );
      return true;
    } catch (error) {
      if (context.mounted) _showError(context, error.toString());
      return false;
    }
  }

  Future<bool> _createOnlineTrip(
    BuildContext context,
    WidgetRef ref,
    GroupModel group,
  ) async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    if (!context.mounted) return false;
    if (identity == null) {
      _showError(context, 'Local identity is required before linking a group.');
      return false;
    }
    await ref.read(tripSessionRepositoryProvider).createOnlineTripFromGroup(
          group: group,
          localIdentityId: identity.localUserId,
        );
    return true;
  }

  Future<void> _finishWithoutTrip(BuildContext context, WidgetRef ref) async {
    await _completeTripStep(context, ref);
  }

  Future<void> _completeTripStep(BuildContext context, WidgetRef ref) async {
    if (flow == TripSetupFlow.onboarding) {
      await ref.read(setupProgressServiceProvider).markTripConfigured();
    }
    ref.invalidate(activeTripProvider);
    if (!context.mounted) return;
    context.go(
      flow == TripSetupFlow.postSetup ? '/home' : '/setup/permissions',
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TripActionCard extends StatelessWidget {
  const _TripActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: enabled ? color : AppColors.disabledGrey),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (!enabled)
                  const Icon(Icons.lock_outline_rounded,
                      color: AppColors.mutedText)
                else
                  const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripFormSheet extends StatelessWidget {
  const _TripFormSheet({
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSubmit,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              const SettingsInfoBox(
                message:
                    'Offline trips are stored locally and do not require backend validation.',
              ),
              const SizedBox(height: 14),
              ...children,
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => onSubmit(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Trip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _validateTripName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.length < 3 || trimmed.length > 60) {
    return 'Trip name must be 3-60 characters.';
  }
  return null;
}

String? _validateChannelCode(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(code)) {
    return 'Use 4-20 uppercase letters, numbers, or hyphens.';
  }
  return null;
}
