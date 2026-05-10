# Phase 14J Two-Device P2P QA Report

Date: 2026-05-10  
Tester: Codex physical-device QA run  
Project: TrailLink Android Flutter App  
Evidence folder: `docs/qa/phase14j_two_device/`

## Executive Summary

This two-phone fresh QA run is **not ready for demo or real-user testing**.

The APK builds and installs, the backend is reachable through `adb reverse`, runtime permissions are granted on both phones, and several core screens render. Xiaomi can create an offline trip/channel and open offline chat with the composer visible. However, Samsung does not consistently bind the joined channel into the same active trip/channel context. Channel Details shows `TL-OFF-MEHC` as active, but Messages, Nearby, and Offline Chat still use `JOINEDTRIP`.

That active-context mismatch blocks two-device discovery, P2P chat delivery, PTT delivery, location teammate sharing, and SOS peer delivery. The strongest root-cause signal is data/context resolution after join, not device radios.

## Device Details

| Device | Serial | Model | Android | API | Permissions |
| --- | --- | --- | --- | --- | --- |
| Device A | `HAF6ZXGI5TINKJCA` | `M2101K7BG` | 13 | 33 | Fine/coarse location, Bluetooth scan/advertise/connect, Nearby Wi-Fi devices, microphone granted |
| Device B | `R58R85Q2HWH` | `SM-A127F` | 13 | 33 | Fine/coarse location, Bluetooth scan/advertise/connect, Nearby Wi-Fi devices, microphone granted for user 0 |

Radios were enabled by the user before testing. App-level runtime permission grants were verified using `dumpsys package com.example.traillink`.

## Build And Environment

| Item | Result |
| --- | --- |
| APK | `build/app/outputs/flutter-apk/app-debug.apk` |
| Build | PASS: `flutter build apk --debug` completed and produced the debug APK |
| Backend port | `5001` |
| Backend health | PASS: `GET http://127.0.0.1:5001/api/health` returned success |
| ADB reverse, Xiaomi | PASS: `tcp:5000 tcp:5001` |
| ADB reverse, Samsung | PASS: `tcp:5000 tcp:5001` |
| Local reset | PARTIAL: `pm clear com.example.traillink` succeeded; full `adb uninstall` returned `DELETE_FAILED_INTERNAL_ERROR` on both devices |

Backend log evidence: `backend-5001.out.log`  
Final device logs: `logcat-xiaomi-final.txt`, `logcat-samsung-final.txt`

## Setup Summary

Device A completed setup, created an offline trip, and generated channel `TL-OFF-MEHC`. Because the test used coordinate-based ADB input, the trip name was accidentally polluted as `QA14JTripgTL-OFF-QA14`; this is a QA input artifact, not a product requirement failure. The generated channel code and active channel were still usable on Xiaomi.

Device B joined `TL-OFF-MEHC`, and Channel Details showed `Offline Channel TL-OFF-MEHC`, `Active`, `1 connected`, `Active now`. After returning to Messages/Nearby/Chat, the app still resolved active channel as `JOINEDTRIP`, causing the devices to advertise different channel contexts.

## Test Results

### 1. Fresh Install And Setup

| ID | Status | Result |
| --- | --- | --- |
| SETUP-01 | PASS | Fresh launch after `pm clear` showed onboarding/setup on both devices. Evidence: `baseline-xiaomi.png`, `baseline-samsung.png`. |
| SETUP-02 | PARTIAL | Local profile/setup completed. UX issues: agreement/feature/security primary actions can be below the visible viewport and require scrolling. |
| SETUP-03 | PASS | Xiaomi created an offline trip and channel `TL-OFF-MEHC`; dashboard showed the active channel. |
| SETUP-04 | FAIL | Samsung joined `TL-OFF-MEHC` in Channel Details, but active providers remained inconsistent and later used `JOINEDTRIP`. |
| SETUP-05 | PASS | Runtime permissions were granted and verified through package dumps. In-app readiness refresh was not deeply re-tested. |

### 2. P2P Discovery

| ID | Status | Result |
| --- | --- | --- |
| NEAR-01 | FAIL | Nearby did not show the same active channel. Xiaomi: `TL-OFF-MEHC`; Samsung: `JOINEDTRIP`. |
| NEAR-02 | PASS | Xiaomi started advertising/discovery. Evidence: `discovery-started-xiaomi2.png/xml`. |
| NEAR-03 | PARTIAL | Samsung started advertising/discovery, but on wrong channel `JOINEDTRIP`. Evidence: `discovery-started-samsung2.png/xml`. |
| NEAR-04 | FAIL | No peer connection formed; both screens stayed at `0 connected`. |
| NEAR-05 | BLOCKED | Radio drop/recently-seen behavior could not be validated because baseline peer connection failed. |
| NEAR-06 | BLOCKED | Reconnection could not be validated because baseline peer connection failed. |

