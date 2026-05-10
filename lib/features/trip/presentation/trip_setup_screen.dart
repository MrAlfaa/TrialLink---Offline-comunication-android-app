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
import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../../trip_context/data/trip_context_service.dart';
import '../data/trip_session_repository.dart';
import '../data/trip_session_service.dart';

enum TripSetupFlow { onboarding, postSetup }

enum _TripSetupAction { createOffline, joinOffline }

class TripSetupScreen extends ConsumerStatefulWidget {
  const TripSetupScreen({
    super.key,
    this.flow = TripSetupFlow.onboarding,
  });

  final TripSetupFlow flow;

  @override
  ConsumerState<TripSetupScreen> createState() => _TripSetupScreenState();
}

class _TripSetupScreenState extends ConsumerState<TripSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tripNameController = TextEditingController();
  final _channelCodeController = TextEditingController();

  _TripSetupAction? _action;
  bool _submitting = false;

  @override
  void dispose() {
    _tripNameController.dispose();
    _channelCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(authAccessControllerProvider);
    final groups = access.accessState.canUseBackendFeatures
        ? ref.watch(myGroupsProvider)
        : const AsyncData(<GroupModel>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.flow == TripSetupFlow.postSetup
              ? 'Create Trip'
              : 'Set up your trip',
        ),
      ),
      body: SafeArea(
        child: _action == null
            ? _buildActionList(context, access, groups)
            : _buildInlineOfflineForm(context),
      ),
    );
  }

  Widget _buildActionList(
    BuildContext context,
    AuthAccessStatus access,
    AsyncValue<List<GroupModel>> groups,
  ) {
    return ListView(
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
          onTap: () => _openInlineAction(_TripSetupAction.createOffline),
        ),
        _TripActionCard(
          title: 'Join Offline Trip Code',
          subtitle: 'Use a teammate channel code without backend login.',
          icon: Icons.qr_code_2_rounded,
          color: AppColors.signalOrange,
          onTap: () => _openInlineAction(_TripSetupAction.joinOffline),
        ),
        _TripActionCard(
          title: 'Link Existing Online Group',
          subtitle: access.accessState.canUseBackendFeatures
              ? 'Choose one of your cloud groups.'
              : 'Online group linking requires internet and login.',
          icon: Icons.groups_rounded,
          color: AppColors.skyBlue,
          enabled: access.accessState.canUseBackendFeatures,
          onTap: () => _showOnlineGroupPicker(context, groups),
        ),
        if (widget.flow == TripSetupFlow.onboarding)
          _TripActionCard(
            title: 'Skip for Now',
            subtitle: 'Dashboard will show a no active trip banner.',
            icon: Icons.skip_next_rounded,
            color: AppColors.mutedText,
            onTap: () => _finishWithoutTrip(context),
          ),
      ],
    );
  }

  void _openInlineAction(_TripSetupAction action) {
    _formKey.currentState?.reset();
    _tripNameController.clear();
    _channelCodeController.clear();
    setState(() => _action = action);
  }

  Widget _buildInlineOfflineForm(BuildContext context) {
    final joining = _action == _TripSetupAction.joinOffline;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            joining ? 'Join Offline Trip' : 'Create Offline Trip',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const SettingsInfoBox(
            message:
                'Offline trips are stored locally and do not require backend validation.',
          ),
          const SizedBox(height: 18),
          if (joining) ...[
            TextFormField(
              controller: _channelCodeController,
              decoration: const InputDecoration(labelText: 'Channel code'),
              textCapitalization: TextCapitalization.characters,
              validator: _validateChannelCode,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tripNameController,
              decoration: const InputDecoration(
                labelText: 'Trip name optional',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                return _validateTripName(value);
              },
            ),
          ] else ...[
            TextFormField(
              controller: _tripNameController,
              decoration: const InputDecoration(labelText: 'Trip name'),
              validator: _validateTripName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _channelCodeController,
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
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _submitting ? null : () => _submitInlineAction(context),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(_submitting
                ? 'Saving...'
                : joining
                    ? 'Join Trip'
                    : 'Save Trip'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed:
                _submitting ? null : () => setState(() => _action = null),
            child: const Text('Back to trip options'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitInlineAction(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final saved = await switch (_action) {
        _TripSetupAction.createOffline => _createOfflineTrip(
            tripName: _tripNameController.text,
            customChannelCode: _channelCodeController.text,
          ),
        _TripSetupAction.joinOffline => _joinOfflineTrip(
            channelCode: _channelCodeController.text,
            tripName: _tripNameController.text,
          ),
        null => Future<bool>.value(false),
      };
      if (saved && context.mounted) {
        await _completeTripStep(context);
      }
    } catch (error) {
      if (context.mounted) _showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showOnlineGroupPicker(
    BuildContext context,
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
                    final saved = await _createOnlineTrip(sheetContext, group);
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
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await _completeTripStep(context);
    }
  }

  Future<bool> _createOfflineTrip({
    required String tripName,
    required String customChannelCode,
  }) async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    if (identity == null) {
      throw StateError('Create an offline identity before setting up a trip.');
    }
    await ref.read(tripSessionRepositoryProvider).createOfflineTrip(
          tripName: tripName,
          identity: identity,
          customChannelCode:
              customChannelCode.trim().isEmpty ? null : customChannelCode,
        );
    return true;
  }

  Future<bool> _joinOfflineTrip({
    required String channelCode,
    required String tripName,
  }) async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    if (identity == null) {
      throw StateError('Create an offline identity before joining a trip.');
    }
    await ref.read(tripContextServiceProvider).joinOfflineChannelAsActiveTrip(
          channelCode,
          tripName: tripName.trim().isEmpty ? null : tripName,
        );
    return true;
  }

  Future<bool> _createOnlineTrip(
    BuildContext context,
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

  Future<void> _finishWithoutTrip(BuildContext context) async {
    await _completeTripStep(context);
  }

  Future<void> _completeTripStep(BuildContext context) async {
    if (widget.flow == TripSetupFlow.onboarding) {
      await ref.read(setupProgressServiceProvider).markTripConfigured();
    }
    await ref.read(authAccessControllerProvider.notifier).refreshFromIdentity();
    ref.invalidate(activeTripContextProvider);
    ref.invalidate(activeOfflineChannelProvider);
    ref.invalidate(activeUsableOfflineChannelProvider);
    ref.invalidate(activeTripChannelProvider);
    ref.invalidate(activeTripProvider);
    if (!context.mounted) return;
    final router = GoRouter.of(context);
    final destination =
        widget.flow == TripSetupFlow.postSetup ? '/home' : '/setup/permissions';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go(destination);
    });
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
