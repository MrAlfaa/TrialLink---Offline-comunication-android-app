# TrailLink Phase 14B Fix Report

Date: 2026-05-09

## Scope

Phase 14B fixed the split source of truth for the active offline channel. Home could show an active offline trip because it read `trip_sessions`, while Offline Channels, Nearby Peers, Connectivity Guidance, PTT, and Offline Chat depended on older active-channel lookups.

No backend changes, SQLite migrations, database reset, or feature redesigns were made.

## Files Changed

### Active channel resolution

- `lib/features/offline_channel/data/active_offline_channel_resolver.dart`
- `lib/features/offline_channel/data/offline_channel_local_data_source.dart`
- `lib/features/offline_channel/presentation/offline_channel_controller.dart`

### Screens and routing

- `lib/app/router.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/features/chat/presentation/chat_hub_screen.dart`
- `lib/features/nearby/presentation/nearby_peers_screen.dart`
- `lib/features/connectivity_intelligence/presentation/connectivity_guidance_screen.dart`
- `lib/features/connectivity_intelligence/presentation/connectivity_controller.dart`
- `lib/features/offline_chat/presentation/offline_chat_screen.dart`
- `lib/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart`
- `lib/shared/widgets/mode_bottom_sheet.dart`
- `lib/features/offline_channel/presentation/active_channel_debug_screen.dart`

### Tests

- `test/phase14b_active_channel_resolution_test.dart`
- `test/main_ui_redesign_test.dart`

## Implementation Summary

`ActiveOfflineChannelResolver` is now the central source for resolving an active usable offline channel. It resolves in this order:

1. Prefer an `offline_channels` row where `is_active = 1` and `channel_status = active`.
2. If not found, inspect the active `trip_sessions` row where `status = active` and `mode` is `offline` or `hybrid`.
3. Match the trip channel by `offline_channel_id`, then by `channel_code`.
4. If the trip references an existing channel that is not marked active, repair it by clearing other active flags and setting this channel active.
5. If the trip only has a channel code and the channel row is missing, create one local repaired channel row without duplicating existing rows.
6. Reject ended channels as active usable channels.

The resolver preserves existing rows and does not delete messages, members, packets, trips, or channels.

## Screen Fixes

| Area | Fix |
| --- | --- |
| Offline Channels | List provider repairs from active trip before listing channels. |
| Nearby Peers | Uses `activeUsableOfflineChannelProvider`, so an active trip-created channel opens discovery controls instead of the create/join prompt. |
| Connectivity Guidance | Uses resolver-backed provider and shows channel-aware empty peer state. |
| Dashboard PTT | Offline or hybrid active trip routes to `/offline-channel/:channelId/ptt`; cloud PTT is used only for online cloud context. |
| Messages Hub | Offline Chat, Nearby Peers, and Channel Details shortcuts use the resolver-backed active trip channel. |
| Offline Chat | Composer stays mounted for active usable channels, including no-peer and zero-message states. |
| Mode Bottom Sheet | Uses the same resolver-backed active channel provider. |
| Debug | Added `/debug/active-channel` outside production only. |

## Verification Results

| Command | Result | Evidence |
| --- | --- | --- |
| `flutter analyze` | PASS | No issues found. |
| `flutter test test\phase14b_active_channel_resolution_test.dart` | PASS | 6 Phase 14B tests passed. |
| `flutter test` | PASS | 93 tests passed. |
| `flutter build apk --debug` | PASS | APK built at `build\app\outputs\flutter-apk\app-debug.apk`. |
| Install on Samsung `R58R85Q2HWH` | PASS | `adb install -r` returned success. |
| Install on Xiaomi `HAF6ZXGI5TINKJCA` | PASS | `adb install -r` returned success. |
| Device UI tree verification | BLOCKED | `uiautomator dump` returned `ERROR: null root node returned by UiTestAutomationBridge` on both devices after launch. Manual visual QA is still required. |

## Bug Status Updates

| Bug ID | Status |
| --- | --- |
| TL-QA-14A-007 | Fixed in code and regression tests; pending manual device confirmation. |
| TL-QA-14A-008 | Fixed in code and regression tests; pending manual device confirmation. |
| TL-QA-14A-009 | Fixed in code and regression tests; pending manual device confirmation. |
| TL-QA-14A-010 | Fixed in code and regression tests; pending manual device confirmation. |

## Manual Device QA Steps

1. Open the app with an existing or newly created Offline Only trip.
2. Confirm Home shows the active offline trip and channel code.
3. Open Offline Channels and confirm the same channel appears with active status.
4. Open Nearby Peers and confirm the channel code and discovery/advertising controls are visible.
5. Open Connectivity Guidance and confirm it shows channel-aware peer empty state, not the create/join prompt.
6. Tap PTT from Home and confirm it opens the offline PTT screen, not My Groups.
7. Open Messages -> Offline Channel Chat and confirm the composer is visible above the bottom nav.
8. Confirm no existing online group chat flow regressed.

## Remaining Blockers

- Physical UI confirmation is still needed because ADB UI tree capture returned null roots on both connected devices.
- Two-device Nearby/Connectivity/PTT behavior must still be verified manually after the UI flow is reachable.

