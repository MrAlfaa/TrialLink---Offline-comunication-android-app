# Phase 14K Active Context P2P Fix Report

Date: 2026-05-10  
Build: `build\app\outputs\flutter-apk\app-debug.apk`  
Evidence folder: `docs\qa\phase14k_active_context_p2p\`

## Summary

Phase 14K fixed the confirmed active-channel context bug where a newly joined offline channel could become active in `offline_channels`, while `ActiveTripContext` still pointed to an older trip/channel. That stale context made Messages, Nearby, Channel Details, and Offline Chat disagree, and could make chat appear read-only or composerless.

Fresh two-phone QA now confirms that both phones can complete Manual Offline setup, create/join the same offline channel, and keep Home, Messages, Channel Details, Nearby, and Offline Chat aligned to the same channel code: `TL-OFF-14K4`.

The retest also exposed a separate P2P packet-delivery bug: Nearby discovery and connection succeed on both phones, but text packets sent over the connected Nearby session do not arrive on the other device and time out waiting for ACK.

## Root Cause

The broken behavior came from multiple join/activate paths writing channel state directly through `TripSessionRepository` or `OfflineChannelRepository`. Those paths could mark an offline channel as globally active without also updating:

- `trip_sessions.status`
- `trip_sessions.offline_channel_id`
- `trip_sessions.active_channel_id`
- `trip_sessions.channel_code`
- `offline_channels.trip_id`
- `offline_channels.is_primary`
- `chat_rooms.is_active`
- `active_offline_channel_id`

After that split, screens derived from `ActiveTripContext` could show the old trip/channel while channel details showed the newer globally active channel.

## Fixed Behavior

- Joining an offline channel now goes through `TripContextService.joinOfflineChannelAsActiveTrip(...)`.
- Activating an existing channel now goes through `TripContextService.activateOfflineChannelAsTrip(...)`.
- Activation sets exactly one active trip, one active offline channel, and one active default `General` chat.
- `getActiveTripContext()` reconciles a stale active trip if a different globally active usable channel is found.
- Setup and channel UI paths invalidate the active context providers after writing state.
- Trip setup create/join now uses inline forms instead of modal sheets to avoid debug red-screen assertions during route/provider teardown.

## Files Changed

- `lib/features/trip_context/data/trip_context_service.dart`
- `lib/features/offline_channel/presentation/offline_channel_controller.dart`
- `lib/features/offline_channel/presentation/join_offline_channel_screen.dart`
- `lib/features/offline_channel/presentation/offline_channel_details_screen.dart`
- `lib/features/offline_channel/presentation/offline_channel_list_screen.dart`
- `lib/features/trip/presentation/trip_setup_screen.dart`
- `lib/features/trip/presentation/trip_setup_wizard_screen.dart`
- `test/phase14g_trip_channel_chat_context_test.dart`
- `test/phase14b_active_channel_resolution_test.dart`
- `test/lock_trip_nearby_regression_test.dart`

## Source Verification

| Command | Result | Evidence |
| --- | --- | --- |
| `flutter analyze` | PASS, no issues | `flutter-analyze-final.txt` |
| `flutter test test\phase14b_active_channel_resolution_test.dart test\phase14g_trip_channel_chat_context_test.dart test\offline_chat_layout_test.dart` | PASS, 27 tests | `flutter-focused-tests-final.txt` |
| `flutter test` | PASS, 131 tests | `flutter-test-final.txt` |
| `flutter build apk --debug` | PASS | `flutter-build-debug-final.txt` |

## Fresh Install And Device Details

| Device | Serial | Model | Android | Role |
| --- | --- | --- | --- | --- |
| Xiaomi | `HAF6ZXGI5TINKJCA` | `Xiaomi M2101K7BG` | 13 | Device A, created trip/channel |
| Samsung | `R58R85Q2HWH` | `samsung SM-A127F` | 13 | Device B, joined channel |

Fresh install commands were run with uninstall/reinstall and permission grants. ADB reverse was configured for later cloud checks:

- `HAF6ZXGI5TINKJCA`: `UsbFfs tcp:5000 tcp:5001`
- `R58R85Q2HWH`: `UsbFfs tcp:5000 tcp:5001`

Manual Offline setup was used first to remove backend/cloud noise.

## Active Channel Evidence

| Screen | Xiaomi | Samsung | Result |
| --- | --- | --- | --- |
| Home | `xiaomi-home-after-finish.png/xml` shows `QA14KTrip`, `TL-OFF-14K4`, Offline Mode | `samsung-home-after-finish.png/xml` shows `QA14KTrip`, `TL-OFF-14K4`, Offline Mode | PASS |
| Messages | `messages-HAF6ZXGI5TINKJCA.png/xml` shows `QA14KTrip`, `TL-OFF-14K4` | `messages-R58R85Q2HWH.png/xml` shows `QA14KTrip`, `TL-OFF-14K4` | PASS |
| Channel Details | `channel-details-HAF6ZXGI5TINKJCA.png/xml` shows active `TL-OFF-14K4` | `channel-details-R58R85Q2HWH.png/xml` shows active `TL-OFF-14K4` | PASS |
| Nearby | `nearby-discovery-retry-HAF6ZXGI5TINKJCA.png/xml` shows active `TL-OFF-14K4` | `nearby-discovery-retry-R58R85Q2HWH.png/xml` shows active `TL-OFF-14K4` | PASS |
| Offline Chat | `offline-chat-HAF6ZXGI5TINKJCA.png/xml` shows composer and `TL-OFF-14K4` | `offline-chat-R58R85Q2HWH.png/xml` shows composer and `TL-OFF-14K4` | PASS |

## Two-Phone Retest Matrix

| ID | Scenario | Result | Notes / Evidence |
| --- | --- | --- | --- |
| SETUP-01 | Fresh launch after app reset/reinstall | PASS | Setup appeared on both phones. |
| SETUP-02 | Manual Mode -> Offline setup | PASS | Both phones completed setup without backend dependency. |
| SETUP-03 | Device A creates offline trip/channel | PASS | Xiaomi created `QA14KTrip`, `TL-OFF-14K4`. |
| SETUP-04 | Device B joins same channel code | PASS | Samsung joined `TL-OFF-14K4`. |
| CTX-01 | Home/Messages/Nearby/Channel Details/Chat use same channel | PASS | All checked screens show `TL-OFF-14K4`. |
| CHAT-01 | Offline chat composer visible with zero peers | PASS | Composer/input/send visible on both phones. |
| CHAT-02 | Zero-peer send queues locally | PASS | Xiaomi `QA14KZeroPeer` saved locally and later marked `sent` after peer connection. |
| NEAR-01 | Start advertising on both phones | PASS | Both show `Advertising On`. |
| NEAR-02 | Start discovery on both phones | PASS | Both show `Discovery On`. |
| NEAR-03 | Discover peer on same channel | PASS | Xiaomi sees `QA14KB`; Samsung sees `QA14KA`. |
| NEAR-04 | Connect peers | PASS | Both show `1 Connected`; evidence `nearby-connect-attempt-*.xml`. |
| CHAT-03 | Xiaomi sends connected text to Samsung | FAIL | Sender shows `QA14KAtoBl` then `ack timeout`; Samsung does not show message. |
| CHAT-04 | Samsung sends connected text to Xiaomi | FAIL | Sender shows `QA14KBto` then `ack timeout`; Xiaomi does not show message. |
| PTT-01 | Voice-note PTT transfer | BLOCKED | Blocked by same packet-delivery/ACK failure found in text chat. |
| SOS-01 | Offline SOS packet delivery | BLOCKED | Not sent during this controlled run because text packet transfer failed. |
| MAP-01 | Map/location P2P share | NOT TESTED | Deferred after packet-delivery failure. |
| CLOUD-01 | Manual Online / cloud chat | NOT TESTED | Phase 14K first pass focused Manual Offline; backend reverse is configured for later cloud pass. |

## Bugs Found

### TL-QA-14K-001 - Connected Nearby text packets time out without receiver delivery

Severity: High  
Area: Offline chat / Nearby packet transport  
Status: Open  

Steps:

1. Fresh install both phones.
2. Use Manual Mode -> Offline.
3. Device A creates `QA14KTrip` / `TL-OFF-14K4`.
4. Device B joins `TL-OFF-14K4`.
5. Start advertising and discovery on both phones.
6. Connect Samsung to Xiaomi.
7. Open Offline Chat on both phones.
8. Send text from Xiaomi to Samsung, then from Samsung to Xiaomi.

Expected:

- Receiver shows the message.
- Sender status advances from pending/sent to delivered/acknowledged if ACK is supported.

Actual:

- Both devices show `1 Connected`.
- Sender saves message locally and marks it `ack timeout`.
- Receiver never displays the message.

Evidence:

- `nearby-connect-attempt-HAF6ZXGI5TINKJCA.xml`
- `nearby-connect-attempt-R58R85Q2HWH.xml`
- `chat-a-to-b-sent-HAF6ZXGI5TINKJCA.xml`
- `chat-a-to-b-sent-R58R85Q2HWH.xml`
- `chat-b-to-a-sent-HAF6ZXGI5TINKJCA.xml`
- `chat-b-to-a-sent-R58R85Q2HWH.xml`
- `logcat-xiaomi-final.txt`
- `logcat-samsung-final.txt`

Likely fix area:

- `NearbyConnectionsTransport.sendPacket(...)` and payload receive callback.
- `OfflinePacketRouter` packet stream handling and active actor/channel guards.
- Add guarded debug logs for `sendBytesPayload`, `onPayLoadRecieved`, packet parse, channel reject, and ACK send/receive so the next run can identify packet-send vs packet-receive vs router-ignore precisely.

### TL-QA-14K-002 - Nearby peer action card can place Connect below the fold on Xiaomi

Severity: Medium  
Area: Nearby Peers UI  
Status: Open  

The Xiaomi peer card showed the discovered Samsung peer, but the `Connect` action was below the first visible viewport and required scrolling. For real users, the primary action should remain visible, sticky, or the peer card should be more compact.

Evidence:

- `nearby-discovery-retry-HAF6ZXGI5TINKJCA.png/xml`

### TL-QA-14K-003 - Chat send button is easy to miss after keyboard resize in ADB/manual tapping

Severity: Low to Medium  
Area: Offline Chat UI  
Status: Open  

When the keyboard opens, the composer moves and the send button coordinate changes. This is expected layout behavior, but the icon-only send button has no visible UIAutomator content-desc. Add a visible semantic label or tooltip-compatible semantics so QA automation can tap it reliably by selector.

Evidence:

- `chat-a-to-b-HAF6ZXGI5TINKJCA.xml`
- `chat-b-to-a-R58R85Q2HWH.xml`

### TL-QA-14K-004 - Xiaomi UIAutomator emits MIUI theme compatibility FileNotFoundException

Severity: Low  
Area: Test environment  
Status: External/device noise  

UI dumps still succeed, but Xiaomi prints MIUI `theme_compatibility.xml` errors during `uiautomator dump`. This appears to be device/ROM noise, not an app failure.

## UI Improvement Notes

- The setup agreement step still has nested scrolling behavior; users may miss the bottom acceptance controls on taller pages.
- Setup primary actions sit very low on gesture-navigation devices. A fixed bottom action area with safe-area padding would make this more reliable.
- Nearby peer cards should expose the primary `Connect` action without requiring scroll when there is only one discovered peer.
- Offline chat send button should expose a stable Android semantics label/content description.
- Transport failures need user-visible retry/detail wording. `ack timeout` is useful for QA but too technical as the only real-user signal.

## Final Recommendation

Phase 14K active context is fixed and ready to keep. The app is not ready for a real two-phone demo of offline messaging/PTT/SOS until TL-QA-14K-001 is fixed, because discovery/connect works but payload delivery does not complete.

Recommended next fix:

1. Add guarded debug diagnostics in the Nearby packet send/receive/router path.
2. Reproduce with the same two phones and `TL-OFF-14K4` style Manual Offline flow.
3. Fix packet delivery or router rejection.
4. Retest text chat, then PTT, SOS, and location share.
