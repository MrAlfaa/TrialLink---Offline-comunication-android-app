# Phase 14F Setup Cloud Failure Fix Report

## Bug Summary

During setup, selecting Manual Mode with Online as the default could trigger cloud identity bootstrap. If cloud account creation failed, the blocking dialog showed "Cloud setup unavailable". Tapping Continue Offline only cleared that dialog state, so the persisted mode stayed Manual Online and the app reopened in an online/cloud-unavailable state.

## Root Cause

- `CloudAccountProgressOverlay` handled Continue Offline by calling only `cloudSyncController.clear()`.
- No code path wrote `mode_control_type=manual`, `manual_communication_mode=offline`, `user_mode=offline`, or `selected_mode=offline`.
- The failed local identity was marked with `sync_state=failed`, which made later cloud retry intent less clear than `needs_cloud_create`.
- Error wording mixed server reachability, timeout, and bootstrap failure into one generic backend message.

## Files Changed

- `lib/features/setup/data/setup_cloud_failure_recovery_service.dart`
- `lib/features/cloud_identity/presentation/cloud_account_progress_overlay.dart`
- `lib/features/cloud_identity/data/cloud_identity_repository.dart`
- `lib/features/cloud_identity/data/cloud_sync_controller.dart`
- `lib/core/mode/mode_controller.dart`
- `lib/core/identity/local_identity_repository.dart`
- `test/setup_cloud_failure_mode_test.dart`

## Implementation Details

- Added `SetupCloudFailureRecoveryService.continueOfflineAfterCloudFailure()`.
- Continue Offline now:
  - keeps the local identity saved,
  - records `cloud_status=sync_failed`,
  - records `sync_state=needs_cloud_create`,
  - writes Manual Offline mode settings,
  - sets `setup_completed=true`,
  - clears cloud blocking state,
  - refreshes auth and mode providers,
  - routes to `/home`.
- Auto mode cloud bootstrap failure now degrades the effective mode to Offline and clears the blocking overlay, with this warning:
  - "Cloud setup failed. Offline Mode is available. TrailLink will retry cloud setup when the server is reachable."
- Offline mode does not attempt cloud bootstrap.
- Cloud setup failure wording now distinguishes:
  - no network: "No internet connection."
  - server unreachable: "TrailLink cloud server is unreachable."
  - timeout: "Cloud setup timed out."
  - email conflict: "This email is already linked to another TrailLink profile."
  - generic bootstrap failure: "Cloud account creation failed."

## Tests Added

- `test/setup_cloud_failure_mode_test.dart`
  - Continue Offline persists Manual Offline and completes setup.
  - Auto mode cloud failure degrades to effective Offline and clears the blocking overlay.
  - Offline mode setup does not attempt cloud bootstrap.
  - Error wording distinguishes no internet, server unreachable, timeout, email conflict, and generic bootstrap failure.

## Verification Results

- `flutter analyze`
  - PASS: No issues found.
- `flutter test test\setup_cloud_failure_mode_test.dart`
  - PASS: 5 tests passed.
- `flutter test`
  - PASS: 116 tests passed.
- `flutter build apk --debug`
  - PASS: Built `build\app\outputs\flutter-apk\app-debug.apk`.
- Samsung device install
  - PASS: `adb -s R58R85Q2HWH install -r build\app\outputs\flutter-apk\app-debug.apk`
- Samsung launch smoke check
  - PASS: `com.example.traillink/.MainActivity` launched and stayed running.
  - Screenshot: `docs/qa/screenshots/phase14f/phase14f-launch.png`
  - Note: device opened to the existing app-lock screen, so setup-flow UI verification was not completed on-device in this pass.

## Manual Verification Steps

1. Reset app data or use a device/profile that is not past setup.
2. Enter setup and save a local identity.
3. Select Manual Mode and Online as the default manual state.
4. Make cloud bootstrap fail by leaving backend unavailable or returning a bootstrap error.
5. Confirm the dialog title is "Cloud setup unavailable".
6. Confirm dialog body says the local TrailLink profile is saved and Offline Mode can continue.
7. Tap Continue Offline.
8. Confirm the app opens `/home`.
9. Confirm dashboard shows Offline Mode and Sync Paused.
10. Confirm local identity is still present and cloud retry remains available later.

## Remaining Risks

- The physical Samsung was app-locked during this verification pass, so the exact setup failure flow was validated by automated tests and launch smoke check, not by end-to-end device tapping.
- Auto mode fallback is session-local; a later app restart or explicit mode change can retry cloud setup through the existing cloud profile actions.
