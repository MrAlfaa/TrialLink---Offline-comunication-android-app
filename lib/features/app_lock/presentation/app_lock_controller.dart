import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_lock_repository.dart';
import '../data/biometric_auth_service.dart';
import '../data/models/app_lock_state.dart';
import '../data/models/app_lock_status.dart';
import '../data/trail_pin_service.dart';

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final appLockControllerProvider =
    StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(
    repository: ref.read(appLockRepositoryProvider),
    biometricAuth: ref.read(biometricAuthServiceProvider),
  );
});

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController({
    required AppLockRepository repository,
    required BiometricAuthService biometricAuth,
  })  : _repository = repository,
        _biometricAuth = biometricAuth,
        super(AppLockState.initial());

  final AppLockRepository _repository;
  final BiometricAuthService _biometricAuth;
  static const resumeUnlockGrace = Duration(seconds: 3);

  Future<void> initialize() async {
    final biometricAvailable = await _biometricAuth.isAvailable();
    state = await _repository.load(biometricAvailable: biometricAvailable);
  }

  Future<void> refreshConfiguration({bool preserveUnlocked = false}) async {
    final previous = state;
    final biometricAvailable = await _biometricAuth.isAvailable();
    final loaded =
        await _repository.load(biometricAvailable: biometricAvailable);
    if (preserveUnlocked &&
        previous.status == AppLockStatus.unlocked &&
        loaded.status == AppLockStatus.locked) {
      state = loaded.copyWith(status: AppLockStatus.unlocked);
      return;
    }
    state = loaded;
  }

  Future<void> enableAppLock() async {
    await _repository.setEnabled(true);
    await initialize();
  }

  Future<void> disableAppLock() async {
    await _repository.setEnabled(false);
    await initialize();
  }

  Future<void> configurePin(String pin) async {
    await _repository.configurePin(pin);
    await _repository.markConfigured();
    await _repository.saveFailedAttempts(0);
    await _repository.savePinLockoutUntil(null);
    await _unlock(message: 'App Lock configured.');
  }

  Future<void> completeConfigurationWithExistingPin() async {
    await _repository.markConfigured();
    await _repository.saveFailedAttempts(0);
    await _repository.savePinLockoutUntil(null);
    await _unlock(message: 'App Lock configured.');
  }

  Future<bool> unlockWithBiometric() async {
    if (!state.biometricEnabled) {
      state = state.copyWith(message: 'Biometric unlock is disabled.');
      return false;
    }
    state = state.copyWith(unlockInProgress: true, clearMessage: true);
    try {
      final result = await _biometricAuth.authenticate();
      if (result.success) {
        await _unlock();
        return true;
      }
      state = state.copyWith(
        unlockInProgress: false,
        message: result.message ??
            'Authentication failed. Try again or use TrailLink PIN.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        unlockInProgress: false,
        message: 'Authentication failed. Try again or use TrailLink PIN.',
      );
      return false;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    state = state.copyWith(unlockInProgress: true, clearMessage: true);
    final lockoutUntil = state.pinLockoutUntil;
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      state = state.copyWith(
        unlockInProgress: false,
        status: AppLockStatus.pinLockedOut,
        message: 'Too many attempts. Try again in 2 minutes.',
      );
      return false;
    }
    final ok = await _repository.verifyPin(pin);
    if (ok) {
      await resetFailedPinAttempts();
      await _unlock();
      return true;
    }
    await recordFailedPinAttempt();
    state = state.copyWith(unlockInProgress: false);
    return false;
  }

  Future<void> lockNow({String? intendedRoute}) async {
    if (!state.appLockEnabled || state.status == AppLockStatus.disabled) {
      return;
    }
    state = state.copyWith(
      status: state.status == AppLockStatus.setupRequired
          ? AppLockStatus.setupRequired
          : AppLockStatus.locked,
      intendedRoute: intendedRoute,
      message: 'App Lock is enabled. Unlock to continue.',
    );
  }

  Future<void> handleAppBackgrounded() async {
    if (state.unlockInProgress) return;
    final now = DateTime.now();
    await _repository.saveBackgroundedAt(now);
    state = state.copyWith(lastBackgroundedAt: now);
  }

  Future<void> handleAppResumed() async {
    if (!state.isInitialized) await initialize();
    if (state.unlockInProgress) return;
    if (AppLockRepository.shouldSkipResumeRelock(
      unlockInProgress: false,
      lastUnlockCompletedAt: state.lastUnlockCompletedAt,
      now: DateTime.now(),
      grace: resumeUnlockGrace,
    )) {
      await refreshConfiguration(preserveUnlocked: true);
      return;
    }
    if (await shouldLockOnResume()) {
      await lockNow();
      return;
    }
    await refreshConfiguration(preserveUnlocked: true);
  }

  Future<bool> shouldLockOnStartup() async {
    if (!state.isInitialized) await initialize();
    return state.appLockEnabled &&
        (state.status == AppLockStatus.locked ||
            state.status == AppLockStatus.setupRequired ||
            state.status == AppLockStatus.pinLockedOut);
  }

  Future<bool> shouldLockOnResume() async {
    if (!state.isInitialized) await initialize();
    return AppLockRepository.shouldLockOnResume(
      appLockEnabled: state.appLockEnabled,
      lastBackgroundedAt: state.lastBackgroundedAt,
      timeout: state.autoLockTimeout,
      now: DateTime.now(),
    );
  }

  Future<void> updateAutoLockTimeout(Duration timeout) async {
    await _repository.setAutoLockTimeout(timeout);
    state = state.copyWith(autoLockTimeout: timeout);
  }

  Future<void> updateQuickSosEnabled(bool enabled) async {
    await _repository.setQuickSosEnabled(enabled);
    state = state.copyWith(quickSosEnabled: enabled);
  }

  Future<void> updateBiometricEnabled(bool enabled) async {
    await _repository.setBiometricEnabled(enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> updateTrailPinEnabled(bool enabled) async {
    await _repository.setTrailPinEnabled(enabled);
    state = state.copyWith(trailPinEnabled: enabled);
  }

  Future<void> resetFailedPinAttempts() async {
    await _repository.saveFailedAttempts(0);
    await _repository.savePinLockoutUntil(null);
    state = state.copyWith(
      failedPinAttempts: 0,
      clearPinLockoutUntil: true,
      status: state.appLockEnabled ? AppLockStatus.locked : state.status,
    );
  }

  Future<void> recordFailedPinAttempt() async {
    final attempts = state.failedPinAttempts + 1;
    if (attempts >= TrailPinService.maxFailedAttempts) {
      final until = DateTime.now().add(TrailPinService.lockoutDuration);
      await _repository.saveFailedAttempts(attempts);
      await _repository.savePinLockoutUntil(until);
      state = state.copyWith(
        unlockInProgress: false,
        status: AppLockStatus.pinLockedOut,
        failedPinAttempts: attempts,
        pinLockoutUntil: until,
        message: 'Too many attempts. Try again in 2 minutes.',
      );
      return;
    }
    await _repository.saveFailedAttempts(attempts);
    state = state.copyWith(
      unlockInProgress: false,
      failedPinAttempts: attempts,
      message: 'Wrong PIN. Try again.',
    );
  }

  Future<void> _unlock({String? message}) async {
    final now = DateTime.now();
    await _repository.saveFailedAttempts(0);
    await _repository.savePinLockoutUntil(null);
    await _repository.saveUnlockTime(now);
    await _repository.clearBackgroundedAt();
    state = state.copyWith(
      status: state.appLockEnabled
          ? AppLockStatus.unlocked
          : AppLockStatus.disabled,
      lastUnlockedAt: now,
      lastUnlockCompletedAt: now,
      clearLastBackgroundedAt: true,
      failedPinAttempts: 0,
      clearPinLockoutUntil: true,
      unlockInProgress: false,
      message: message,
      clearMessage: message == null,
      clearIntendedRoute: true,
    );
  }
}
