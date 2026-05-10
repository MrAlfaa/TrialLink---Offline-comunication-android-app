# Phase 14D Chat Layout Fix Report

## Root Cause Summary

Samsung device testing confirmed the offline chat route resolves the active channel and renders the header/chips, but the chat body/composer still does not render visibly on the physical device. The failing route shows `test trip`, `Offline Chat - 0 peers nearby`, `TL-OFF-NEM7`, and the global bottom nav, proving routing and channel resolution are working.

The remaining issue is isolated to the offline chat render surface under the shell. Source and widget tests now protect the expected chat layout, but physical verification is still not passing.

A separate confirmed bug was fixed: the trip setup wizard hardcoded Nearby permission readiness as `Missing`, so granting Android Nearby permissions did not update readiness.

## Files Changed

- `lib/features/offline_chat/presentation/offline_chat_screen.dart`
- `lib/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart`
- `lib/features/nearby/data/nearby_permission_service.dart`
- `lib/features/trip/presentation/trip_setup_wizard_screen.dart`
- `test/offline_chat_layout_test.dart`
- `test/nearby_permission_readiness_test.dart`
- `test/phase14b_active_channel_resolution_test.dart`

## Layout Approach Used

- Kept the offline chat route scoped to the existing app shell.
- Kept the global `TrailBottomNav` visible.
- Added stable keys for the offline chat screen, message area, empty state, composer, input, send button, no-peer hint, and read-only bar.
- Kept zero-peer chat send enabled so messages can queue locally.
- Added a read-only bar path for ended channels instead of showing an enabled composer.
- Tried bottom-clearance and floating overlay placement for the composer because the physical device shows the shell nav and header but not the body surface.

## Removed Wrappers / Hacks

- Removed the global `_constrainedPageChild` page wrapper from the route transition helpers.
- Removed manual viewport sizing from the offline chat body.
- Avoided putting the composer inside the message list or a full-screen scroll view.

## Nearby Permission Fix

- Added `NearbyPermissionReadiness` with `ready`, `missing`, `blocked`, and `optional`.
- Added check-only permission flow via `NearbyPermissionService.check()` / `checkNearbyPermissionStatus()`.
- Kept `checkAndRequest()` for the explicit Grant Permission action.
- Updated trip readiness to map actual permission state instead of hardcoding `Nearby permission` as missing.
- Added pure mapper tests for granted, denied, permanently denied, and disabled location-service states.

## Tests Added

- `test/offline_chat_layout_test.dart`
  - zero messages / zero peers keeps composer visible
  - zero-peer send queues message into local list
  - ended channel shows read-only bar instead of composer
  - existing messages keep composer visible
  - shell bottom nav layout keeps composer above nav in widget test

- `test/nearby_permission_readiness_test.dart`
  - granted -> ready
  - denied -> missing
  - permanently denied -> blocked
  - location service disabled -> missing

## Commands Run

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter test test\offline_chat_layout_test.dart test\nearby_permission_readiness_test.dart test\phase14b_active_channel_resolution_test.dart
adb -s R58R85Q2HWH install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s R58R85Q2HWH shell screencap -p /sdcard/...
adb -s R58R85Q2HWH pull /sdcard/... docs\qa\screenshots\phase14e\...
adb -s R58R85Q2HWH shell uiautomator dump /sdcard/...
```

## Results

- `flutter analyze`: PASS, no issues found.
- `flutter test`: PASS, 111 tests passed.
- `flutter build apk --debug`: PASS.
- Samsung physical device: NOT PASS for final acceptance. The offline chat route still shows header/chips and global bottom nav, but the composer is not visible in the captured chat route.

## Device Evidence

- Latest failing chat screenshot: `docs/qa/screenshots/phase14e/36-current-chat.png`
- Latest failing UI tree: `docs/qa/screenshots/phase14e/36-current-chat.xml`
- Additional failed attempts: `31-phase14d-offline-chat-composer-visible.png`, `34-phase14d-offline-chat-composer-visible.png`

## Manual Device Verification Steps

1. Install `build\app\outputs\flutter-apk\app-debug.apk`.
2. Launch app on Samsung `R58R85Q2HWH`.
3. Open Messages.
4. Tap `Offline Channel Chat`.
5. Expected: header, empty/message area, queue hint, text field, send button, and global bottom nav visible together.
6. Current actual: header and bottom nav visible; composer still missing.

## Remaining Risks

- The source/widget-level layout contract is now covered, but the physical shell route still behaves differently.
- The next debugging pass should instrument the actual Flutter render tree or run the app through `flutter run` attached logs to identify why the chat body/floating surface does not paint on Samsung.
- Do not mark `TL-QA-14A-010` resolved until a physical screenshot shows the composer.
