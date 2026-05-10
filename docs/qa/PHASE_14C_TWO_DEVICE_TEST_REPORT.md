# TrailLink Phase 14C Two-Device Test Report

## Phase 14D Retest Addendum - 2026-05-09

Phase 14D fixed the active-channel resolver and retested the Xiaomi runtime path with a fresh APK. Results are evidence-based:

| Test Area | Result | Evidence |
|---|---:|---|
| Active offline trip on Xiaomi | PASS | `docs/qa/screenshots/phase14d/01-xiaomi-launch.png` and `08a-xiaomi-after-latest-install-ready.png` show `QA_P2P_Trip_A` / `TL-OFF-XVZG`. |
| Offline Channels list on Xiaomi | PASS | `docs/qa/screenshots/phase14d/03-xiaomi-offline-channels.png` shows the active channel. |
| Nearby Peers channel detection on Xiaomi | PASS | `docs/qa/screenshots/phase14d/04-xiaomi-nearby-active-channel.png` shows `TL-OFF-XVZG` and discovery controls. |
| Connectivity Guidance channel detection on Xiaomi | PASS | `docs/qa/screenshots/phase14d/05-xiaomi-connectivity-active-channel.png` shows `TL-OFF-XVZG` and no no-channel prompt. |
| Dashboard PTT route on Xiaomi | PASS | `docs/qa/screenshots/phase14d/06-xiaomi-offline-ptt-from-dashboard.png` shows offline PTT for `QA_P2P_Trip_A`. |
| Samsung joined channel state | PARTIAL | `docs/qa/screenshots/phase14d/02-samsung-launch.png` still shows old `TL-OFF-BL4C`; Samsung was not freshly rejoined to `TL-OFF-XVZG` after the fix. |
| Offline Chat composer | PARTIAL | Code was changed and tests pass, but a final valid Android screenshot was not captured because Xiaomi was reset into setup during route/deep-link attempts. |
| Two-device P2P discovery/chat/SOS/location/PTT | NOT TESTED | Requires both devices on the same active channel and manual tester interaction. |

Do not treat Phase 14D as a completed two-device P2P PASS. It confirms the active-channel runtime fixes on Xiaomi and leaves the actual peer transfer tests for a clean manual run.

Date: 2026-05-09

## Scope

Phase 14C was a QA/documentation-only pass for two-device offline channel and P2P readiness after Phase 14B. No feature work or UI redesign was performed.

Devices:

- Device A: Xiaomi `HAF6ZXGI5TINKJCA`
- Device B: Samsung `R58R85Q2HWH`

## Build And Install

| Step | Result | Evidence |
| --- | --- | --- |
| `flutter build apk --debug` | PASS | Built `build\app\outputs\flutter-apk\app-debug.apk`. |
| Install on Device A | PASS | `adb install -r` returned `Success`. |
| Install on Device B | PASS | `adb install -r` returned `Success`. |
| Screenshot capture method | PASS | Used `adb shell screencap -p` then `adb pull`; PNG signatures verified. |
| UI tree on Device A | PASS | UiAutomator readable, with MIUI theme warning noise. |
| UI tree on Device B | PASS after wake/unlock | Initial null root recovered after wake/unlock; UiAutomator readable. |

## Test A - Create And Join Offline Trip

Result: PARTIAL / FAIL

Observed:

- Device A created Offline Only trip `QA_P2P_Trip_A`.
- Device A channel code: `TL-OFF-XVZG`.
- Device A Home showed active trip/channel.
- Device A Offline Channels list showed `QA_P2P_Trip_A`, `TL-OFF-XVZG`, `Active`.
- Device B joined channel code `TL-OFF-XVZG` and opened channel detail showing `Offline Channel TL-OFF-XVZG`, `Active`.
- Device B Home still showed old active trip/channel `QA_Offline_Trip`, `TL-OFF-BL4C`.

Expected:

- Both devices show same active channel code.
- Both Home dashboards show the same trip/channel after join.

Actual:

- Device B can join/open `TL-OFF-XVZG` details, but Home active trip did not switch to the joined channel.

Screenshots:

- `docs/qa/screenshots/phase14c/01-device-a-home-active-trip.png`
- `docs/qa/screenshots/phase14c/02-device-b-channel-joined.png`
- `docs/qa/screenshots/phase14c/03-device-b-home-active-trip.png`
- `docs/qa/screenshots/phase14c/04-device-a-offline-channels-list.png`
- `docs/qa/screenshots/phase14c/05-device-b-offline-channel-detail.png`

## Test B - Nearby Discovery

Result: FAIL

Observed:

- Device A had active trip/channel `QA_P2P_Trip_A`, `TL-OFF-XVZG`.
- Device A Offline Channels list showed the channel.
- Opening Nearby Peers from Offline Channels still showed `Please create or join an offline channel first.`

Expected:

- Nearby Peers should show active channel code and discovery/advertising controls.

Actual:

- Nearby Peers did not resolve the active channel and could not start discovery.

Screenshot:

- `docs/qa/screenshots/phase14c/06-device-a-nearby-no-channel-fail.png`

## Test C - Offline Text Chat

Result: FAIL

Observed:

- Device A Messages Hub showed `QA_P2P_Trip_A`, `TL-OFF-XVZG`.
- Tapping `Offline Channel Chat` produced a blank Flutter surface.
- The offline chat composer was not visible.

Expected:

- Offline Chat should show header, message list, no-peer queue hint, text composer, and send button.

Actual:

- Blank app content; no composer.

Screenshot:

- `docs/qa/screenshots/phase14c/09-device-a-offline-chat-result.png`

Logs:

- `docs/qa/logs/phase14c/device-a-xiaomi-logcat-tail.txt`

## Test D - Offline SOS

Result: BLOCKED

Reason:

- P2P discovery/connect was blocked by Nearby Peers failing to resolve the active channel.

## Test E - Offline Location

Result: BLOCKED

Reason:

- P2P discovery/connect was blocked. Location record transfer to the peer could not be tested.

## Test F - Voice-Note PTT

Result: FAIL

Observed:

- Device A active offline trip/channel existed.
- Dashboard PTT card was tapped from Offline Tools.
- App opened Trip Setup Wizard instead of offline PTT.

Expected:

- Dashboard PTT should open `/offline-channel/:channelId/ptt`.

Actual:

- App routed to trip setup.

Screenshot:

- `docs/qa/screenshots/phase14c/08-device-a-ptt-routes-trip-setup-fail.png`

## Test G - Live Radio Experimental

Result: NOT TESTED

Reason:

- Live Radio is gated by settings and connected peers. Peer connection could not be established because Nearby Peers did not resolve the active channel.

## Test H - Disconnect Presence

Result: BLOCKED

Reason:

- Peer discovery/connect could not be started, so connected-to-disconnected presence transition could not be tested.

## Test I - Offline Media Guard

Result: BLOCKED

Reason:

- Offline Chat opened to a blank surface; media guard could not be inspected.

## Test J - Mode Switch

Result: NOT TESTED

Reason:

- Phase 14C was stopped after the active-channel failures blocked the P2P path.

## Summary

Overall result: NOT READY for two-device P2P demo.

Critical blockers:

- Nearby Peers still cannot resolve an active trip-created channel on device.
- Connectivity Guidance still shows no-channel copy even after offline trip creation.
- Dashboard PTT still fails to open offline PTT in the tested flow.
- Offline Chat from Messages Hub renders blank instead of showing composer.
- Device B joining a channel does not update Home active trip/channel to the joined code.

Recommended next phase:

- Phase 14D runtime active-channel repair and navigation fix, focused on the specific device-evidenced failures above.
