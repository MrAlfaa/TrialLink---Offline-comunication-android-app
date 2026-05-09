import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/identity_bootstrap_service.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../core/settings/app_settings_defaults.dart';
import '../../../core/settings/settings_service.dart';
import '../../../core/setup/setup_progress_service.dart';
import '../../../shared/widgets/agreement_checkbox_tile.dart';
import '../../../shared/widgets/settings_dropdown_tile.dart';
import '../../../shared/widgets/settings_info_box.dart';
import '../../../shared/widgets/settings_toggle_tile.dart';
import '../../app_lock/presentation/app_lock_controller.dart';

class SetupWelcomeScreen extends StatelessWidget {
  const SetupWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      title: 'TrailLink',
      subtitle: 'Stay connected. Even off-grid.',
      icon: Icons.terrain_rounded,
      step: 1,
      heroAsset: 'assets/branding/onboarding_hero.png',
      children: [
        Text(
          'For hikers, campers, and outdoor groups who need communication and safety tools in low-connectivity environments.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 26),
        FilledButton.icon(
          onPressed: () => context.go('/setup/agreement'),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Start Setup'),
        ),
      ],
    );
  }
}

class SetupAgreementScreen extends ConsumerStatefulWidget {
  const SetupAgreementScreen({super.key});

  @override
  ConsumerState<SetupAgreementScreen> createState() =>
      _SetupAgreementScreenState();
}

class _SetupAgreementScreenState extends ConsumerState<SetupAgreementScreen> {
  bool _agreement = false;
  bool _location = false;
  bool _shareLocation = false;
  bool _radio = false;

  bool get _canContinue => _agreement;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      title: 'Safety & Privacy Agreement',
      subtitle: 'Read how TrailLink handles safety data in the field.',
      icon: Icons.verified_user_rounded,
      step: 2,
      heroAsset: 'assets/branding/safety_shield_sos.png',
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 360),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AgreementSection(
                  title: 'Safety first',
                  body:
                      'TrailLink supports emergency alerts, nearby communication, maps, and voice notes during trips. These tools are designed to help your group communicate, but they are not a replacement for official emergency services.',
                ),
                _AgreementSection(
                  title: 'Offline limitations',
                  body:
                      'Offline delivery depends on nearby devices, Bluetooth or Wi-Fi availability, battery level, terrain, and channel setup. TrailLink cannot guarantee that every offline message or SOS alert will reach every teammate.',
                ),
                _AgreementSection(
                  title: 'Location and SOS',
                  body:
                      'SOS can be sent with or without coordinates. If you allow SOS location, TrailLink will try to attach current or last-known location based on your settings. General teammate location sharing is controlled separately.',
                ),
                _AgreementSection(
                  title: 'Nearby peer communication',
                  body:
                      'Nearby communication exchanges channel, identity, and packet metadata with devices using the same trip/channel context. Do not join channels that you do not trust.',
                ),
                _AgreementSection(
                  title: 'Voice and experimental features',
                  body:
                      'Voice-note PTT stores short clips locally or sends them through available paths. Live Radio remains experimental and may consume battery or fail in weak connections.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AgreementCheckboxTile(
          title:
              'I have read and agree to the TrailLink safety and privacy agreement.',
          subtitle: 'Required to continue normal setup.',
          value: _agreement,
          onChanged: (value) => setState(() => _agreement = value),
        ),
        AgreementCheckboxTile(
          title: 'Attach my location to SOS alerts.',
          subtitle: 'Optional. SOS can still be sent without coordinates.',
          value: _location,
          onChanged: (value) => setState(() => _location = value),
        ),
        AgreementCheckboxTile(
          title: 'Enable general location sharing with teammates.',
          subtitle: 'Optional. This controls manual map/location broadcasts.',
          value: _shareLocation,
          onChanged: (value) => setState(() => _shareLocation = value),
        ),
        AgreementCheckboxTile(
          title: 'I understand Live Radio is experimental.',
          value: _radio,
          onChanged: (value) => setState(() => _radio = value),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _canContinue
              ? () async {
                  final settings = ref.read(settingsServiceProvider);
                  await settings.setBool(
                    'understand_offline_limitations',
                    true,
                  );
                  await settings.setBool('allow_location_for_sos', _location);
                  await settings.setBool('attach_location_to_sos', _location);
                  await settings.setBool(
                    'enable_offline_location_share',
                    _shareLocation,
                  );
                  await settings.setBool(
                    'offline_location_share_enabled',
                    _shareLocation,
                  );
                  await settings.setBool(
                    'understand_live_radio_experimental',
                    _radio,
                  );
                  await settings.setBool(
                    AppSettingsDefaults.agreementAccepted,
                    true,
                  );
                  await ref
                      .read(setupProgressServiceProvider)
                      .markAgreementAccepted();
                  if (context.mounted) context.go('/setup/identity');
                }
              : null,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Accept and Continue'),
        ),
      ],
    );
  }
}