### 3. Offline Chat

| ID | Status | Result |
| --- | --- | --- |
| CHAT-OFF-01 | PARTIAL | Xiaomi showed header, empty state, composer, input, send button, bottom nav. Samsung opened read-only chat with wrong channel chip `JOINEDTRIP` and no composer. |
| CHAT-OFF-02 | BLOCKED | Connected-peer send could not be validated because P2P connection failed. |
| CHAT-OFF-03 | BLOCKED | Reply delivery could not be validated because P2P connection failed. |
| CHAT-OFF-04 | PASS | Xiaomi sent `helloA` with zero peers; message appeared locally as `pending`. Evidence: `offline-chat-xiaomi-sent.png/xml`. |
| CHAT-OFF-05 | BLOCKED | Queue forwarding after reconnect could not be validated because peer discovery never connected. |
| CHAT-OFF-06 | NOT TESTED | Offline media gating was not reached during this run. |

### 4. Voice-Note PTT

| ID | Status | Result |
| --- | --- | --- |
| PTT-01 | BLOCKED | PTT entry was not reliably reachable from the tested dashboard/messages surfaces after active-context mismatch. |
| PTT-02 | BLOCKED | Recording/queueing could not be validated without a reachable PTT surface and active channel consistency. |
| PTT-03 | BLOCKED | Receipt/playback could not be validated because P2P connection failed. |
| PTT-04 | BLOCKED | Reply receipt/playback could not be validated because P2P connection failed. |
| PTT-05 | NOT TESTED | Floor conflict was not tested. |
| PTT-06 | NOT TESTED | Microphone-denied behavior was not tested because microphone remained granted. |

### 5. Live Radio Experimental

| ID | Status | Result |
| --- | --- | --- |
| RADIO-01 | PARTIAL | Setup showed `Live Radio Experimental` disabled by default. |
| RADIO-02 | NOT TESTED | Experimental enable flow was not tested. |
| RADIO-03 | BLOCKED | No-peer Live Radio unavailable state could not be validated from PTT surface. |
| RADIO-04 | BLOCKED | Connected-peer eligibility could not be tested because P2P discovery failed. |
| RADIO-05 | BLOCKED | Near-live audio could not be tested because P2P discovery failed. |
| RADIO-06 | BLOCKED | Weak/disconnect fallback could not be tested because baseline connection failed. |
| RADIO-07 | NOT TESTED | Floor contention was not tested. |

### 6. SOS And Location

| ID | Status | Result |
| --- | --- | --- |
| SOS-01 | PARTIAL | SOS screen rendered on both devices with `Location attached`, editable message field, and SOS button. Real alert send was not triggered to avoid creating a false emergency event during this QA sweep. |
| SOS-02 | BLOCKED | Peer acknowledgement could not be tested because P2P connection failed. |
| SOS-03 | NOT TESTED | Location-disabled SOS behavior was not tested; location permission remained granted. |
| MAP-01 | PASS | Map screen rendered on both devices with `flutter_map`, controls, and bottom nav. Evidence: `map-xiaomi.png/xml`, `map-samsung.png/xml`. |
| MAP-02 | NOT TESTED | Share Location send was not triggered. |
| MAP-03 | BLOCKED | Teammate location visibility could not be validated because P2P discovery failed. |

### 7. Online Cloud Features

| ID | Status | Result |
| --- | --- | --- |
| CLOUD-01 | PASS | Backend health passed and both devices had `adb reverse tcp:5000 tcp:5001`. |
| CLOUD-02 | NOT TESTED | Cloud group creation was not completed in this run. |
| CHAT-ON-01 | BLOCKED | Cloud chat could not be opened because Messages showed `No cloud groups yet`. Evidence: `cloud-chat-xiaomi.png/xml`. |
| CHAT-ON-02 | BLOCKED | Cloud text sync was blocked by missing cloud group. |
| CHAT-ON-03 | BLOCKED | Image upload/render was blocked by missing cloud group. |
| CHAT-ON-04 | BLOCKED | Online voice note was blocked by missing cloud group. |
| CLOUD-03 | NOT TESTED | Backend-down behavior was not tested; backend remained running for this run. |

