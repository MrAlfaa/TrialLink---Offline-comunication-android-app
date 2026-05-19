# Phase 14M Live PTT, SOS, And Location QA Report

Date: 2026-05-10  
Workspace: `E:\PROJECTS\Out Source Project\TrailLink-Android Flutter App`

## Summary

Phase 14M fixed four offline-first reliability problems found during manual two-phone QA:

- PTT voice-note packets were persisted on receive, but the PTT screen did not refresh because it only listened for Live Radio router notices.
- Reopening PTT could reuse a disposed shared `PttRepository`/`AudioRecorder`, causing `PlatformException(record, Recorder has not yet been created or has already been disposed.)`.
- Live Radio selection could fall back to Voice-note PTT automatically when eligibility failed, which made the selected tab unstable.
- Stale persisted Nearby endpoints could make PTT report a successful send even when the live transport was no longer connected.

The code now refreshes PTT for voice-note, voice-ACK, floor, and Live Radio notices; keeps Live Radio selected while showing inline failure reasons; maps incoming Live Radio state to the receiver's active local channel; checks live Nearby transport connectivity before sending packets; and keeps offline Map location sharing bound to the active channel.

## Files Changed

- `lib/features/ptt/presentation/ptt_screen.dart`
- `lib/features/ptt/presentation/ptt_controller.dart`
- `lib/features/ptt/data/ptt_repository.dart`
- `lib/features/ptt/data/ptt_floor_controller.dart`
- `lib/features/nearby/data/nearby_packet_transport.dart`
- `lib/features/nearby/data/nearby_connections_transport.dart`
- `lib/features/nearby/data/nearby_repository.dart`
- `lib/features/offline_chat/data/offline_chat_repository.dart`
- `lib/features/offline_chat/data/offline_message_local_data_source.dart`
- `lib/features/offline_chat/presentation/offline_chat_controller.dart`
- `lib/features/location/presentation/location_controller.dart`
- `test/phase14m_live_ptt_sos_location_test.dart`

## Root Causes And Fixes

### PTT Realtime Refresh

Root cause: `PttScreen` refreshed only when `OfflinePacketRouter.lastNotice` contained `live` / `Live Radio`. Notices such as `Voice note received.` and `Voice note delivered.` updated SQLite but did not trigger a screen reload.

Fix: added `shouldRefreshPttForOfflineNotice()` and wired it into `PttScreen`. It now refreshes for voice-note receive, voice ACK/delivered, PTT floor request/release notices, and Live Radio receive/end notices.

### PTT Recorder Lifecycle

Root cause: `PttController.dispose()` disposed `PttRepository`, but `pttRepositoryProvider` was a shared provider. After leaving and reopening PTT, the same repository could hold a disposed `AudioRecorder`.

Fix: made `pttRepositoryProvider` provider-owned with `Provider.autoDispose` and `ref.onDispose(repository.dispose)`. `PttController` now stops active audio but no longer disposes the shared repository manually. User-facing errors are normalized to remove prefixes such as `Bad state:`.

### Live Radio Tab Stability

Root cause: Live Radio eligibility failure and stream failure changed `voiceMode` back to `voiceNote`.

Fix: Live Radio stays selected on blocked/failed states. The screen shows the reason inline and disables/guards hold actions instead of changing tabs without user action.

### Live Radio Receiver Context

Root cause: incoming Live Radio floor/session state used sender packet channel ids in some paths.

Fix: incoming Live Radio start/end and PTT floor packets now use the receiver's active `OfflineChannelModel.channelId` for local state.

### ACK And Stale Endpoint Handling

Root cause: text ACK timeout logic could mark a stale in-memory message as timed out. PTT/packet sending also trusted persisted `nearby_peers` rows after app restart/reinstall.

Fix: offline chat ACK timeout re-reads the message from SQLite before marking timeout. Nearby packet sends now reject endpoints that are not currently connected in the live transport, so stale SQLite connection rows become a visible send failure instead of a misleading success.

### Offline Location Sharing

Root cause: root `/map` in offline mode could save local GPS without resolving the active offline channel.

Fix: `LocationController.shareLocation()` now resolves the active offline channel when the map is opened without an explicit `offlineChannelId`, then sends peer location packets under that channel.

## Automated Verification

| Command | Result |
| --- | --- |
| `flutter analyze` | PASS, no issues found |
| `flutter test test\phase14m_live_ptt_sos_location_test.dart` | PASS, 8 tests |
| `flutter test test\phase14l_packet_delivery_ptt_live_radio_test.dart` | PASS, 7 tests |
| `flutter test test\live_radio_experimental_test.dart` | PASS, 3 tests |
| `flutter test` | PASS, 146 tests |
| `flutter build apk --debug` | PASS, built `build\app\outputs\flutter-apk\app-debug.apk` |

The final APK was installed on both physical devices with `adb install -r -g`.

## Device QA