class SetupIdentityScreen extends ConsumerStatefulWidget {
  const SetupIdentityScreen({super.key});

  @override
  ConsumerState<SetupIdentityScreen> createState() =>
      _SetupIdentityScreenState();
}

class _SetupIdentityScreenState extends ConsumerState<SetupIdentityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      title: 'Create your TrailLink profile',
      subtitle: 'Create one TrailLink profile for offline and cloud sync.',
      icon: Icons.badge_rounded,
      step: 3,
      heroAsset: 'assets/branding/onboarding_hero.png',
      children: [
        const SettingsInfoBox(
          message:
              'TrailLink saves your profile locally first. Cloud account creation runs later when you enter Online Mode.',
          icon: Icons.person_pin_circle_rounded,
          color: AppColors.skyBlue,
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.deepForest,
                foregroundColor: Colors.white,
                child: Text(
                  _initials(_nameController.text),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length < 2 || trimmed.length > 50) {
                    return 'Display name must be 2-50 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email / Gmail optional',
                  helperText:
                      'Optional. Used later when creating a cloud profile.',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                      .hasMatch(trimmed)) {
                    return 'Enter a valid email or leave it blank.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number optional',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Emergency note optional',
                  prefixIcon: Icon(Icons.note_alt_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length > 200) {
                    return 'Emergency note must be 200 characters or less.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _saving ? null : _saveIdentity,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: const Text('Save Profile'),
        ),
      ],
    );
  }

  Future<void> _saveIdentity() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final result =
          await ref.read(identityBootstrapServiceProvider).createIdentity(
                displayName: _nameController.text,
                email: _emailController.text,
                phoneNumber: _phoneController.text,
                emergencyNote: _noteController.text,
              );
      await ref.read(setupProgressServiceProvider).markIdentityConfigured();
      await ref
          .read(authAccessControllerProvider.notifier)
          .refreshFromIdentity();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'TrailLink profile saved.')),
      );
      context.go('/setup/mode');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return 'TL';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class SetupModePreferenceScreen extends ConsumerStatefulWidget {
  const SetupModePreferenceScreen({super.key});

  @override
  ConsumerState<SetupModePreferenceScreen> createState() =>
      _SetupModePreferenceScreenState();
}

class _SetupModePreferenceScreenState
    extends ConsumerState<SetupModePreferenceScreen> {
  ModeControlType _controlType = ModeControlType.auto;
  ManualCommunicationMode _manualMode = ManualCommunicationMode.offline;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      title: 'Choose startup mode',
      subtitle: 'Choose automatic switching or a manual communication path.',
      icon: Icons.sync_alt_rounded,
      step: 4,
      heroAsset: 'assets/branding/mode_auto_manual.png',
      children: [
        SettingsDropdownTile<ModeControlType>(
          title: 'Mode Control',
          value: _controlType,
          items: const {
            ModeControlType.auto: 'Auto Mode',
            ModeControlType.manual: 'Manual Mode',
          },
          onChanged: (mode) => setState(() => _controlType = mode),
        ),
        if (_controlType == ModeControlType.manual) ...[
          const SizedBox(height: 12),
          SettingsDropdownTile<ManualCommunicationMode>(
            title: 'Default Manual State',
            value: _manualMode,
            items: const {
              ManualCommunicationMode.online: 'Online',
              ManualCommunicationMode.offline: 'Offline',
            },
            onChanged: (mode) => setState(() => _manualMode = mode),
          ),
        ],
        const SizedBox(height: 12),
        const SettingsInfoBox(
          message:
              'Auto Mode changes the feature set as backend availability changes. Manual Mode lets you choose Online or Offline yourself.',
          icon: Icons.sync_rounded,
          color: AppColors.skyBlue,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            final settings = ref.read(settingsServiceProvider);
            final userMode = _controlType == ModeControlType.auto
                ? UserMode.auto
                : _manualMode.userMode;
            await settings.setString('mode_control_type', _controlType.name);
            await settings.setString(
              'manual_communication_mode',
              _manualMode.name,
            );
            await settings.setString('default_startup_mode', userMode.name);
            await settings.setString(
                AppSettingsDefaults.selectedMode, userMode.name);
            await settings.setString(
                AppSettingsDefaults.userMode, userMode.name);
            await settings.setBool('auto_switch_enabled', true);
            await settings.setBool('show_mode_explanations', true);
            await ref
                .read(modeControllerProvider.notifier)
                .setModeControlType(_controlType);
            if (_controlType == ModeControlType.manual) {
              await ref
                  .read(modeControllerProvider.notifier)
                  .setManualCommunicationMode(_manualMode);
            }
            await ref.read(setupProgressServiceProvider).markModeConfigured();
            if (context.mounted) context.go('/setup/features');
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
      ],
    );
  }
}

