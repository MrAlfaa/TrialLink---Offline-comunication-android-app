# Phase 14H Full-Screen Chat Context Fix Report

## Summary

Phase 14H moves offline chat detail out of the bottom-nav shell and onto a full-screen route backed by `ActiveTripContext`. The canonical route is now:

- `/trips/:tripId/channels/:channelId/chats/:chatId`

Legacy routes remain supported through a resolver screen:

- `/offline-channel/:channelId/chat`
- `/offline-channels/:channelId/chat`

## Root Cause

The previous offline chat path still opened through shell-era routing and layout assumptions. The route could render the header while the message body and composer were not reliably laid out on the Samsung device. Runtime render inspection showed the composer was present in the widget tree, but the body subtree did not receive a stable rendered size.

The fix avoids the shell path, resolves the exact trip/channel/chat context, and renders chat as one full-screen `Scaffold` body with a single `SafeArea -> Column`:

1. Header.
2. Status strips.
3. `Expanded` message area.
4. Composer or read-only bar as the final child.

## Files Changed

- `lib/app/router.dart`
- `lib/features/trip_context/data/trip_context_service.dart`
- `lib/features/offline_chat/presentation/offline_chat_screen.dart`
- `lib/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart`
- `lib/features/chat/presentation/chat_hub_screen.dart`
- `lib/features/offline_channel/presentation/offline_channel_details_screen.dart`
- `test/offline_chat_layout_test.dart`
- `test/phase14b_active_channel_resolution_test.dart`
- `test/phase14h_fullscreen_chat_context_test.dart`

## Route Changes

The canonical full-screen route is registered before `ShellRoute`, so the global `TrailBottomNav` is not rendered inside chat detail. Legacy channel-chat URLs now load a resolver screen that resolves the default active chat for the channel and replaces the location with the canonical full-screen route.

## ActiveTripContext Resolution

`TripContextService` now exposes:

- `resolveOfflineChatContext({required tripId, required channelId, String? chatId})`
- `resolveDefaultOfflineChatRoute(String channelId)`

The resolver validates that the requested channel belongs to the requested trip, ensures a default `General` chat when needed, and exposes read-only/membership state for composer visibility.

## Composer Rules

The composer remains visible when:

- trip, channel, and chat are active
- there are zero messages
- there are zero nearby peers
- outgoing messages are queued

The composer is replaced by `offline-chat-readonly-bar` only when the trip/channel/chat is ended, archived, read-only, or membership is left/removed/blocked.

## Layout Changes

The offline chat screen now uses a single full-screen body layout:

- No global bottom nav.
- No `floatingActionButton`.
- No chat `bottomNavigationBar`.
- No physical viewport height calculation.
- Empty chat uses direct centered content inside the `Expanded` message area.
- The input bar applies a finite responsive max-height to avoid unbounded device layout constraints while still sizing naturally.

Stable QA keys retained:

- `offline-chat-screen`
- `offline-chat-message-area`
- `offline-chat-empty-state`
- `offline-chat-composer`
- `offline-chat-input`
- `offline-chat-send-button`
- `offline-chat-no-peers-hint`
- `offline-chat-readonly-bar`

## Test Results

Commands run:

```text
flutter test test\phase14h_fullscreen_chat_context_test.dart
Result: passed, 7/7

flutter test test\offline_chat_layout_test.dart
Result: passed, 6/6

flutter test test\phase14b_active_channel_resolution_test.dart
Result: passed, 14/14

flutter analyze
Result: No issues found

flutter test
Result: passed, 129/129

flutter build apk --debug
Result: passed, built build\app\outputs\flutter-apk\app-debug.apk
```

Note: one parallel Flutter test invocation hit a Windows native-assets copy race in `build/unit_test_assets`. The same tests passed when rerun sequentially.

## Samsung Device QA

Device:

- Samsung `R58R85Q2HWH`

Completed:

- Debug APK installed successfully with `adb install -r`.
- App launched successfully.
- App lock appeared as expected after reinstall.

Blocked:

- Final screenshot proof is pending because the physical app is currently on the TrailLink PIN screen and ADB cannot bypass app lock. No debug bypass was added.

Captured files:

- `docs/qa/phase14h_after_header_wait.png`
- `docs/qa/phase14h_after_header_unlock.xml`
- Earlier pre-final diagnostic captures are also under `docs/qa/phase14h_*.png` and `docs/qa/phase14h_*.xml`.

Required final capture after user unlock:

```powershell
adb -s R58R85Q2HWH shell screencap -p /sdcard/phase14h_fullscreen_chat_final.png
adb -s R58R85Q2HWH pull /sdcard/phase14h_fullscreen_chat_final.png docs/qa/phase14h_fullscreen_chat_final.png
```

## Remaining Risks

- Final Samsung screenshot after the last layout adjustment is still pending behind app lock.
- Xiaomi retest remains pending until that device is connected.
- Online/cloud chat routing was intentionally left unchanged except shared test expectations.
