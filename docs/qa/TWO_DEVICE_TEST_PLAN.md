# TrailLink Phase 14A Two-Device Manual Test Plan

Use this document with two physical Android phones. Fill Actual, Result, and Notes during manual testing.

## Device Setup

| Field | Device A | Device B |
| --- | --- | --- |
| adb serial | HAF6ZXGI5TINKJCA | R58R85Q2HWH |
| Role | Online/Auto or bridge-capable phone | Manual Offline peer |
| Network | Same Wi-Fi as laptop | Same Wi-Fi as laptop |
| Required settings | Bluetooth, Wi-Fi, location, microphone enabled | Bluetooth, Wi-Fi, location, microphone enabled |
| Backend URL | Use reachable laptop/LAN API base, not emulator-only `10.0.2.2` on physical phones | Same |

Commands:

```powershell
adb devices
flutter build apk --debug
adb -s HAF6ZXGI5TINKJCA install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s R58R85Q2HWH install -r build\app\outputs\flutter-apk\app-debug.apk
```

## A. Offline Peer Discovery

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A joins/creates same offline channel as Device B. | Both show same channel code. |  |  |  |
| Device A starts advertising and discovery. | Discovery/advertising status is active. |  |  |  |
| Device B starts advertising and discovery. | Devices appear as nearby peers. |  |  |  |
| Connect peers. | Both show connected/nearby presence and last seen. |  |  |  |
| Turn off Device B network/Bluetooth temporarily. | Device A changes B from connected to recently seen/disconnected without removing membership. |  |  |  |

## B. Offline Text Chat

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A opens Offline Chat and sends text. | Message appears locally first as pending/sending. |  |  |  |
| Device B receives text. | B shows message and ACK/delivery updates. |  |  |  |
| Device B replies. | A receives reply and statuses settle. |  |  |  |
| Disconnect peer and send another text. | Message remains queued/pending, not lost. |  |  |  |

## C. Offline SOS

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A sends SOS with location enabled. | A saves event locally and B receives emergency. |  |  |  |
| Device B acknowledges if supported. | A sees ACK/latest emergency update. |  |  |  |
| Repeat with location disabled. | SOS still sends without blocking; UI says location is not attached. |  |  |  |

## D. Offline Location Sharing

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A taps Get GPS. | Permission prompt or GPS result appears. |  |  |  |
| Device A shares location. | Location saved locally first, then sent to peer if connected. |  |  |  |
| Device B opens Map. | B sees A as last-known teammate location. |  |  |  |

## E. Voice-Note PTT

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A selects Voice-note PTT. | Voice-note mode is default and stable. |  |  |  |
| Hold, record, release. | A sends voice note packet/file. |  |  |  |
| Device B receives and plays. | B can play received voice note. |  |  |  |
| Device B records reply. | A receives and plays reply. |  |  |  |

## F. Live Radio Experimental

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Enable Live Radio in Voice settings on both devices. | Experimental acknowledgement is required. |  |  |  |
| Verify strong connection/connected peer. | Live Radio becomes selectable only when eligible. |  |  |  |
| Device A holds live radio. | A streams; B hears near-live audio if implemented and connection is good. |  |  |  |
| Device B tries to talk while A is speaking. | B is denied/waits for floor. |  |  |  |
| Weaken/disconnect connection. | Live Radio becomes unavailable or falls back to voice-note PTT. |  |  |  |

## G. Bridge Mode

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A online with backend reachable, bridge enabled. | A shows bridge ready for same channel. |  |  |  |
| Device B offline sends message/SOS/location. | Device A receives offline packet. |  |  |  |
| A bridges to backend. | Backend receives one bridged record, no duplicates. |  |  |  |
| Repeat same packet/ACK. | Duplicate prevention skips repeated bridge upload. |  |  |  |

## H. Mode Switching

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Switch A Auto/Online/Offline. | UI cards and status chips change correctly. |  |  |  |
| Switch B Manual Offline. | Cloud sync pauses and offline tools remain visible. |  |  |  |
| Restart both apps. | Selected mode persists as designed. |  |  |  |

## I. Media

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Online cloud chat: send gallery image. | Local preview appears, upload completes, receiver/history show media. |  |  |  |
| Online cloud chat: send voice note. | Voice bubble uploads and plays. |  |  |  |
| Offline chat: attempt media. | Media attach hidden/blocked with online-only message. |  |  |  |

## J. Channel/Group Lifecycle

| Steps | Expected Result | Actual Result | Result | Notes |
| --- | --- | --- | --- | --- |
| Device A owner ends offline channel. | A marks channel ended and read-only, active channel cleared. |  |  |  |
| Device B connected receives status update. | B shows ended/read-only and cannot send/connect/PTT. |  |  |  |
| Device B history remains visible. | Old messages/details remain read-only. |  |  |  |
| Cloud group owner archives group. | Members no longer see it as active/joined; cached history read-only. |  |  |  |

