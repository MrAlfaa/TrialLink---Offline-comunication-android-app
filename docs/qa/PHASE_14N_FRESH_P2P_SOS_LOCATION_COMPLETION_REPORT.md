# Phase 14N Fresh P2P, PTT, Live Radio, SOS, And Location Completion Report

Date: 2026-05-10  
Build: `build\app\outputs\flutter-apk\app-debug.apk`  
Package: `com.example.traillink`  
Mode tested first: Manual Mode -> Offline

## Summary

Phase 14N performed a fresh two-phone QA run for offline P2P behavior and found a real packet boundary defect after Nearby reported a live connection. Samsung could send an offline chat packet to Xiaomi, but Samsung later showed `ack timeout`, and Xiaomi could not send a packet back to Samsung. The Xiaomi chat header also showed `0 peers nearby` while the Nearby screen had already shown a connected peer.

The root cause is that offline feature senders were using persisted SQLite peer rows as their source of truth. The Nearby screen had the live transport connection in memory, but SQLite was either missing the connected row on one device or contained stale rows on another path. That split caused chat/PTT/SOS/location senders to see the wrong peer state, so ACK return packets and outbound packets could be skipped or sent to stale endpoints.

The fix centralizes connected-peer resolution in `NearbyRepository.connectedPeers(channelCode)`. It reads live connected peers from `NearbyConnectionsTransport`, persists those live peers opportunistically, marks stale persisted connected peers lost, and then returns the live peers to offline chat, PTT, Live Radio eligibility, SOS, and location sharing.

## Files Changed

- `lib/features/nearby/data/nearby_packet_transport.dart`
- `lib/features/nearby/data/nearby_connections_transport.dart`
- `lib/features/nearby/data/nearby_repository.dart`
- `lib/features/nearby/presentation/nearby_controller.dart`
- `lib/features/offline_chat/data/offline_chat_repository.dart`
- `lib/features/offline_chat/data/offline_message_local_data_source.dart`
- `lib/features/offline_chat/presentation/offline_chat_controller.dart`
- `lib/features/ptt/data/ptt_repository.dart`
- `lib/features/ptt/data/live_radio_eligibility_service.dart`
- `lib/features/ptt/data/ptt_floor_controller.dart`
- `lib/features/ptt/presentation/ptt_controller.dart`
- `lib/features/ptt/presentation/ptt_screen.dart`
- `lib/features/location/data/location_repository.dart`
- `lib/features/location/presentation/location_controller.dart`
- `lib/features/emergency/data/emergency_repository.dart`
- `test/phase14m_live_ptt_sos_location_test.dart`
- `test/phase14n_fresh_p2p_sos_location_test.dart`

## Implementation Details

### Live Nearby peer boundary

- Added `isConnected(endpointId)` and `connectedPeersForChannel(channelCode)` to `NearbyPacketTransport`.
- Implemented those methods in `NearbyConnectionsTransport` from the transport-owned `_peers` map.
- Updated `NearbyRepository` to subscribe to peer discovery, connection, and lost streams so live transport state is persisted even when the Nearby screen is not the active UI.
- Updated `NearbyRepository.sendPacket()` to reject stale endpoints before send, mark them lost, and surface a clear failure instead of silently trusting old SQLite rows.
- Updated `NearbyRepository.connectedPeers()` to return live connected transport peers and mark stale persisted connected peers lost.

### Offline chat and ACK protection

- Offline chat now gets connected peers through `NearbyRepository.connectedPeers()`.
- ACK timeout marking re-reads the persisted message before changing status, so a delayed ACK cannot be overwritten by stale controller state.
- Debug-only offline chat ACK diagnostics were added around ACK transmit, receive, and timeout decisions.

### PTT and Live Radio

- Voice-note PTT send uses the same live Nearby peer resolver before deciding whether a transfer failed or is simply queued.
- Live Radio eligibility uses the live Nearby peer resolver when available, with SQLite only as a no-nearby fallback.
- Incoming Live Radio start/end packets are stored against the receiver's active local channel, not the sender's channel id.
- Live Radio keeps the Live Radio tab selected when blocked or failed, while clearing streaming state safely.

### SOS and location sharing

- Offline SOS send, SOS ACK send, SOS ACK metrics, and offline location share now use the shared live Nearby peer resolver.
- Root offline map sharing continues to resolve the active offline channel before creating the location packet.

## Verification Results

| Command | Result |
| --- | --- |
| `flutter analyze` | PASS, no issues found |
| `flutter test test\phase14n_fresh_p2p_sos_location_test.dart` | PASS, 6 tests |
| `flutter test test\phase14m_live_ptt_sos_location_test.dart` | PASS, 8 tests |
| `flutter test test\phase14l_packet_delivery_ptt_live_radio_test.dart` | PASS, 7 tests |
| `flutter test test\live_radio_experimental_test.dart` | PASS, 3 tests |
| `flutter test` | PASS, 152 tests |
| `flutter build apk --debug` | PASS |

## Device Details

| Device | Serial | Model | Android | Status |
| --- | --- | --- | --- | --- |
| Device A | `HAF6ZXGI5TINKJCA` | Xiaomi `M2101K7BG` | Android 13 / SDK 33 | Initially tested, later disconnected from ADB |
| Device B | `R58R85Q2HWH` | Samsung `SM-A127F` | Android 13 / SDK 33 | Tested and patched APK installed |

## Fresh Install And Setup Evidence

Both devices were cleared and installed fresh before the initial Phase 14N run:

