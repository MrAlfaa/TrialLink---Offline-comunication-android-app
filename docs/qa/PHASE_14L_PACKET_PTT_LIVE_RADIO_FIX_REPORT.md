# Phase 14L Packet Delivery, PTT, And Live Radio Fix Report

Date: 2026-05-10  
Build: `build\app\outputs\flutter-apk\app-debug.apk`  
Evidence folder: `docs\qa\phase14l_packet_ptt_live_radio\`

## Summary

Phase 14L repaired the offline packet path used by Nearby text delivery, ACKs, voice-note PTT, SOS/location packet routing, and Live Radio control packets.

The first suspected issue was valid: `OfflinePacketRouter` could start before the setup identity was hydrated. In that state the router could ignore incoming packets because no current actor was available. The fix now resolves the actor from auth access first and local identity second, refreshes auth access after local setup writes, and logs guarded debug diagnostics instead of silently dropping packets.

Physical two-phone QA then exposed two additional packet blockers:

1. Samsung Nearby BLE advertising failed because the endpoint name was 132 bytes, above the Nearby BLE endpoint limit.
2. Incoming offline text was received and ACKed, but not visible on the receiver because it was stored under the sender's local `channelId`. Each phone has a different local SQLite `channel_id` for the same shared channel code, so the receiver must store incoming messages under its own active channel id.

After these fixes, Xiaomi sent `phase14l_fixed` to Samsung on `TL-OFF-14L`; Samsung displayed the message and Xiaomi handled the ACK.

## Files Changed

| File | Purpose |
| --- | --- |
| `lib\core\offline\offline_packet_router.dart` | Added identity-safe router hydration, local identity fallback, and debug packet-drop diagnostics. |
| `lib\features\nearby\data\nearby_connections_transport.dart` | Added debug packet/payload boundary logging and payload transfer update diagnostics. |
| `lib\features\nearby\data\models\nearby_advertisement_payload.dart` | Added compact `TL2` endpoint format under the Nearby BLE endpoint limit while preserving `TL1` compatibility. |
| `lib\features\trip\presentation\trip_setup_screen.dart` | Refreshes auth access from local identity before invalidating providers and navigating after setup. |
| `lib\features\trip\presentation\trip_setup_wizard_screen.dart` | Refreshes auth access after trip create/join before route transition. |
| `lib\features\offline_chat\data\offline_chat_repository.dart` | Stores incoming text under the receiver's local active channel id/code, then sends ACK. |
| `lib\features\ptt\data\live_radio_audio_service.dart` | Added chunk error callback support for Live Radio fallback. |
| `lib\features\ptt\data\ptt_repository.dart` | Added voice-note transfer failure state, Live Radio packet size guard, and safe fallback stream. |
| `lib\features\ptt\presentation\ptt_controller.dart` | Listens for Live Radio failure and returns to voice-note PTT mode. |
| `test\phase14l_packet_delivery_ptt_live_radio_test.dart` | Added Phase 14L regression tests for router identity, diagnostics, advertisement size, incoming channel mapping, PTT, and Live Radio fallback. |

## Root Causes And Fixes

| Root cause | Evidence | Fix |
| --- | --- | --- |
| Router actor could be null before setup identity hydration. | Phase 14K packet timeout behavior and code inspection showed packets could be ignored before handlers ran. | Router now refreshes from auth access and local identity; setup flows call `refreshFromIdentity()` before navigation. |
| Nearby BLE endpoint info exceeded Android Nearby limit. | Samsung logcat showed `expected an endpointInfo of at most 131 bytes but got 132`. | Advertisement payload now uses compact `TL2|channel|shortUser|name|shortChannel|device` format and test verifies `<= 131`. |
| Receiver stored incoming text using sender local `channelId`. | First physical text test showed Samsung received text and sent ACK, but chat UI did not display it. | Incoming text insert now uses `activeChannel.channelId` and `activeChannel.channelCode` on the receiver. |

## Automated Verification

| Command | Result |
| --- | --- |
| `flutter analyze` | PASS, no issues. |
| `flutter test test\phase14l_packet_delivery_ptt_live_radio_test.dart` | PASS, 7 tests. |
| `flutter test test\phase14b_active_channel_resolution_test.dart` | PASS. |
| `flutter test test\phase14g_trip_channel_chat_context_test.dart` | PASS. |
| `flutter test test\offline_chat_layout_test.dart` | PASS. |
| `flutter test test\live_radio_experimental_test.dart` | PASS. |
| `flutter test` | PASS, 138 tests. |
| `flutter build apk --debug` | PASS, debug APK built. |

## Fresh Install And Device Details

| Device | Serial | Model | Android | Role |
| --- | --- | --- | --- | --- |
| Xiaomi | `HAF6ZXGI5TINKJCA` | `M2101K7BG` | 13 | Device A, created trip/channel. |
| Samsung | `R58R85Q2HWH` | `SM-A127F` | 13 | Device B, joined channel. |

Fresh install/reset flow:

```powershell
adb -s HAF6ZXGI5TINKJCA shell pm clear com.example.traillink
adb -s R58R85Q2HWH shell pm clear com.example.traillink
adb -s HAF6ZXGI5TINKJCA install -r -g build\app\outputs\flutter-apk\app-debug.apk
adb -s R58R85Q2HWH install -r -g build\app\outputs\flutter-apk\app-debug.apk
```

Setup used Manual Mode -> Offline. Xiaomi created trip `Phase 14L QA` with channel `TL-OFF-14L`; Samsung joined `TL-OFF-14L`.

Permissions granted/verified:

- Location: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- Nearby/Bluetooth: `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`
- Wi-Fi discovery: `NEARBY_WIFI_DEVICES`
- Microphone: `RECORD_AUDIO`

## Physical QA Results

| Area | Result | Notes |
| --- | --- | --- |
| Fresh install and setup | PASS | Both devices completed onboarding with clean local state. |
| Manual Offline mode | PASS | Home showed Offline Mode and Cloud Sync Paused. |
| Active trip/channel alignment | PASS | Both devices showed `Phase 14L QA` and `TL-OFF-14L` after setup/join. |
| Permission readiness | PASS | Required Android permissions were granted through install/runtime flow. |
| Nearby advertising before compact endpoint fix | FAIL, fixed | Samsung BLE advertise failed because endpoint info was 132 bytes. |
| Nearby advertising/discovery after compact endpoint fix | PASS | Both devices showed Advertising On, Discovery On, and peer discovery. |
| Nearby connection | PASS | Both devices reached connected state; heartbeat packets were exchanged and routed. |
| Offline text Xiaomi -> Samsung before receiver-channel fix | PARTIAL, fixed | Samsung received and ACKed packet but UI did not show message due local channel id mismatch. |
| Offline text Xiaomi -> Samsung after receiver-channel fix | PASS | Samsung displayed `phase14l_fixed`; Xiaomi received ACK and router logged handled ACK. |
| Duplicate packet handling | PASS | Logs showed duplicate relay/heartbeat packets ignored rather than inserted twice. |
| Voice-note PTT source behavior | PASS | Automated checks cover payload guard, failure state, and `voice_ack` contract. |
| Voice-note PTT physical send/playback | NOT TESTED | Physical PTT pass remains pending after text packet delivery was fixed. |
| Live Radio source behavior | PASS | Automated checks cover experimental gating, chunk guard, failure stream, and voice-note fallback. |
| Live Radio physical flow | NOT TESTED | Physical start/end/disconnect flow remains pending; Live Radio stayed experimental. |

## Packet Evidence

Important evidence files:

| Evidence | Meaning |
| --- | --- |
| `home-xiaomi.png`, `home-samsung.png` | Both devices after Manual Offline setup, showing active trip/channel. |
| `nearby-started-xiaomi.png`, `nearby-started-samsung.png` | Initial Nearby screen state before endpoint fix. |
| `logcat-nearby-samsung.txt` | Shows original Samsung Nearby endpoint length failure. |
| `nearby-patched-xiaomi.png`, `nearby-patched-samsung.png` | Nearby discovery after compact `TL2` endpoint patch. |
| `logcat-nearby-patched-xiaomi.txt`, `logcat-nearby-patched-samsung.txt` | Nearby packet and payload diagnostics after endpoint fix. |
| `nearby-connected-xiaomi.png`, `nearby-connected-samsung.png` | Both devices connected over Nearby. |
| `logcat-nearby-connected-xiaomi.txt`, `logcat-nearby-connected-samsung.txt` | Connection success, heartbeat send/receive, and router handling. |
| `offline-chat-xiaomi.png`, `offline-chat-samsung.png` | Offline chat opened on both devices. |
| `chat-after-xiaomi-to-samsung-xiaomi.png`, `chat-after-xiaomi-to-samsung-samsung.png` | Pre receiver-channel fix: packet delivered/ACKed but receiver UI missing message. |
| `logcat-chat-xiaomi-to-samsung-xiaomi.txt`, `logcat-chat-xiaomi-to-samsung-samsung.txt` | Pre-fix packet/ACK logs proving packet path reached router. |
| `chat-after-fixed-xiaomi.png`, `chat-after-fixed-samsung.png` | Final fixed result: Samsung shows `phase14l_fixed`; Xiaomi shows sent/ACKed message state. |
| `logcat-chat-after-fixed-xiaomi.txt`, `logcat-chat-after-fixed-samsung.txt` | Final packet diagnostics for text, ACK, payload success, and router handled events. |

Final fixed packet flow observed in logcat:

- Xiaomi: `[TrailLink][NearbyPacket] event=tx_start type=text`
- Samsung: `[TrailLink][NearbyPacket] event=rx_bytes type=text`
- Samsung: `[TrailLink][OfflinePacketRouter] event=handled type=text ... reason=Offline message received.`
- Samsung: `[TrailLink][NearbyPacket] event=tx_start type=ack`
- Xiaomi: `[TrailLink][NearbyPacket] event=rx_bytes type=ack`
- Xiaomi: `[TrailLink][OfflinePacketRouter] event=handled type=ack ... reason=Message delivery acknowledged.`

## UI And UX Notes

| Issue | Severity | Suggested fix |
| --- | --- | --- |
| Stale/duplicate peer rows can remain after reconnect. Xiaomi showed `2 Connected` while Samsung showed one connected card plus one lost/stale card. | Medium | Normalize peer rows by stable remote identity/channel and prune stale endpoint aliases when the same peer reconnects. |
| Old pre-fix Xiaomi message remained as `ack timeout`. | Low | Expected for a message sent before the receiver-channel fix; future retry UI could allow resending failed messages. |
| UIAutomator dumps on Xiaomi produced MIUI theme stack traces. | Low | Treat as device tooling noise unless it correlates with an app crash; screenshots/XML were still captured. |

## Remaining Risks

- Physical voice-note PTT send/playback still needs a dedicated two-phone pass now that text packet delivery is fixed.
- Physical Live Radio start/end/disconnect fallback still needs a dedicated two-phone pass; Live Radio remains experimental.
- Nearby reliability depends on Android Nearby services, radio state, distance, power saving, and OEM background restrictions.
- The compact `TL2` endpoint intentionally advertises shortened ids and display fields; full identity still travels in packet payloads and local state.
- Online/cloud verification is separate and should run only after offline P2P, PTT, and Live Radio physical checks pass.

## Demo Readiness Recommendation

Offline setup, active channel alignment, Nearby discovery/connect, text packet delivery, receiver UI insertion, and ACK routing are now suitable for a controlled demo.

Do not demo voice-note PTT or Live Radio as fully verified physical features yet. Run the remaining PTT and Live Radio physical pass first, then fix the stale peer row cleanup before broad user testing.