class SetupFeaturePreferenceScreen extends ConsumerStatefulWidget {
  const SetupFeaturePreferenceScreen({super.key});

  @override
  ConsumerState<SetupFeaturePreferenceScreen> createState() =>
      _SetupFeaturePreferenceScreenState();
}

class _SetupFeaturePreferenceScreenState
    extends ConsumerState<SetupFeaturePreferenceScreen> {
  bool _offlineSos = true;
  bool _location = true;
  bool _nearby = true;
  bool _voice = true;
  bool _radio = false;
  bool _compass = true;
  bool _bridge = true;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      title: 'Choose features to enable',
      subtitle: 'Recommended safety features are enabled by default.',
      icon: Icons.tune_rounded,
      step: 5,
      heroAsset: 'assets/branding/mode_auto_manual.png',
      children: [
        _toggle('Offline SOS', _offlineSos, (value) async {
          if (!value) {
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
          setState(() => _offlineSos = value);
        }),
        _toggle(
          'Offline Location Sharing',
          _location,
          (value) {
            setState(() => _location = value);
          },
        ),
        _toggle('Nearby Peer Discovery', _nearby, (value) {
          setState(() => _nearby = value);
        }),
        _toggle('Voice-note PTT', _voice, (value) {
          setState(() => _voice = value);
        }),
        _toggle('Live Radio Experimental', _radio, (value) {
          setState(() => _radio = value);
        }),
        _toggle('Connectivity Compass', _compass, (value) {
          setState(() => _compass = value);
        }),
        _toggle('Bridge Mode', _bridge, (value) {
          setState(() => _bridge = value);
        }),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            final settings = ref.read(settingsServiceProvider);
            await settings.setBool('enable_cloud_chat', true);
            await settings.setBool('enable_online_location_sync', true);
            await settings.setBool('enable_cloud_sos', true);
            await settings.setBool('enable_offline_sos', _offlineSos);
            await settings.setBool('offline_sos_enabled', _offlineSos);
            await settings.setBool('enable_offline_channel', true);
            await settings.setBool('enable_offline_location_share', _location);
            await settings.setBool(
              'offline_location_share_enabled',
              _location,
            );
            await settings.setBool('enable_nearby_discovery', _nearby);
            await settings.setBool('enable_offline_chat', true);
            await settings.setBool('enable_voice_note_ptt', _voice);
            await settings.setBool('voice_note_ptt_enabled', _voice);
            await settings.setBool('enable_live_radio', _radio);
            await settings.setBool('live_radio_enabled', _radio);
            await settings.setBool('enable_connectivity_compass', _compass);
            await settings.setBool('enable_bridge_mode', _bridge);
            await ref
                .read(setupProgressServiceProvider)
                .markFeaturePreferencesConfigured();
            if (context.mounted) context.go('/setup/security');
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _toggle(
      String title, bool value, FutureOr<void> Function(bool) assign) {
    return SettingsToggleTile(
      title: title,
      value: value,
      onChanged: (next) async => assign(next),
    );
  }
}

class SetupSecurityPreferenceScreen extends ConsumerStatefulWidget {
  const SetupSecurityPreferenceScreen({super.key});

  @override
  ConsumerState<SetupSecurityPreferenceScreen> createState() =>
      _SetupSecurityPreferenceScreenState();
}

class _SetupSecurityPreferenceScreenState
    extends ConsumerState<SetupSecurityPreferenceScreen> {
  bool _appLock = false;
  bool _biometric = true;
  bool _quickSos = true;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      title: 'Secure your TrailLink app',
      subtitle: 'Protect messages, locations, SOS history, and voice notes.',
      icon: Icons.lock_rounded,
      step: 6,
      heroAsset: 'assets/branding/safety_shield_sos.png',
      children: [
        const SettingsInfoBox(
          message:
              'App Lock protects private data. If fingerprint and PIN are both enabled, either one unlocks TrailLink. Quick SOS can still work from the locked screen.',
          icon: Icons.lock_rounded,
          color: AppColors.offlinePurple,
        ),
        const SizedBox(height: 10),
        _toggle('Enable App Lock', _appLock, (value) => _appLock = value),
        _toggle(
          'Use fingerprint / phone PIN',
          _biometric,
          (value) => _biometric = value,
        ),
        _toggle(
          'Allow Quick SOS from lock screen',
          _quickSos,
          (value) => _quickSos = value,
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            final settings = ref.read(settingsServiceProvider);
            await settings.setBool('biometric_unlock_enabled', _biometric);
            await settings.setBool('trail_pin_enabled', true);
            await settings.setString('auto_lock_timeout', '1 minute');
            await settings.setBool('quick_sos_from_lock_enabled', _quickSos);
            if (_appLock) {
              final appLock = ref.read(appLockControllerProvider.notifier);
              await appLock.enableAppLock();
              await appLock.updateBiometricEnabled(_biometric);
              await appLock.updateTrailPinEnabled(true);
              await appLock.updateAutoLockTimeout(const Duration(minutes: 1));
              await appLock.updateQuickSosEnabled(_quickSos);
              if (context.mounted) {
                context.go('/settings/app-lock/setup?next=/setup/trip');
              }
              return;
            }
            await settings.setBool('app_lock_enabled', false);
            await ref
                .read(setupProgressServiceProvider)
                .markSecurityPreferencesConfigured();
            if (context.mounted) context.go('/setup/trip');
          },
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
        TextButton(
          onPressed: () async {
            await ref
                .read(setupProgressServiceProvider)
                .markSecurityPreferencesConfigured();
            if (context.mounted) context.go('/setup/trip');
          },
          child: const Text('Skip for now'),
        ),
      ],
    );
  }

  Widget _toggle(String title, bool value, ValueChanged<bool> assign) {
    return SettingsToggleTile(
      title: title,
      value: value,
      onChanged: (next) => setState(() => assign(next)),
    );
  }
}

