# Phase 14I Chat Shell Composer QA Report

Date: 2026-05-10

## Bug Summary

Samsung QA showed the offline chat route resolving real trip/channel data but rendering an incomplete chat surface. The screen showed the trip title, offline subtitle, channel code, queued chip, and the global bottom navigation, but the message body and composer were missing.

## Root Cause

The route/header context was valid. Runtime diagnostics showed `canCompose=true`, `loading=false`, `messages=0`, and `peers=0`, so the composer was not blocked by trip/channel state.

The remaining failure was layout:

- Offline chat had been moved through route/layout variants during Phase 14H and needed to be shell-owned again so `TrailBottomNav` could render.
- `OfflineChatInputBar` still used viewport-height math and fixed min/max composer constraints. On the physical Samsung layout this produced a fragile bottom composer surface even though widget tests passed.
- `ChatAppBar` used zero title spacing, so the chat title started at the screen edge when no back button was implied.

## Files Changed

- `lib/app/router.dart`
- `lib/features/offline_chat/presentation/offline_chat_screen.dart`
- `lib/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart`
- `lib/features/chat/presentation/widgets/chat_app_bar.dart`
- `lib/features/chat/presentation/chat_screen.dart`
- `test/offline_chat_layout_test.dart`
- `test/phase14h_fullscreen_chat_context_test.dart`
- `test/phase14b_active_channel_resolution_test.dart`
- `test/chat_media_messaging_test.dart`
- `backend/scripts/qa-clean-user-data.js`
- `backend/package.json`

## Implementation Details

- Moved canonical and legacy offline chat routes back under `ShellRoute`.
- Kept `TrailBottomNav` visible and selected on Messages for offline and cloud chat routes.
- Reworked offline chat to use `ChatAppBar`, a `SafeArea(bottom: false)`, a constrained `Column`, an `Expanded` message area, and `OfflineChatInputBar` as the final child.
- Removed the old composer viewport-height calculation and fixed min/max height constraints.
- Kept the composer visible for zero messages, zero peers, and queued mode.
- Kept read-only replacement behavior for ended/read-only chat.
- Adjusted `ChatAppBar` spacing so header text no longer starts at x=0.
- Added a safe QA Mongo cleanup script that requires a specific identity selector and `QA_ALLOW_DELETE=true` before deletion.

## Verification Results

- `flutter analyze`: PASS, no issues found.
- `flutter test test\offline_chat_layout_test.dart`: PASS, 6 tests.
- `flutter test test\phase14h_fullscreen_chat_context_test.dart`: PASS, 7 tests.
- `flutter test test\phase14b_active_channel_resolution_test.dart`: PASS, 14 tests.
- `flutter test test\chat_media_messaging_test.dart`: PASS, 6 tests.
- `flutter test`: PASS, 130 tests.
- `flutter build apk --debug`: PASS, produced `build\app\outputs\flutter-apk\app-debug.apk`.
- Backend health on `127.0.0.1:5001/api/health`: PASS.
- `adb reverse tcp:5000 tcp:5001`: PASS.

## Device QA

Device: Samsung `R58R85Q2HWH`

Local reset and fresh install:

- `adb shell pm clear com.example.traillink`
- `adb uninstall com.example.traillink`
- `adb install -r build\app\outputs\flutter-apk\app-debug.apk`

Offline chat:

- Fresh setup completed.
- Active offline trip/channel opened from Messages.
- Header, channel chip, message area, no-peer hint, composer, send button, and bottom nav are visible together.
- Zero-peer send created a local queued/ack-timeout message and kept the composer visible.

Online chat:

- Backend was reachable through ADB reverse.
- Created QA cloud group `QAGroup`.
- Opened cloud group chat.
- Cloud chat header, empty state, attachment button, text field, send button, and bottom nav are visible together.

Screenshots:

- `docs/qa/final_offline_chat_composer_visible_wait.png`
- `docs/qa/cloud_chat_composer_visible.png`

## Mongo QA Cleanup

Cleanup target: `publicUserId=UID-202605090009`

Dry run matched:

- 1 user
- 1 owned group
- 1 group member

Delete with `QA_ALLOW_DELETE=true` removed:

- 1 user
- 1 owned group
- 1 group member

Final dry run confirmed no matching QA user remained. No full database wipe was performed.

## Final Local Cleanup

After screenshot verification and Mongo cleanup, Samsung app data was cleared again with:

- `adb shell pm clear com.example.traillink`

The final debug APK remains installed, but local SQLite, shared preferences, cache, and secure storage are reset.

## Remaining Risks

- The final cloud QA account was intentionally removed from MongoDB after screenshot verification.
- The physical device is now clean; opening the app again starts setup from a reset local state.
- Xiaomi was not retested because Samsung `R58R85Q2HWH` was the available connected device.
