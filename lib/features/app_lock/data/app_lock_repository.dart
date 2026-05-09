import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_service.dart';
import 'models/app_lock_state.dart';
import 'models/app_lock_status.dart';
import 'trail_pin_service.dart';

final appLockRepositoryProvider = Provider<AppLockRepository>((ref) {
  return AppLockRepository(
    settings: ref.read(settingsServiceProvider),
    pinService: TrailPinService(),
  );
});

class AppLockRepository {
  AppLockRepository({
    required SettingsService settings,
    required TrailPinService pinService,
  })  : _settings = settings,
        _pinService = pinService;

  final SettingsService _settings;
  final TrailPinService _pinService;

  Future<AppLockState> load({
    bool biometricAvailable = false,
  }) async {
    final enabled = await _settings.getBool('app_lock_enabled', false);
    final configured = await _settings.getBool('app_lock_configured', false);
    final pinConfigured = await _pinService.hasPin();
    final trailPinEnabled = await _settings.getBool('trail_pin_enabled', true);
    final pinLockoutUntil =
        _parseDate(await _settings.getString('app_lock_pin_lockout_until', ''));
    final lockoutActive =
        pinLockoutUntil != null && DateTime.now().isBefore(pinLockoutUntil);
    final status = !enabled
        ? AppLockStatus.disabled
        : (!configured || (trailPinEnabled && !pinConfigured))
            ? AppLockStatus.setupRequired
            : lockoutActive
                ? AppLockStatus.pinLockedOut
                : AppLockStatus.locked;

    return AppLockState(
      status: status,
      appLockEnabled: enabled,
      biometricEnabled:
          await _settings.getBool('biometric_unlock_enabled', true),
      trailPinEnabled: trailPinEnabled,
      quickSosEnabled:
          await _settings.getBool('quick_sos_from_lock_enabled', true),
      autoLockTimeout: parseTimeout(
        await _settings.getString('auto_lock_timeout', '1 minute'),
      ),
      lastUnlockedAt: _parseDate(
          await _settings.getString('app_lock_last_unlocked_at', '')),
      lastBackgroundedAt: _parseDate(
        await _settings.getString('app_lock_last_backgrounded_at', ''),
      ),
      failedPinAttempts:
          await _settings.getInt('app_lock_failed_pin_attempts', 0),
      pinLockoutUntil: pinLockoutUntil,
      isInitialized: true,
      biometricAvailable: biometricAvailable,
      pinConfigured: pinConfigured,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _settings.setBool('app_lock_enabled', enabled);
    if (!enabled) {
      await _settings.setBool('app_lock_configured', false);
      await _settings.setInt('app_lock_failed_pin_attempts', 0);
      await _settings.setString('app_lock_pin_lockout_until', '');
      await _pinService.clearPin();
    }
  }

  Future<void> markConfigured() async {
    await _settings.setBool('app_lock_configured', true);
    await _settings.setBool('app_lock_enabled', true);
  }

  Future<void> saveUnlockTime(DateTime now) async {
    await _settings.setString(
        'app_lock_last_unlocked_at', now.toIso8601String());
  }

  Future<void> saveBackgroundedAt(DateTime now) async {
    await _settings.setString(
      'app_lock_last_backgrounded_at',
      now.toIso8601String(),
    );
  }

  Future<void> clearBackgroundedAt() {
    return _settings.setString('app_lock_last_backgrounded_at', '');
  }

  Future<void> saveFailedAttempts(int attempts) {
    return _settings.setInt('app_lock_failed_pin_attempts', attempts);
  }

  Future<void> savePinLockoutUntil(DateTime? until) {
    return _settings.setString(
      'app_lock_pin_lockout_until',
      until?.toIso8601String() ?? '',
    );
  }

  Future<void> setBiometricEnabled(bool value) {
    return _settings.setBool('biometric_unlock_enabled', value);
  }

  Future<void> setTrailPinEnabled(bool value) {
    return _settings.setBool('trail_pin_enabled', value);
  }

  Future<void> setQuickSosEnabled(bool value) {
    return _settings.setBool('quick_sos_from_lock_enabled', value);
  }

  Future<void> setAutoLockTimeout(Duration timeout) {
    return _settings.setString('auto_lock_timeout', timeoutToLabel(timeout));
  }

  Future<void> configurePin(String pin) => _pinService.configurePin(pin);

  Future<bool> verifyPin(String pin) => _pinService.verifyPin(pin);

  Future<bool> hasPin() => _pinService.hasPin();

  static Duration parseTimeout(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'immediately' => Duration.zero,
      '0' => Duration.zero,
      '30 seconds' => const Duration(seconds: 30),
      '30' => const Duration(seconds: 30),
      '1 minute' => const Duration(minutes: 1),
      '60' => const Duration(minutes: 1),
      '5 minutes' => const Duration(minutes: 5),
      '300' => const Duration(minutes: 5),
      '15 minutes' => const Duration(minutes: 15),
      '900' => const Duration(minutes: 15),
      _ => const Duration(minutes: 1),
    };
  }

  static String timeoutToLabel(Duration timeout) {
    if (timeout == Duration.zero) return 'immediately';
    if (timeout == const Duration(seconds: 30)) return '30 seconds';
    if (timeout == const Duration(minutes: 5)) return '5 minutes';
    if (timeout == const Duration(minutes: 15)) return '15 minutes';
    return '1 minute';
  }

  static bool shouldLockOnResume({
    required bool appLockEnabled,
    required DateTime? lastBackgroundedAt,
    required Duration timeout,
    required DateTime now,
  }) {
    if (!appLockEnabled || lastBackgroundedAt == null) return false;
    if (timeout == Duration.zero) return true;
    return now.difference(lastBackgroundedAt) >= timeout;
  }

  static bool shouldSkipResumeRelock({
    required bool unlockInProgress,
    required DateTime? lastUnlockCompletedAt,
    required DateTime now,
    required Duration grace,
  }) {
    if (unlockInProgress) return true;
    if (lastUnlockCompletedAt == null) return false;
    return now.difference(lastUnlockCompletedAt) <= grace;
  }

  static DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
