import 'app_lock_status.dart';

class AppLockState {
  const AppLockState({
    required this.status,
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.trailPinEnabled,
    required this.quickSosEnabled,
    required this.autoLockTimeout,
    this.lastUnlockedAt,
    this.lastBackgroundedAt,
    this.failedPinAttempts = 0,
    this.pinLockoutUntil,
    this.message,
    this.intendedRoute,
    this.isInitialized = false,
    this.biometricAvailable = false,
    this.pinConfigured = false,
    this.unlockInProgress = false,
    this.lastUnlockCompletedAt,
  });

  factory AppLockState.initial() {
    return const AppLockState(
      status: AppLockStatus.disabled,
      appLockEnabled: false,
      biometricEnabled: true,
      trailPinEnabled: true,
      quickSosEnabled: true,
      autoLockTimeout: Duration(seconds: 60),
    );
  }

  final AppLockStatus status;
  final bool appLockEnabled;
  final bool biometricEnabled;
  final bool trailPinEnabled;
  final bool quickSosEnabled;
  final Duration autoLockTimeout;
  final DateTime? lastUnlockedAt;
  final DateTime? lastBackgroundedAt;
  final int failedPinAttempts;
  final DateTime? pinLockoutUntil;
  final String? message;
  final String? intendedRoute;
  final bool isInitialized;
  final bool biometricAvailable;
  final bool pinConfigured;
  final bool unlockInProgress;
  final DateTime? lastUnlockCompletedAt;

  bool get isLocked =>
      status == AppLockStatus.locked ||
      status == AppLockStatus.setupRequired ||
      status == AppLockStatus.pinLockedOut;

  bool get canUsePin =>
      trailPinEnabled &&
      pinConfigured &&
      (pinLockoutUntil == null || DateTime.now().isAfter(pinLockoutUntil!));

  AppLockState copyWith({
    AppLockStatus? status,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? trailPinEnabled,
    bool? quickSosEnabled,
    Duration? autoLockTimeout,
    DateTime? lastUnlockedAt,
    bool clearLastUnlockedAt = false,
    DateTime? lastBackgroundedAt,
    bool clearLastBackgroundedAt = false,
    int? failedPinAttempts,
    DateTime? pinLockoutUntil,
    bool clearPinLockoutUntil = false,
    String? message,
    bool clearMessage = false,
    String? intendedRoute,
    bool clearIntendedRoute = false,
    bool? isInitialized,
    bool? biometricAvailable,
    bool? pinConfigured,
    bool? unlockInProgress,
    DateTime? lastUnlockCompletedAt,
    bool clearLastUnlockCompletedAt = false,
  }) {
    return AppLockState(
      status: status ?? this.status,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      trailPinEnabled: trailPinEnabled ?? this.trailPinEnabled,
      quickSosEnabled: quickSosEnabled ?? this.quickSosEnabled,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      lastUnlockedAt:
          clearLastUnlockedAt ? null : lastUnlockedAt ?? this.lastUnlockedAt,
      lastBackgroundedAt: clearLastBackgroundedAt
          ? null
          : lastBackgroundedAt ?? this.lastBackgroundedAt,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      pinLockoutUntil:
          clearPinLockoutUntil ? null : pinLockoutUntil ?? this.pinLockoutUntil,
      message: clearMessage ? null : message ?? this.message,
      intendedRoute:
          clearIntendedRoute ? null : intendedRoute ?? this.intendedRoute,
      isInitialized: isInitialized ?? this.isInitialized,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      pinConfigured: pinConfigured ?? this.pinConfigured,
      unlockInProgress: unlockInProgress ?? this.unlockInProgress,
      lastUnlockCompletedAt: clearLastUnlockCompletedAt
          ? null
          : lastUnlockCompletedAt ?? this.lastUnlockCompletedAt,
    );
  }
}