| Device | Serial | State |
| --- | --- | --- |
| Xiaomi | `HAF6ZXGI5TINKJCA` | Installed, active offline channel `TL-OFF-E7G8` |
| Samsung | `R58R85Q2HWH` | Installed, active offline channel `TL-OFF-E7G8` |

### Physical Results

| Area | Result | Evidence |
| --- | --- | --- |
| Home active channel consistency | PASS | `docs/qa/phase14m_live_ptt_sos_location/after-reinstall-xiaomi.xml`, `after-reinstall-samsung.xml` |
| PTT opens for active offline channel | PASS | `fixed-ptt-ready-xiaomi.xml`, `fixed-ptt-ready-samsung.xml` |
| Live Radio tab stays selected | PASS | `live-tab-xiaomi.xml`, `live-tab-samsung.xml` |
| PTT recorder lifecycle after reopen | PASS | `ptt-after-lifecycle-fix-xiaomi.xml`, `logcat-after-lifecycle-fix-xiaomi.txt` |
| Stale endpoint failure is visible | PASS | `guard-ptt-after-send-xiaomi.xml`, `guard-ptt-after-send-xiaomi.png` |
| Two-way realtime voice-note delivery | PARTIAL | Sender recording works; receiving was not proven because the live Nearby connection was not available during the final retest |
| Offline SOS physical stress flow | NOT TESTED | Source contracts verified; real SOS flow deferred to avoid uncontrolled emergency-style alerting during unstable peer state |
| Offline location physical sharing | NOT TESTED | Source contracts verified; receiver marker/card requires a live peer connection |
| Live Radio real stream audio | PARTIAL | Tab stability and gating verified; real near-live stream requires live connected peer state |

## Evidence Index

Key evidence files:

- `docs/qa/phase14m_live_ptt_sos_location/ptt-after-xiaomi-send-xiaomi.xml`
- `docs/qa/phase14m_live_ptt_sos_location/logcat-after-xiaomi-send-xiaomi.txt`
- `docs/qa/phase14m_live_ptt_sos_location/ptt-after-lifecycle-fix-xiaomi.xml`
- `docs/qa/phase14m_live_ptt_sos_location/logcat-after-lifecycle-fix-xiaomi.txt`
- `docs/qa/phase14m_live_ptt_sos_location/guard-ptt-after-send-xiaomi.xml`
- `docs/qa/phase14m_live_ptt_sos_location/guard-ptt-after-send-xiaomi.png`
- `docs/qa/phase14m_live_ptt_sos_location/live-tab-samsung.xml`
- `docs/qa/phase14m_live_ptt_sos_location/nearby-open-xiaomi.xml`
- `docs/qa/phase14m_live_ptt_sos_location/nearby-open-samsung.xml`

Note: `guard-ptt-after-send-xiaomi.xml` was captured before the final wording cleanup that strips `Bad state:` from PTT errors. The final installed APK contains the wording cleanup.

## Bugs Found

| ID | Severity | Status | Details |
| --- | --- | --- | --- |
| TL-QA-14M-001 | High | Fixed | PTT screen did not refresh for incoming voice-note/voice-ACK router notices. |
| TL-QA-14M-002 | High | Fixed | Reopened PTT could reuse disposed recorder and fail recording. |
| TL-QA-14M-003 | Medium | Fixed | Live Radio tab auto-switched back to Voice-note PTT on eligibility/failure. |
| TL-QA-14M-004 | High | Fixed | PTT could send to stale persisted endpoint rows and show misleading send state. |
| TL-QA-14M-005 | Medium | Fixed | Root offline Map share did not always resolve the active channel. |
| TL-QA-14M-006 | Medium | Open QA | Real two-way PTT receive and voice ACK still needs a fresh run after Nearby peers are reconnected live. |

## Remaining Risks

- Nearby transport state is volatile after reinstall/restart. A peer shown in local channel membership is not necessarily a live Nearby endpoint.
- `sendBytesPayload()` only confirms enqueue, not receiver delivery. Voice-note delivery must still rely on `voice_ack` for final delivered status.
- Live Radio remains experimental and should stay gated until repeated two-device stream tests pass.
- SOS and location sharing source contracts are fixed, but full real-device stress QA still requires a stable live peer connection and controlled QA wording: `QA TEST SOS - NO REAL EMERGENCY`.

## Demo Readiness

Not ready for a full two-phone demo of every offline feature yet. The code-level fixes are in place and verified, and PTT now fails visibly instead of silently when the live Nearby endpoint is stale. Before demo, run a fresh two-phone session where both devices explicitly start Nearby advertising/discovery after the final APK install, confirm live peer connection in the Nearby screen, then repeat:

1. Voice-note PTT Xiaomi to Samsung.
2. Voice-note PTT Samsung to Xiaomi.
3. Live Radio start/end both directions.
4. QA-only SOS send/acknowledge/map tracking.
5. Location share both directions.
