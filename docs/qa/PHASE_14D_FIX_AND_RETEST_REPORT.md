# TrailLink Phase 14D Fix And Retest Report

Date: 2026-05-09  
Scope: Active offline channel runtime resolution, dependent offline routing, and assisted Android retest.  
Devices:
- Xiaomi `HAF6ZXGI5TINKJCA`
- Samsung `R58R85Q2HWH`

## Summary

Phase 14D fixed the runtime split between active trip state and offline-channel state. The resolver now repairs stale local membership instead of rejecting otherwise valid active trip/channel data, and joining an offline channel activates a trip-first local session.

Xiaomi retest evidence confirms:
- Home shows active offline trip `QA_P2P_Trip_A` with channel `TL-OFF-XVZG`.
- Offline Channels lists the active channel.
- Nearby Peers detects the active channel and shows discovery controls.
- Connectivity Guidance detects the active channel and shows channel-aware guidance.
- Dashboard PTT opens the offline PTT screen for the active channel.

Two-device P2P transfer was not completed in this pass. Samsung still showed the older channel in the available evidence before a fresh join retest. Offline Chat composer code was changed and full Flutter tests pass, but the final Android composer screenshot is not a valid PASS because the Xiaomi device was reset into setup during deep-link/route attempts.

## Files Changed

- `lib/features/offline_channel/data/active_offline_channel_resolver.dart`
- `lib/features/trip/data/trip_session_repository.dart`
- `lib/features/offline_channel/presentation/offline_channel_controller.dart`
- `lib/features/offline_channel/presentation/join_offline_channel_screen.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/chat/presentation/chat_hub_screen.dart`
- `lib/features/offline_chat/presentation/offline_chat_screen.dart`
- `lib/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart`
- `lib/shared/widgets/trail_scaffold.dart`
- `test/phase14b_active_channel_resolution_test.dart`
- `docs/qa/PHASE_14D_FIX_AND_RETEST_REPORT.md`
- `docs/qa/PHASE_14C_TWO_DEVICE_TEST_REPORT.md`
- `docs/qa/PHASE_14C_P2P_RESULTS.md`
- `docs/qa/PHASE_14C_SCREENSHOT_INDEX.md`
- `docs/qa/BUG_BACKLOG.md`

## Implementation Details

### Active Channel Resolver

The resolver now treats stale membership as repairable state:
- Resolves `offline_channels.is_active = 1` and `channel_status = active`.
- Falls back to active `trip_sessions` in `offline` or `hybrid` mode.
- Matches by `offline_channel_id`, then `channel_code`.
- Repairs channel active flags when active trip points at an inactive local channel row.
- Creates a repaired local channel row when the trip has a usable channel code but no local row.
- Inserts or reactivates the current local member row when membership is missing/stale.
- Still rejects ended channels and channels with missing channel code.

### Join Channel Activation

The offline channel join controller now calls `TripSessionRepository.activateOfflineChannelTrip(...)` after a successful join. That method:
- Sets the joined channel as active.
- Updates an existing matching offline/hybrid trip when possible.
- Creates a new active offline trip if no matching trip exists.
- Preserves existing channel/member rows and avoids destructive resets.

### Dependent Screens

Updated screens consume resolver-backed providers:
- Dashboard PTT routing.
- Messages Hub offline shortcuts.
- Nearby Peers.
- Connectivity Guidance.
- Offline Chat fallback channel resolution.

### Offline Chat Composer

The Offline Chat screen now has explicit fallback route handling and an inline composer path. The global bottom nav is hidden for `/offline-channel/:channelId/chat` so the chat route can reserve its own message surface. This fixes the shell/nav overlap risk in code, but final Android visual proof is still not captured due the device setup reset during retest.

## Automated Verification

| Command | Result | Evidence |
|---|---:|---|
| `flutter analyze` | PASS | `No issues found!` after final code edits |
| `flutter test test\phase14b_active_channel_resolution_test.dart` | PASS | 8 tests passed in targeted run |
| `flutter test` | PASS | 95 tests passed |
| `flutter build apk --debug` | PASS | Built `build\app\outputs\flutter-apk\app-debug.apk` |

## Android Retest Results

| Area | Result | Evidence |
|---|---:|---|
| Xiaomi Home active trip | PASS | `docs/qa/screenshots/phase14d/01-xiaomi-launch.png`, `08a-xiaomi-after-latest-install-ready.png` |
| Xiaomi Offline Channels list | PASS | `docs/qa/screenshots/phase14d/03-xiaomi-offline-channels.png` |
| Xiaomi Nearby active channel | PASS | `docs/qa/screenshots/phase14d/04-xiaomi-nearby-active-channel.png` |
| Xiaomi Connectivity active channel | PASS | `docs/qa/screenshots/phase14d/05-xiaomi-connectivity-active-channel.png` |
| Xiaomi Dashboard PTT route | PASS | `docs/qa/screenshots/phase14d/06-xiaomi-offline-ptt-from-dashboard.png` |
| Samsung same joined channel | PARTIAL | `02-samsung-launch.png` still shows old `TL-OFF-BL4C`; fresh join retest not completed |
| Offline Chat composer visual proof | PARTIAL | Code/test updated, but final screenshot was not valid after device reset into setup |
| Two-device P2P discovery/chat/SOS/PTT | NOT TESTED | Requires fresh manual two-device flow after both devices are on same active channel |

## Remaining Blockers

- Xiaomi automation became unreliable again during the final chat retest and the app was routed into setup while trying to deep-launch chat.
- Samsung must be rejoined to the Xiaomi channel after installing the Phase 14D APK before two-device P2P can be marked PASS/FAIL.
- Offline Chat composer needs one clean manual screenshot after setup is restored; current final device evidence is not sufficient for PASS.

## Manual Retest Steps Still Needed

1. On both devices, install the latest debug APK.
2. On Xiaomi, confirm active trip `QA_P2P_Trip_A` / `TL-OFF-XVZG`.
3. On Samsung, join `TL-OFF-XVZG` again and confirm Home updates to that channel.
4. Open Messages -> Offline Channel Chat on Xiaomi and confirm the text composer is visible.
5. Start Nearby discovery/advertising on both devices.
6. Test offline text, SOS, location, PTT, media guard, and mode switch.

## Result

Ready for final demo: No  
Ready for manual two-device retest: Yes, after Samsung rejoins Xiaomi channel and Xiaomi setup state is restored.  
Recommended next phase: Manual two-device P2P verification with tester-assisted taps where ADB input is unreliable.
