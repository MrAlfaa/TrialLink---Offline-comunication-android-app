import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/local_identity_model.dart';
import '../../../core/identity/local_identity_repository.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../core/settings/app_settings_defaults.dart';
import '../../../core/settings/feature_flag_service.dart';
import '../../../core/settings/settings_service.dart';
import '../../app_lock/data/app_lock_repository.dart';
import '../../app_lock/presentation/app_lock_controller.dart';
import '../../cloud_identity/data/cloud_sync_controller.dart';
import '../../../shared/widgets/settings_dropdown_tile.dart';
import '../../../shared/widgets/settings_info_box.dart';
import '../../../shared/widgets/settings_section_card.dart';
import '../../../shared/widgets/settings_toggle_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communicationItems = const [
      _SettingsItem(
        title: 'Communication Mode',
        subtitle: 'Auto, Online, and Offline preferences',
        icon: Icons.sync_alt_rounded,
        color: AppColors.skyBlue,
        route: '/settings/mode',
      ),
      _SettingsItem(
        title: 'Feature Controls',
        subtitle: 'Turn online and offline tools on or off',
        icon: Icons.tune_rounded,
        color: AppColors.deepForest,
        route: '/settings/features',
      ),
    ];
    final safetyItems = const [
      _SettingsItem(
        title: 'Safety & Emergency',
        subtitle: 'SOS, location sharing, and alert behavior',
        icon: Icons.health_and_safety_rounded,
        color: AppColors.danger,
        route: '/settings/safety',
      ),
      _SettingsItem(
        title: 'App Lock & Privacy',
        subtitle: 'Fingerprint, PIN, and data protection foundations',
        icon: Icons.lock_rounded,
        color: AppColors.offlinePurple,
        route: '/settings/app-lock',
      ),
      _SettingsItem(
        title: 'Agreement & Privacy',
        subtitle: 'Review safety and privacy agreement choices',
        icon: Icons.verified_user_rounded,
        color: AppColors.skyBlue,
        route: '/settings/agreement',
      ),
    ];
    final advancedItems = const [
      _SettingsItem(
        title: 'Voice & Walkie-Talkie',
        subtitle: 'Voice-note PTT, Live Radio, and speaker limits',
        icon: Icons.record_voice_over_rounded,
        color: AppColors.signalOrange,
        route: '/settings/voice',
      ),
      _SettingsItem(
        title: 'Data & Sync',
        subtitle: 'Automatic sync preferences',
        icon: Icons.cloud_sync_rounded,
        color: AppColors.success,
        route: '/settings/data-sync',
      ),
      _SettingsItem(
        title: 'Bridge Mode',
        subtitle: 'Forward nearby offline data through an online teammate',
        icon: Icons.cable_rounded,
        color: AppColors.offlinePurple,
        route: '/settings/bridge',
      ),
    ];
    final identity = ref.watch(authAccessControllerProvider).identity;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Manage your profile, communication, safety, and sync preferences.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            _ProfileSummaryCard(identity: identity),
            const SizedBox(height: 18),
            const _SettingsSectionHeading('Communication'),
            ...communicationItems.map((item) => _SettingsCard(item: item)),
            const SizedBox(height: 8),
            const _SettingsSectionHeading('Safety & Privacy'),
            ...safetyItems.map((item) => _SettingsCard(item: item)),
            const SizedBox(height: 8),
            const _SettingsSectionHeading('Voice & Advanced'),
            ...advancedItems.map((item) => _SettingsCard(item: item)),
          ],
        ),
      ),
    );
  }
}

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  LocalIdentityModel? _identity;
  bool _loading = true;
  bool _saving = false;
  bool _creatingCloud = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final identity =
        await ref.read(localIdentityRepositoryProvider).getCurrentIdentity();
    if (!mounted) return;
    _identity = identity;
    _nameController.text = identity?.displayName ?? '';
    _emailController.text = identity?.email ?? '';
    _phoneController.text = identity?.phoneNumber ?? '';
    _noteController.text = identity?.emergencyNote ?? '';
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    return _SettingsScaffold(
      title: 'Profile',
      loading: _loading,
      children: [
        if (identity == null)
          const SettingsInfoBox(
            message:
                'No local TrailLink profile was found. Complete setup to create your offline profile.',
            icon: Icons.person_off_rounded,
            color: AppColors.warning,
          )
        else ...[
          SettingsSectionCard(
            title: 'TrailLink Identity',
            subtitle:
                'Your TrailLink ID is created by the cloud and cannot be changed here.',
            icon: Icons.badge_rounded,
            children: [
              _ReadOnlyProfileRow(
                label: 'TrailLink ID',
                value: identity.publicUserId?.isNotEmpty == true
                    ? identity.publicUserId!
                    : 'Not created yet',
                copyValue: identity.publicUserId,
              ),
              _ReadOnlyProfileRow(
                label: 'Local ID',
                value: identity.localUserId,
              ),
              _ReadOnlyProfileRow(
                label: 'Cloud ID',
                value: identity.cloudUserId?.isNotEmpty == true
                    ? identity.cloudUserId!
                    : 'Not linked yet',
              ),
              _ReadOnlyProfileRow(
                label: 'Cloud status',
                value: _humanizeStatus(identity.cloudStatus),
              ),
              if (!identity.isCloudReady) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _creatingCloud ? null : _createCloudProfile,
                  icon: _creatingCloud
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_sync_rounded),
                  label: Text(
                    _creatingCloud
                        ? 'Creating...'
                        : identity.cloudStatus == 'sync_failed'
                            ? 'Retry Cloud Profile'
                            : 'Create Cloud Profile',
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: SettingsSectionCard(
              title: 'Profile Details',
              subtitle:
                  'These details are saved locally first and synced later when cloud sync is ready.',
              icon: Icons.person_rounded,
              children: [
                _ProfileTextField(
                  controller: _nameController,
                  label: 'Display name',
                  isRequired: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _validateProfileField(
                    displayName: value ?? '',
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) => _validateProfileField(
                    displayName: 'Valid Name',
                    email: value,
                  ),
                ),
                const SizedBox(height: 12),
                _ProfileTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _ProfileTextField(
                  controller: _noteController,
                  label: 'Emergency note',
                  maxLines: 3,
                  validator: (value) => _validateProfileField(
                    displayName: 'Valid Name',
                    emergencyNote: value,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_saving ? 'Saving...' : 'Save Profile'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String? _validateProfileField({
    required String displayName,
    String? email,
    String? emergencyNote,
  }) {
    try {
      LocalIdentityRepository.validateProfileInput(
        displayName: displayName,
        email: email,
        emergencyNote: emergencyNote,
      );
      return null;
    } on StateError catch (error) {
      return error.message;
    }
  }

  Future<void> _save() async {
    final identity = _identity;
    if (identity == null || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final email = _blankToNull(_emailController.text);
      final phone = _blankToNull(_phoneController.text);
      final note = _blankToNull(_noteController.text);
      final updated = identity.copyWith(
        displayName: _nameController.text.trim(),
        email: email,
        clearEmail: email == null,
        phoneNumber: phone,
        clearPhoneNumber: phone == null,
        emergencyNote: note,
        clearEmergencyNote: note == null,
        syncState: identity.isCloudReady ? 'needs_sync' : identity.syncState,
      );
      await ref.read(localIdentityRepositoryProvider).updateIdentity(updated);
      await ref
          .read(authAccessControllerProvider.notifier)
          .refreshFromIdentity();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved locally.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createCloudProfile() async {
    final identity = _identity;
    if (identity == null || _creatingCloud) return;
    setState(() => _creatingCloud = true);
    try {
      final result = await ref
          .read(cloudSyncControllerProvider.notifier)
          .ensureCloudReadyBeforeOnlineMode();
      await ref
          .read(authAccessControllerProvider.notifier)
          .refreshFromIdentity();
      await _load();
      if (!mounted) return;
      final message = result.success
          ? 'TrailLink ID ready: ${result.publicUserId ?? 'Cloud profile'}'
          : result.errorMessage ??
              'Cloud profile could not be created. Check backend connection and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cloud profile could not be created. Check backend connection and try again. $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creatingCloud = false);
    }
  }
}

class ModeSettingsScreen extends ConsumerStatefulWidget {
  const ModeSettingsScreen({super.key});

  @override
  ConsumerState<ModeSettingsScreen> createState() => _ModeSettingsScreenState();
}

class _ModeSettingsScreenState extends ConsumerState<ModeSettingsScreen> {
  ModeControlType _controlType = ModeControlType.auto;
  ManualCommunicationMode _manualMode = ManualCommunicationMode.offline;
  bool _autoSwitch = true;
  bool _askBeforeSwitch = false;
  bool _showExplanations = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    final controlName = await settings.getString(
        'mode_control_type', ModeControlType.auto.name);
    _controlType = ModeControlType.values.firstWhere(
      (mode) => mode.name == controlName,
      orElse: () => ModeControlType.auto,
    );
    final manualName = await settings.getString(
      'manual_communication_mode',
      ManualCommunicationMode.offline.name,
    );
    _manualMode = ManualCommunicationMode.values.firstWhere(
      (mode) => mode.name == manualName,
      orElse: () => ManualCommunicationMode.offline,
    );
    _autoSwitch = await settings.getBool('auto_switch_enabled', true);
    _askBeforeSwitch = await settings.getBool('ask_before_auto_switch', false);
    _showExplanations = await settings.getBool('show_mode_explanations', true);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Mode Settings',
      loading: _loading,
      children: [
        SettingsSectionCard(
          title: 'Mode Control',
          subtitle:
              'Choose automatic switching or a manual communication path.',
          icon: Icons.sync_rounded,
          children: [
            SettingsDropdownTile<ModeControlType>(
              title: 'Mode Control',
              value: _controlType,
              items: {
                ModeControlType.auto: ModeControlType.auto.label,
                ModeControlType.manual: ModeControlType.manual.label,
              },
              onChanged: (mode) async {
                setState(() => _controlType = mode);
                await ref.read(settingsServiceProvider).setString(
                      'mode_control_type',
                      mode.name,
                    );
                await ref
                    .read(modeControllerProvider.notifier)
                    .setModeControlType(mode);
              },
            ),
            if (_controlType == ModeControlType.manual)
              SettingsDropdownTile<ManualCommunicationMode>(
                title: 'Default Manual State',
                value: _manualMode,
                items: const {
                  ManualCommunicationMode.online: 'Online',
                  ManualCommunicationMode.offline: 'Offline',
                },
                onChanged: (mode) async {
                  setState(() => _manualMode = mode);
                  await ref.read(settingsServiceProvider).setString(
                        'manual_communication_mode',
                        mode.name,
                      );
                  await ref
                      .read(modeControllerProvider.notifier)
                      .setManualCommunicationMode(mode);
                },
              ),
            SettingsToggleTile(
              title: 'Auto-switch in Auto Mode',
              value: _autoSwitch,
              enabled: _controlType == ModeControlType.auto,
              onChanged: (value) => _setBool(
                  'auto_switch_enabled', value, (next) => _autoSwitch = next),
            ),
            SettingsToggleTile(
              title: 'Ask before automatic mode switch',
              value: _askBeforeSwitch,
              onChanged: (value) => _setBool('ask_before_auto_switch', value,
                  (next) => _askBeforeSwitch = next),
            ),
            SettingsToggleTile(
              title: 'Show mode explanations',
              value: _showExplanations,
              onChanged: (value) => _setBool('show_mode_explanations', value,
                  (next) => _showExplanations = next),
            ),
            const SettingsInfoBox(
              message:
                  'Manual Offline will not switch back to Online automatically. Choose Auto for automatic switching.',
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setBool(
    String key,
    bool value,
    void Function(bool value) assign,
  ) async {
    setState(() => assign(value));
    await ref.read(settingsServiceProvider).setBool(key, value);
  }
}

class FeatureControlsSettingsScreen extends ConsumerStatefulWidget {
  const FeatureControlsSettingsScreen({super.key});

  @override
  ConsumerState<FeatureControlsSettingsScreen> createState() =>
      _FeatureControlsSettingsScreenState();
}

class _FeatureControlsSettingsScreenState
    extends ConsumerState<FeatureControlsSettingsScreen> {
  final _values = <String, bool>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    for (final item in _featureItems) {
      _values[item.key] = await settings.getBool(item.key, true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Feature Controls',
      loading: _loading,
      children: [
        SettingsSectionCard(
          title: 'Online Features',
          icon: Icons.cloud_done_rounded,
          children: _featureItems
              .where((item) => item.group == 'online')
              .map(_toggle)
              .toList(),
        ),
        const SizedBox(height: 14),
        SettingsSectionCard(
          title: 'Offline Features',
          icon: Icons.settings_input_antenna_rounded,
          children: _featureItems
              .where((item) => item.group == 'offline')
              .map(_toggle)
              .toList(),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Feature preferences saved.')),
            );
          },
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save Changes'),
        ),
      ],
    );
  }

  Widget _toggle(_FeatureToggle item) {
    return SettingsToggleTile(
      title: item.title,
      subtitle: item.subtitle,
      value: _values[item.key] ?? true,
      onChanged: (value) async {
        if (item.key == 'enable_offline_sos' && !value) {
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Disable Offline SOS?'),
                  content: const Text(
                    'Offline SOS is a safety feature. Are you sure you want to disable it?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep Enabled'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Disable'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!confirmed) return;
        }
        setState(() => _values[item.key] = value);
        await ref.read(settingsServiceProvider).setBool(item.key, value);
        if (item.key == 'enable_offline_sos') {
          await ref
              .read(settingsServiceProvider)
              .setBool('offline_sos_enabled', value);
        }
        if (item.key == 'enable_offline_location_share') {
          await ref
              .read(settingsServiceProvider)
              .setBool('offline_location_share_enabled', value);
        }
        ref.invalidate(featureFlagProvider);
      },
    );
  }
}

class SafetyEmergencySettingsScreen extends ConsumerStatefulWidget {
  const SafetyEmergencySettingsScreen({super.key});

  @override
  ConsumerState<SafetyEmergencySettingsScreen> createState() =>
      _SafetyEmergencySettingsScreenState();
}

class _SafetyEmergencySettingsScreenState
    extends ConsumerState<SafetyEmergencySettingsScreen> {
  final _bools = <String, bool>{};
  int _countdown = 3;
  int _retryInterval = 10;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    for (final key in _safetyBoolKeys) {
      _bools[key] = await settings.getBool(key, true);
    }
    _countdown = await settings.getInt('sos_countdown_seconds', 3);
    _retryInterval = await settings.getInt('sos_retry_interval_seconds', 10);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Safety & Emergency',
      loading: _loading,
      children: [
        SettingsSectionCard(
          title: 'SOS Behavior',
          icon: Icons.emergency_share_rounded,
          children: [
            _boolTile('confirm_before_sos', 'Confirm before sending SOS'),
            SettingsDropdownTile<int>(
              title: 'Countdown seconds',
              value: _countdown,
              items: const {0: 'No countdown', 3: '3 seconds', 5: '5 seconds'},
              onChanged: (value) async {
                setState(() => _countdown = value);
                await ref
                    .read(settingsServiceProvider)
                    .setInt('sos_countdown_seconds', value);
              },
            ),
            _boolTile('attach_location_to_sos', 'Attach location to SOS'),
            if (_bools['attach_location_to_sos'] == false)
              const SettingsInfoBox(
                message: 'SOS alerts will be sent without your location.',
                icon: Icons.location_off_rounded,
                color: AppColors.warning,
              ),
            _boolTile(
              'use_last_known_location_for_sos',
              'Use last-known location if GPS fails',
            ),
            _boolTile('retry_sos_until_ack', 'Retry SOS until acknowledged'),
            SettingsDropdownTile<int>(
              title: 'Retry interval',
              value: _retryInterval,
              items: const {
                10: '10 seconds',
                20: '20 seconds',
                30: '30 seconds'
              },
              onChanged: (value) async {
                setState(() => _retryInterval = value);
                await ref
                    .read(settingsServiceProvider)
                    .setInt('sos_retry_interval_seconds', value);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSectionCard(
          title: 'Alert Feedback',
          icon: Icons.notifications_active_rounded,
          children: [
            _boolTile('sos_vibration_enabled', 'Vibration'),
            _boolTile('sos_sound_enabled', 'Sound alert'),
            _boolTile(
              'sos_fullscreen_alert_enabled',
              'Show full-screen SOS alert',
            ),
          ],
        ),
      ],
    );
  }

  Widget _boolTile(String key, String title) {
    return SettingsToggleTile(
      title: title,
      value: _bools[key] ?? true,
      onChanged: (value) async {
        if (key == 'attach_location_to_sos' && !value) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'SOS will still work, but location will not be attached.'),
            ),
          );
        }
        setState(() => _bools[key] = value);
        await ref.read(settingsServiceProvider).setBool(key, value);
      },
    );
  }
}

class AppLockPrivacySettingsScreen extends ConsumerStatefulWidget {
  const AppLockPrivacySettingsScreen({super.key});

  @override
  ConsumerState<AppLockPrivacySettingsScreen> createState() =>
      _AppLockPrivacySettingsScreenState();
}

class _AppLockPrivacySettingsScreenState
    extends ConsumerState<AppLockPrivacySettingsScreen> {
  final _bools = <String, bool>{};
  String _timeout = '1 minute';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    for (final key in _privacyBoolKeys) {
      _bools[key] = await settings.getBool(
        key,
        AppSettingsDefaults.byKey[key]?.defaultValue == 'true',
      );
    }
    _timeout = await settings.getString('auto_lock_timeout', '1 minute');
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'App Lock & Privacy',
      loading: _loading,
      children: [
        const SettingsInfoBox(
          message:
              'App Lock protects private screens after startup or resume. Quick SOS remains available while locked.',
          icon: Icons.lock_rounded,
          color: AppColors.offlinePurple,
        ),
        const SizedBox(height: 14),
        SettingsSectionCard(
          title: 'App Lock',
          icon: Icons.lock_rounded,
          children: [
            _boolTile('app_lock_enabled', 'Enable App Lock'),
            _boolTile(
              'biometric_unlock_enabled',
              'Use device fingerprint / phone PIN',
            ),
            _boolTile('trail_pin_enabled', 'Use TrailLink PIN fallback'),
            SettingsDropdownTile<String>(
              title: 'Auto-lock after',
              value: _timeout,
              items: const {
                'immediately': 'Immediately',
                '30 seconds': '30 seconds',
                '1 minute': '1 minute',
                '5 minutes': '5 minutes',
                '15 minutes': '15 minutes',
              },
              onChanged: (value) async {
                setState(() => _timeout = value);
                await ref
                    .read(settingsServiceProvider)
                    .setString('auto_lock_timeout', value);
                await ref
                    .read(appLockControllerProvider.notifier)
                    .updateAutoLockTimeout(
                        AppLockRepository.parseTimeout(value));
              },
            ),
            FilledButton.icon(
              onPressed: () => context.go('/settings/app-lock/setup'),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Configure App Lock'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSectionCard(
          title: 'Emergency Access & Data Privacy',
          icon: Icons.privacy_tip_rounded,
          children: [
            _boolTile(
              'quick_sos_from_lock_enabled',
              'Allow Quick SOS from locked screen',
            ),
            _boolTile(
              'hide_message_preview_when_locked',
              'Hide message preview when locked',
            ),
            _boolTile(
              'hide_location_when_locked',
              'Hide location details when locked',
            ),
            _boolTile(
              'auto_delete_trip_data_after_trip',
              'Auto-delete offline data after trip',
            ),
          ],
        ),
      ],
    );
  }

  Widget _boolTile(String key, String title) {
    return SettingsToggleTile(
      title: title,
      value: _bools[key] ?? false,
      onChanged: (value) async {
        if (key == 'app_lock_enabled') {
          if (value) {
            setState(() => _bools[key] = true);
            await ref.read(appLockControllerProvider.notifier).enableAppLock();
            if (mounted) context.go('/settings/app-lock/setup');
            return;
          }
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Disable App Lock?'),
                  content: const Text(
                    'This removes the TrailLink PIN and disables app-level privacy protection.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Disable'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!confirmed) return;
          await ref.read(appLockControllerProvider.notifier).disableAppLock();
        }
        if (key == 'biometric_unlock_enabled') {
          await ref
              .read(appLockControllerProvider.notifier)
              .updateBiometricEnabled(value);
        } else if (key == 'trail_pin_enabled') {
          await ref
              .read(appLockControllerProvider.notifier)
              .updateTrailPinEnabled(value);
          if (value && !ref.read(appLockControllerProvider).pinConfigured) {
            if (mounted) context.go('/settings/app-lock/setup');
          }
        } else if (key == 'quick_sos_from_lock_enabled') {
          await ref
              .read(appLockControllerProvider.notifier)
              .updateQuickSosEnabled(value);
        }
        setState(() => _bools[key] = value);
        await ref.read(settingsServiceProvider).setBool(key, value);
      },
    );
  }
}

class VoicePttSettingsScreen extends ConsumerStatefulWidget {
  const VoicePttSettingsScreen({super.key});

  @override
  ConsumerState<VoicePttSettingsScreen> createState() =>
      _VoicePttSettingsScreenState();
}

class _VoicePttSettingsScreenState
    extends ConsumerState<VoicePttSettingsScreen> {
  final _bools = <String, bool>{};
  int _maxOffline = 15;
  int _timeout = 35;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    for (final key in _voiceBoolKeys) {
      _bools[key] = await settings.getBool(
        key,
        AppSettingsDefaults.byKey[key]?.defaultValue == 'true',
      );
    }
    if (_bools['live_radio_enabled'] == false &&
        await settings.getBool('enable_live_radio', false)) {
      _bools['live_radio_enabled'] = true;
    }
    if (_bools['voice_note_ptt_enabled'] == false &&
        await settings.getBool('enable_voice_note_ptt', false)) {
      _bools['voice_note_ptt_enabled'] = true;
    }
    _maxOffline =
        await settings.getInt('max_offline_voice_duration_seconds', 15);
    _timeout = await settings.getInt('speaker_timeout_seconds', 35);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Voice & Walkie-Talkie',
      loading: _loading,
      children: [
        SettingsSectionCard(
          title: 'Voice-note PTT',
          icon: Icons.mic_rounded,
          children: [
            _boolTile('voice_note_ptt_enabled', 'Enable voice-note PTT'),
            SettingsDropdownTile<int>(
              title: 'Max offline voice-note duration',
              value: _maxOffline,
              items: const {
                10: '10 seconds',
                15: '15 seconds',
                20: '20 seconds'
              },
              onChanged: (value) async {
                setState(() => _maxOffline = value);
                await ref
                    .read(settingsServiceProvider)
                    .setInt('max_offline_voice_duration_seconds', value);
              },
            ),
            _boolTile('one_speaker_at_a_time', 'Only one speaker at a time'),
            SettingsDropdownTile<int>(
              title: 'Speaker timeout',
              value: _timeout,
              items: const {
                20: '20 seconds',
                35: '35 seconds',
                45: '45 seconds'
              },
              onChanged: (value) async {
                setState(() => _timeout = value);
                await ref
                    .read(settingsServiceProvider)
                    .setInt('speaker_timeout_seconds', value);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSectionCard(
          title: 'Live Radio Experimental',
          icon: Icons.radio_rounded,
          children: [
            _boolTile('live_radio_enabled', 'Enable Live Radio'),
            _boolTile(
              'live_radio_requires_strong_connection',
              'Require strong connection for live radio',
            ),
            _boolTile(
              'live_radio_fallback_to_voice_note',
              'Fallback to voice-note if weak',
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsSectionCard(
          title: 'Audio Privacy',
          icon: Icons.folder_special_rounded,
          children: [
            _boolTile('store_voice_notes_locally', 'Store voice notes locally'),
            _boolTile(
              'auto_delete_voice_after_trip',
              'Auto-delete voice notes after trip',
            ),
          ],
        ),
      ],
    );
  }

  Widget _boolTile(String key, String title) {
    return SettingsToggleTile(
      title: title,
      value: _bools[key] ?? false,
      onChanged: (value) async {
        if (key == 'live_radio_enabled' && value) {
          final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Enable Live Radio Experimental?'),
                  content: const Text(
                    'Live Radio is offline-only and experimental. It should be used only with connected peers and a good connection.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Enable'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (!confirmed) return;
          await ref
              .read(settingsServiceProvider)
              .setBool('understand_live_radio_experimental', true);
        }
        setState(() => _bools[key] = value);
        await ref.read(settingsServiceProvider).setBool(key, value);
        if (key == 'voice_note_ptt_enabled') {
          await ref.read(settingsServiceProvider).setBool(
                'enable_voice_note_ptt',
                value,
              );
          ref.invalidate(featureFlagProvider);
        }
        if (key == 'live_radio_enabled') {
          await ref.read(settingsServiceProvider).setBool(
                'enable_live_radio',
                value,
              );
          ref.invalidate(featureFlagProvider);
        }
      },
    );
  }
}

class DataSyncSettingsScreen extends ConsumerStatefulWidget {
  const DataSyncSettingsScreen({super.key});

  @override
  ConsumerState<DataSyncSettingsScreen> createState() =>
      _DataSyncSettingsScreenState();
}

class _DataSyncSettingsScreenState
    extends ConsumerState<DataSyncSettingsScreen> {
  final _bools = <String, bool>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    for (final key in _dataSyncBoolKeys) {
      _bools[key] = await settings.getBool(
        key,
        AppSettingsDefaults.byKey[key]?.defaultValue == 'true',
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Data & Sync',
      loading: _loading,
      children: [
        SettingsSectionCard(
          title: 'Sync Behavior',
          icon: Icons.cloud_sync_rounded,
          children: [
            for (final entry in _dataSyncLabels.entries)
              SettingsToggleTile(
                title: entry.value,
                value: _bools[entry.key] ?? false,
                onChanged: (value) async {
                  setState(() => _bools[entry.key] = value);
                  await ref
                      .read(settingsServiceProvider)
                      .setBool(entry.key, value);
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        const SettingsSectionCard(
          title: 'Sync Notes',
          icon: Icons.storage_rounded,
          children: [
            SettingsInfoBox(
              message:
                  'TrailLink saves important data locally first. When Online Mode is ready, enabled sync categories run automatically in the background.',
              icon: Icons.info_outline_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class AgreementPrivacySettingsScreen extends ConsumerStatefulWidget {
  const AgreementPrivacySettingsScreen({super.key});

  @override
  ConsumerState<AgreementPrivacySettingsScreen> createState() =>
      _AgreementPrivacySettingsScreenState();
}

class _AgreementPrivacySettingsScreenState
    extends ConsumerState<AgreementPrivacySettingsScreen> {
  bool _offline = false;
  bool _location = false;
  bool _radio = false;
  bool _accepted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsServiceProvider);
    _offline = await settings.getBool('understand_offline_limitations', false);
    _location = await settings.getBool('allow_location_for_sos', false);
    _radio =
        await settings.getBool('understand_live_radio_experimental', false);
    _accepted =
        await settings.getBool(AppSettingsDefaults.agreementAccepted, false);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Agreement & Privacy',
      loading: _loading,
      children: [
        SettingsSectionCard(
          title: 'Safety & Privacy Agreement',
          subtitle:
              'TrailLink uses location, nearby discovery, microphone recording, and local storage based on your settings and permissions.',
          icon: Icons.verified_user_rounded,
          children: [
            SettingsToggleTile(
              title: 'I understand offline communication limits',
              subtitle:
                  'Nearby delivery depends on devices in the same channel and cannot guarantee delivery.',
              value: _offline,
              onChanged: (value) =>
                  _setBool('understand_offline_limitations', value),
            ),
            SettingsToggleTile(
              title: 'I agree to location use for SOS',
              value: _location,
              onChanged: (value) => _setBool('allow_location_for_sos', value),
            ),
            SettingsToggleTile(
              title: 'I understand Live Radio is experimental',
              value: _radio,
              onChanged: (value) =>
                  _setBool('understand_live_radio_experimental', value),
            ),
            SettingsToggleTile(
              title: 'Agreement accepted',
              value: _accepted,
              onChanged: (value) async {
                await _setBool(AppSettingsDefaults.agreementAccepted, value);
                if (value) {
                  await ref.read(settingsServiceProvider).setString(
                        'agreement_accepted_at',
                        DateTime.now().toIso8601String(),
                      );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setBool(String key, bool value) async {
    setState(() {
      if (key == 'understand_offline_limitations') _offline = value;
      if (key == 'allow_location_for_sos') _location = value;
      if (key == 'understand_live_radio_experimental') _radio = value;
      if (key == AppSettingsDefaults.agreementAccepted) _accepted = value;
    });
    await ref.read(settingsServiceProvider).setBool(key, value);
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({
    required this.title,
    required this.children,
    required this.loading,
  });

  final String title;
  final List<Widget> children;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: children,
              ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.identity});

  final LocalIdentityModel? identity;

  @override
  Widget build(BuildContext context) {
    final name = identity?.displayName ?? 'TrailLink profile';
    final id = identity?.publicUserId;
    final subtitle = id?.isNotEmpty == true
        ? 'TrailLink ID: $id'
        : identity == null
            ? 'Create your local profile during setup'
            : 'TrailLink ID not created yet';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go('/settings/profile'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.deepForest.withValues(alpha: 0.12),
                child: Text(
                  _initials(name),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.deepForest,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, color: AppColors.deepForest),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionHeading extends StatelessWidget {
  const _SettingsSectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _ReadOnlyProfileRow extends StatelessWidget {
  const _ReadOnlyProfileRow({
    required this.label,
    required this.value,
    this.copyValue,
  });

  final String label;
  final String value;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    final canCopy = copyValue?.isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.mutedText,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          if (canCopy)
            IconButton(
              tooltip: 'Copy $label',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyValue!));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    this.isRequired = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool isRequired;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _humanizeStatus(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'TL';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.item});

  final _SettingsItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(item.icon, color: item.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(item.subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureToggle {
  const _FeatureToggle({
    required this.key,
    required this.title,
    required this.group,
    this.subtitle,
  });

  final String key;
  final String title;
  final String group;
  final String? subtitle;
}

const _featureItems = [
  _FeatureToggle(
      key: 'enable_cloud_chat', title: 'Cloud Group Chat', group: 'online'),
  _FeatureToggle(
    key: 'enable_online_location_sync',
    title: 'Online Location Sync',
    group: 'online',
  ),
  _FeatureToggle(
      key: 'enable_cloud_sos',
      title: 'Cloud Emergency Alerts',
      group: 'online'),
  _FeatureToggle(
    key: 'enable_bridge_mode',
    title: 'Bridge Mode',
    group: 'online',
    subtitle: 'Help same-channel offline teammates reach the cloud',
  ),
  _FeatureToggle(
      key: 'enable_offline_channel',
      title: 'Offline Channel',
      group: 'offline'),
  _FeatureToggle(
    key: 'enable_nearby_discovery',
    title: 'Nearby Peer Discovery',
    group: 'offline',
  ),
  _FeatureToggle(
      key: 'enable_offline_chat', title: 'Offline Text Chat', group: 'offline'),
  _FeatureToggle(
      key: 'enable_offline_sos', title: 'Offline SOS', group: 'offline'),
  _FeatureToggle(
    key: 'enable_offline_location_share',
    title: 'Offline Location Sharing',
    group: 'offline',
  ),
  _FeatureToggle(
    key: 'enable_connectivity_compass',
    title: 'Connectivity Compass',
    group: 'offline',
  ),
];

const _safetyBoolKeys = [
  'confirm_before_sos',
  'attach_location_to_sos',
  'use_last_known_location_for_sos',
  'retry_sos_until_ack',
  'sos_vibration_enabled',
  'sos_sound_enabled',
  'sos_fullscreen_alert_enabled',
];

const _privacyBoolKeys = [
  'app_lock_enabled',
  'biometric_unlock_enabled',
  'trail_pin_enabled',
  'quick_sos_from_lock_enabled',
  'hide_message_preview_when_locked',
  'hide_location_when_locked',
  'auto_delete_trip_data_after_trip',
];

const _voiceBoolKeys = [
  'voice_note_ptt_enabled',
  'one_speaker_at_a_time',
  'live_radio_enabled',
  'live_radio_requires_strong_connection',
  'live_radio_fallback_to_voice_note',
  'store_voice_notes_locally',
  'auto_delete_voice_after_trip',
];

const _dataSyncBoolKeys = [
  'auto_sync_when_online',
  'sync_offline_messages',
  'sync_sos_history',
  'sync_location_history',
  'sync_normal_voice_notes',
];

const _dataSyncLabels = {
  'auto_sync_when_online': 'Auto-sync when online',
  'sync_offline_messages': 'Sync offline messages',
  'sync_sos_history': 'Sync SOS history',
  'sync_location_history': 'Sync location history',
  'sync_normal_voice_notes': 'Sync normal offline voice notes',
};