```powershell
adb -s HAF6ZXGI5TINKJCA shell pm clear com.example.traillink
adb -s R58R85Q2HWH shell pm clear com.example.traillink
adb -s HAF6ZXGI5TINKJCA install -r -g build\app\outputs\flutter-apk\app-debug.apk
adb -s R58R85Q2HWH install -r -g build\app\outputs\flutter-apk\app-debug.apk
```

Setup used Manual Mode -> Offline. Xiaomi created the offline channel `TL-OFF-14N`; Samsung joined `TL-OFF-14N`.

## Physical QA Results

| Area | Result | Evidence | Notes |
| --- | --- | --- | --- |
| Fresh install and setup | PASS | `home-xiaomi.png`, `home-samsung.png` | Both devices reached Home with `TL-OFF-14N`. |
| Channel consistency | PASS | `home-*.png`, `messages-*.png`, `nearby-open-*.png` | Home/Messages/Nearby showed the same channel before packet testing. |
| Nearby discovery | PASS | `nearby-after-discovery-xiaomi.png`, `nearby-after-discovery-samsung.png` | Devices discovered each other. |
| Nearby connection | PASS | `nearby-after-connect-xiaomi.png`, `nearby-after-connect-samsung.png` | Both showed one connected peer in Nearby. |
| Offline chat UI | PASS | `chat-open-xiaomi.png`, `chat-open-samsung.png` | Composer visible; Samsung showed 1 peer, Xiaomi incorrectly showed 0 peers. |
| Offline chat Samsung -> Xiaomi | PARTIAL | `chat-btoa-xiaomi.png`, `chat-atob-samsung.png` | Xiaomi received Samsung's text, but Samsung later showed ACK timeout. |
| Offline chat Xiaomi -> Samsung | FAIL before patch | `chat-atob-xiaomi.png`, `chat-atob-samsung.png` | Xiaomi stayed pending and Samsung did not receive that message. |
| Voice-note PTT | BLOCKED after patch | Xiaomi not visible to ADB | Source fix applied to same peer boundary; physical retest still needed. |
| Live Radio | BLOCKED after patch | Xiaomi not visible to ADB | Source fix applied to eligibility and fallback; physical retest still needed. |
| Offline SOS | BLOCKED after patch | Xiaomi not visible to ADB | SOS send/ack now uses live peer resolver; physical retest still needed. |
| Location sharing | BLOCKED after patch | Xiaomi not visible to ADB | Location send now uses live peer resolver; physical retest still needed. |
| Patched Samsung reinstall | PASS | `patched-settled-samsung.png`, `patched-settled-samsung.xml` | Samsung retained `TL-OFF-14N` after patched APK install. |

## Evidence Index

Evidence folder: `docs\qa\phase14n_fresh_p2p_sos_location\`

Key files:

- `home-xiaomi.png`
- `home-samsung.png`
- `messages-xiaomi.png`
- `messages-samsung.png`
- `nearby-after-discovery-xiaomi.png`
- `nearby-after-discovery-samsung.png`
- `nearby-after-connect-xiaomi.png`
- `nearby-after-connect-samsung.png`
- `chat-open-xiaomi.png`
- `chat-open-samsung.png`
- `chat-btoa-xiaomi.png`
- `chat-atob-xiaomi.png`
- `chat-atob-samsung.png`
- `logcat-chat-xiaomi.txt`
- `logcat-chat-samsung.txt`
- `patched-settled-samsung.png`
- `patched-settled-samsung.xml`
- `patched-logcat-samsung.txt`

## Bugs Found

### TL-QA-14N-001: Live Nearby state not shared with packet senders

Severity: High  
Status: Fixed in source, needs two-phone retest  

Steps:

1. Fresh install both phones.
2. Join both phones to `TL-OFF-14N`.
3. Connect peers in Nearby.
4. Open offline chat.
5. Send text both directions.

Expected:

- Both phones show one nearby peer in chat.
- Messages deliver both directions.
- Sender changes to delivered/acknowledged only after ACK.

Actual:

- Xiaomi chat showed `0 peers nearby` while Nearby showed connected.
- Samsung -> Xiaomi was received, but Samsung showed ACK timeout.
- Xiaomi -> Samsung stayed pending and was not received.

Fix:

- Added live connected-peer lookup to `NearbyPacketTransport` and `NearbyRepository`.
- Rewired chat/PTT/SOS/location/Live Radio eligibility to use `NearbyRepository.connectedPeers()`.
- Stale SQLite connected rows are marked lost when no live transport endpoint exists.

## Remaining QA Required

The patched APK was installed on Samsung, but Xiaomi was no longer visible in `adb devices` after the patch build. Because two-phone P2P depends on both live devices, the final physical validation is still required:

1. Reconnect Xiaomi `HAF6ZXGI5TINKJCA` and confirm it appears in `adb devices -l`.
2. Install the patched APK on Xiaomi without clearing data if the `TL-OFF-14N` setup is still present.
3. Start Nearby advertising/discovery on both phones.
4. Confirm chat on both phones shows one peer.
5. Retest text A -> B and B -> A.
6. Retest voice-note PTT both directions without manual refresh.
7. Retest Live Radio tab stability, connected stream, and disconnect fallback.
8. Retest SOS with `QA TEST SOS - NO REAL EMERGENCY`.
9. Retest location sharing both directions.

## Demo Readiness

Not ready for a real-user demo until the patched APK is retested with both phones connected. Source verification and the root-cause patch are complete, but packet-dependent physical tests must be repeated after Xiaomi is reconnected.