class SetupPermissionScreen extends ConsumerWidget {
  const SetupPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SetupScaffold(
      title: 'Permissions',
      subtitle:
          'TrailLink will request permissions only when features need them.',
      icon: Icons.fact_check_rounded,
      step: 8,
      heroAsset: 'assets/branding/trip_channel_hero.png',
      children: [
        const SettingsInfoBox(
          message:
              'Location supports maps and SOS. Bluetooth, Wi-Fi, and Nearby support offline peers. Microphone supports voice-note PTT.',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () async {
            final setup = ref.read(setupProgressServiceProvider);
            await setup.markPermissionsConfigured();
            await setup.completeSetup();
            await ref
                .read(authAccessControllerProvider.notifier)
                .refreshFromIdentity();
            if (context.mounted) context.go('/home');
          },
          icon: const Icon(Icons.check_rounded),
          label: const Text('Finish Setup'),
        ),
      ],
    );
  }
}

class _SetupScaffold extends StatelessWidget {
  const _SetupScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    required this.step,
    this.heroAsset,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final int step;
  final String? heroAsset;

  @override
  Widget build(BuildContext context) {
    final previous = _previousSetupRoute(step);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (previous != null) {
          context.go(previous);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.softSand,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          leading: previous == null
              ? null
              : IconButton(
                  onPressed: () => context.go(previous),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/branding/setup_background.png',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.softSand.withValues(alpha: 0.72),
              ),
            ),
            SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Step $step of 8',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.deepForest
                                      .withValues(alpha: 0.16),
                                  blurRadius: 22,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: SizedBox(
                                height: 178,
                                width: double.infinity,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (heroAsset != null)
                                      Image.asset(
                                        heroAsset!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                      )
                                    else
                                      const DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: AppColors.deepForest,
                                        ),
                                      ),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.deepForest
                                                .withValues(alpha: 0.04),
                                            AppColors.deepForest
                                                .withValues(alpha: 0.50),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.deepForest,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.deepForest
                                      .withValues(alpha: 0.16),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 32),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          ...children,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _previousSetupRoute(int step) {
  return switch (step) {
    1 => null,
    2 => '/setup/welcome',
    3 => '/setup/agreement',
    4 => '/setup/identity',
    5 => '/setup/mode',
    6 => '/setup/features',
    7 => '/setup/security',
    8 => '/setup/trip',
    _ => null,
  };
}

class _AgreementSection extends StatelessWidget {
  const _AgreementSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}