### 8. Mode And Restart Behavior

| ID | Status | Result |
| --- | --- | --- |
| MODE-01 | PARTIAL | Offline trip/channel exists, but dashboard still surfaced `Auto - Online` because setup used Auto and backend was reachable. This weakens user understanding of the active offline trip. |
| MODE-02 | PARTIAL | Auto with backend reachable created cloud identity and backend health checks continued passing, but cloud group chat was not available. |
| MODE-03 | NOT TESTED | Backend-down Auto fallback was not tested. |
| MODE-04 | PARTIAL | Relaunch recovered after red screens and local data persisted, but active trip/channel context remained inconsistent on Samsung. |
| MODE-05 | NOT TESTED | App Lock was disabled during setup; lock/PIN behavior was not tested. |

## Bugs Found

| ID | Severity | Screen/Area | Expected | Actual | Evidence | Suggested Fix |
| --- | --- | --- | --- | --- | --- | --- |
| TL-QA-14J-001 | Critical | Samsung setup join | Saving a joined offline channel should complete setup or return to dashboard safely. | Flutter red error screen after join save: `_children.contains(child)` assertion. Relaunch recovered. | `after-join-save-samsung.png`, `logcat-samsung-after-join-crash.txt` | Audit setup join navigation/state transitions for duplicate child/key reuse and async route updates after save. Add widget/integration regression for join during setup. |
| TL-QA-14J-002 | Critical | Xiaomi setup/channel transition | UI should not red-screen during setup or channel transition. | Flutter red error screen: `_elements.contains(element)` assertion. Relaunch recovered. | `current-aligned-xiaomi.png`, `logcat-xiaomi-after-assertion.txt` | Inspect animated/conditional widgets in setup completion/channel transition. Remove unstable GlobalKey/child reuse patterns. |
| TL-QA-14J-003 | Critical | ActiveTripContext / join channel | After Samsung joins `TL-OFF-MEHC`, all tools should resolve `TL-OFF-MEHC`. | Channel Details shows `TL-OFF-MEHC`, but Messages/Nearby/Chat resolve `JOINEDTRIP`. | `samsung-after-home-join-code.png/xml`, `messages-samsung.png/xml`, `discovery-started-samsung2.png/xml`, `offline-chat-samsung.png/xml` | Fix join flow persistence so trip `active_channel_id`, offline channel `is_active`, default chat, and compatibility mirrors update atomically. Rewire old providers to the same active context. |
| TL-QA-14J-004 | High | P2P discovery | Both phones on same channel should discover and connect. | Both devices advertise/discover, but on different channel contexts; peer count stays `0 connected`. | `discovery-started-xiaomi2.png/xml`, `discovery-started-samsung2.png/xml` | Resolve TL-QA-14J-003 first, then retest P2P transport. Add channel-code assertion before starting advertising. |
| TL-QA-14J-005 | High | Samsung offline chat | Joined active channel chat should be writable unless channel/chat is actually ended/read-only. | Samsung chat shows read-only and no composer because it opens wrong context `JOINEDTRIP`. | `offline-chat-samsung.png/xml` | Derive chat read-only state from resolved trip/channel/chat, not stale compatibility channel fields. |
| TL-QA-14J-006 | Medium | Setup UX | Primary action should remain visible or clearly reachable on all tested screens. | Agreement, feature, and security steps require scrolling; some `Continue` buttons appear with bounds `[0,0][0,0]` in UI tree before scroll. | `agreement-bottom-xiaomi.png/xml`, `features-bottom-xiaomi.png/xml`, `security-bottom-xiaomi.png/xml` | Use a sticky bottom action area or reduce vertical hero content on setup steps. |
| TL-QA-14J-007 | Medium | Mode/dashboard | Offline-only trip should make active offline tools obvious. | Dashboard still reads `Auto - Online` while showing an Offline Only trip/channel. | `home-xiaomi-after-finish.png/xml` | Show effective mode per active trip/channel and a clear cloud/offline split. |
| TL-QA-14J-008 | Medium | QA selectors/accessibility | QA selectors/content descriptions should expose key chat controls. | UIAutomator sees generic `EditText`/`Send` but not stable IDs like `offline-chat-composer`. | `offline-chat-xiaomi2.xml`, `offline-chat-xiaomi-sent.xml` | Add `Semantics(label: ...)` or content descriptions for QA keys, not only Flutter `Key`s. |
| TL-QA-14J-009 | Low | Install/reset | Fresh install should be cleanly repeatable. | `adb uninstall com.example.traillink` returned `DELETE_FAILED_INTERNAL_ERROR`; `pm clear` and reinstall succeeded. | Command output in QA run | Investigate package/user/profile state only if this repeats outside the test bench. |
| TL-QA-14J-010 | Medium | Messages/cloud | Online chat should have an obvious create/join path before chat validation. | Messages showed `No cloud groups yet`; cloud chat could not be opened. | `cloud-chat-xiaomi.png/xml` | Add a direct cloud group setup path from Messages or setup completion when Auto/Online mode is active. |

