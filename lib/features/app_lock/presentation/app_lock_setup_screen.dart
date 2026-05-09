import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/setup/setup_progress_service.dart';
import '../../../shared/widgets/settings_dropdown_tile.dart';
import '../../../shared/widgets/settings_info_box.dart';
import '../../../shared/widgets/settings_section_card.dart';
import '../../../shared/widgets/settings_toggle_tile.dart';
import '../data/trail_pin_service.dart';
import 'app_lock_controller.dart';

class AppLockSetupScreen extends ConsumerStatefulWidget {
  const AppLockSetupScreen({super.key});

  @override
  ConsumerState<AppLockSetupScreen> createState() => _AppLockSetupScreenState();
}

class _AppLockSetupScreenState extends ConsumerState<AppLockSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _enabled = true;
  bool _biometric = true;
  bool _pinFallback = true;
  bool _quickSos = true;
  Duration _timeout = const Duration(minutes: 1);
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _readCurrentLockState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(appLockControllerProvider.notifier).initialize();
      if (!mounted) return;
      setState(_readCurrentLockState);
    });
  }

  void _readCurrentLockState() {
    final state = ref.read(appLockControllerProvider);
    _enabled = state.appLockEnabled || state.status.name == 'setupRequired';
    _biometric = state.biometricEnabled;
    _pinFallback = state.trailPinEnabled;
    _quickSos = state.quickSosEnabled;
    _timeout = state.autoLockTimeout;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider);
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    final pinRequired = _enabled && !lockState.pinConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Secure TrailLink')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SettingsInfoBox(
              message:
                  'App Lock protects private screens. Quick SOS remains available without revealing private data.',
              icon: Icons.lock_rounded,
              color: AppColors.offlinePurple,
            ),
            if (!lockState.biometricAvailable && _biometric) ...[
              const SizedBox(height: 12),
              const SettingsInfoBox(
                message: 'Biometric unlock is unavailable on this device.',
                icon: Icons.fingerprint_rounded,
                color: AppColors.warning,
              ),
            ],
            const SizedBox(height: 14),
            SettingsSectionCard(
              title: 'App Lock',
              icon: Icons.lock_rounded,
              children: [
                SettingsToggleTile(
                  title: 'Enable App Lock',
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                SettingsToggleTile(
                  title: 'Device fingerprint / phone PIN',
                  value: _biometric,
                  onChanged: (value) => setState(() => _biometric = value),
                ),
                SettingsToggleTile(
                  title: 'TrailLink PIN fallback',
                  value: pinRequired || _pinFallback,
                  onChanged: (value) {
                    if (pinRequired && !value) {
                      setState(() {
                        _pinFallback = true;
                        _error =
                            'Create a 4-digit TrailLink PIN before disabling PIN fallback.';
                      });
                      return;
                    }
                    setState(() => _pinFallback = value);
                  },
                ),
                if (pinRequired) ...[
                  const SizedBox(height: 10),
                  const SettingsInfoBox(
                    message:
                        'Create a 4-digit TrailLink PIN now. Fingerprint or phone PIN can also unlock TrailLink when available.',
                    icon: Icons.pin_rounded,
                    color: AppColors.warning,
                  ),
                ],
                if (_enabled &&
                    (pinRequired || _pinFallback) &&
                    !lockState.pinConfigured) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Create TrailLink PIN',
                      prefixIcon: Icon(Icons.pin_rounded),
                    ),
                  ),
                  TextField(
                    controller: _confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Confirm TrailLink PIN',
                      prefixIcon: Icon(Icons.check_rounded),
                    ),
                  ),
                ],
                SettingsDropdownTile<Duration>(
                  title: 'Auto-lock after',
                  value: _timeout,
                  items: {
                    Duration.zero: 'Immediately',
                    const Duration(seconds: 30): '30 seconds',
                    const Duration(minutes: 1): '1 minute',
                    const Duration(minutes: 5): '5 minutes',
                    const Duration(minutes: 15): '15 minutes',
                  },
                  onChanged: (value) => setState(() => _timeout = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SettingsSectionCard(
              title: 'Emergency Access',
              icon: Icons.emergency_share_rounded,
              children: [
                SettingsToggleTile(
                  title: 'Quick SOS from locked screen',
                  value: _quickSos,
                  onChanged: (value) => setState(() => _quickSos = value),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(context, next),
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save Security Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, String? next) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final controller = ref.read(appLockControllerProvider.notifier);
      if (!_enabled) {
        await controller.disableAppLock();
      } else {
        final lockState = ref.read(appLockControllerProvider);
        final pinRequired = !lockState.pinConfigured;
        final useTrailPin = _pinFallback || pinRequired;
        if (!_biometric && !useTrailPin) {
          throw StateError(
            'Enable fingerprint / phone PIN or TrailLink PIN to use App Lock.',
          );
        }
        await controller.enableAppLock();
        await controller.updateBiometricEnabled(_biometric);
        await controller.updateTrailPinEnabled(useTrailPin);
        await controller.updateQuickSosEnabled(_quickSos);
        await controller.updateAutoLockTimeout(_timeout);
        if (useTrailPin && !lockState.pinConfigured) {
          final pin = _pinController.text.trim();
          if (!TrailPinService.isValidPin(pin)) {
            throw StateError('TrailLink PIN must be exactly 4 digits.');
          }
          if (pin != _confirmController.text.trim()) {
            throw StateError('PIN confirmation does not match.');
          }
          await controller.configurePin(pin);
        } else if (lockState.pinConfigured) {
          await controller.completeConfigurationWithExistingPin();
        }
      }
      if (next != null && next.isNotEmpty) {
        await ref
            .read(setupProgressServiceProvider)
            .markSecurityPreferencesConfigured();
      }
      if (!context.mounted) return;
      context.go(next == null || next.isEmpty ? '/settings/app-lock' : next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