## UI/UX Improvement Notes

- Make setup primary actions sticky at the bottom so small screens do not hide `Continue`.
- Make the join offline trip form labels unambiguous. The test input path accidentally placed a channel-code string into the trip name field, which suggests the form is easy to misuse with keyboard/focus changes.
- Show one clear active context everywhere: active trip name, active channel name/code, active mode, and cloud sync status.
- Do not show `Auto - Online` as the dominant dashboard state when the active work item is an Offline Only trip.
- Add visible entry points for PTT and Live Radio under active offline tools, or clearly show why they are unavailable.
- Add content descriptions for bottom nav items that currently appear as NAF/empty nodes in UIAutomator.
- Add explicit offline no-peer guidance in Nearby and Chat: "Both phones must be on channel TL-OFF-...".
- Keep emergency/SOS text serious but add a test/demo guard if QA teams must validate send flows without creating false emergency records.

## Screenshots And Evidence Index

| File | Device | Area | Result |
| --- | --- | --- | --- |
| `baseline-xiaomi.png/xml` | Xiaomi | Fresh launch | Setup shown |
| `baseline-samsung.png/xml` | Samsung | Fresh launch | Setup shown |
| `home-xiaomi-after-finish.png/xml` | Xiaomi | Dashboard | Offline channel `TL-OFF-MEHC` visible |
| `after-join-save-samsung.png` | Samsung | Setup join | Flutter assertion red screen |
| `home-samsung-after-finish.png/xml` | Samsung | Dashboard | Active data persisted after relaunch |
| `samsung-after-home-join-code.png/xml` | Samsung | Channel details | `TL-OFF-MEHC` active in details |
| `messages-samsung.png/xml` | Samsung | Messages | Stale/wrong active channel `JOINEDTRIP` |
| `discovery-started-xiaomi2.png/xml` | Xiaomi | Nearby | Advertising/discovery on `TL-OFF-MEHC` |
| `discovery-started-samsung2.png/xml` | Samsung | Nearby | Advertising/discovery on `JOINEDTRIP` |
| `offline-chat-xiaomi2.png/xml` | Xiaomi | Offline chat | Composer visible |
| `offline-chat-xiaomi-sent.png/xml` | Xiaomi | Offline chat | `helloA` pending |
| `offline-chat-samsung.png/xml` | Samsung | Offline chat | Read-only, no composer, wrong channel |
| `cloud-chat-xiaomi.png/xml` | Xiaomi | Messages/cloud | No cloud groups yet |
| `map-xiaomi.png/xml` | Xiaomi | Map | Map renders |
| `map-samsung.png/xml` | Samsung | Map | Map renders |
| `sos-xiaomi.png/xml` | Xiaomi | SOS | SOS UI renders |
| `sos-samsung.png/xml` | Samsung | SOS | SOS UI renders |
| `logcat-xiaomi-final.txt` | Xiaomi | Logs | Final log snapshot |
| `logcat-samsung-final.txt` | Samsung | Logs | Final log snapshot |

## Final Recommendation

Status: **Not ready for demo or real-user testing.**

Top fixes before the next QA pass:

1. Fix Samsung join flow and active context persistence so all providers/screens resolve the same `trip -> channel -> chat`.
2. Fix the two Flutter framework assertion red screens during setup/channel transitions.
3. Retest P2P only after both phones show the same active channel in Home, Messages, Nearby, Channel Details, and Offline Chat.
4. Fix Samsung offline chat read-only/no-composer state after join.
5. Improve setup small-screen layout and active-mode wording before real-user usability testing.

After those fixes, rerun only the blocked areas first: P2P discovery, offline chat delivery/ack, queue-forward-on-reconnect, PTT voice-note delivery, SOS peer delivery, teammate map sharing, and cloud chat with a created cloud group.
