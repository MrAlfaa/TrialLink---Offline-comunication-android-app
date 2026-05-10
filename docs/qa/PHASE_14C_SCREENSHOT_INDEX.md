# Phase 14C Screenshot Index

Date: 2026-05-09

Folder:

`docs/qa/screenshots/phase14c/`

PNG capture method:

`adb shell screencap -p /sdcard/<name>.png` followed by `adb pull`. PNG signatures were checked with a byte-signature script.

## Phase 14D Screenshot Addendum

Folder:

`docs/qa/screenshots/phase14d/`

Phase 14D screenshots also used `adb shell screencap -p /sdcard/<name>.png` followed by `adb pull`; this avoids corrupt PNG output from PowerShell redirection.

| File | Device | What it shows | Result |
| --- | --- | --- | --- |
| `01-xiaomi-launch.png` | A Xiaomi | Home active trip `QA_P2P_Trip_A`, channel `TL-OFF-XVZG` | PASS evidence |
| `02-samsung-launch.png` | B Samsung | Samsung still showing old `TL-OFF-BL4C` | PARTIAL evidence |
| `03-xiaomi-offline-channels.png` | A Xiaomi | Offline Channels list shows active channel | PASS evidence |
| `04-xiaomi-nearby-active-channel.png` | A Xiaomi | Nearby Peers detects `TL-OFF-XVZG` and shows controls | PASS evidence |
| `05-xiaomi-connectivity-active-channel.png` | A Xiaomi | Connectivity Guidance detects `TL-OFF-XVZG` | PASS evidence |
| `06-xiaomi-offline-ptt-from-dashboard.png` | A Xiaomi | Dashboard PTT opens offline PTT screen | PASS evidence |
| `07-xiaomi-offline-chat-composer.png` | A Xiaomi | Final capture not valid for composer PASS due navigation/setup state changes | PARTIAL evidence |
| `07b-xiaomi-offline-chat-composer-wait.png` | A Xiaomi | Earlier no-composer failure retained for comparison | FAIL evidence |
| `07m-direct-route-chat.png` | A Xiaomi | Direct route attempt landed in setup/profile flow | BLOCKED evidence |

## Screenshots

| File | Device | What it shows | Result |
| --- | --- | --- | --- |
| `00-xiaomi-home-before-trip.png` | A Xiaomi | No active trip before Phase 14C setup | Evidence |
| `00-samsung-launch-state.png` | B Samsung | Existing active offline trip before joining A channel | Evidence |
| `01-device-a-home-active-trip.png` | A Xiaomi | Home active trip `QA_P2P_Trip_A`, channel `TL-OFF-XVZG` | PASS evidence |
| `02-device-b-channel-joined.png` | B Samsung | Joined/opened channel detail for `TL-OFF-XVZG` | PARTIAL evidence |
| `03-device-b-home-active-trip.png` | B Samsung | Home still shows old `TL-OFF-BL4C` after join | FAIL evidence |
| `04-device-a-offline-channels-list.png` | A Xiaomi | Offline Channels list shows `QA_P2P_Trip_A`, `TL-OFF-XVZG`, `Active` | PASS evidence |
| `05-device-b-offline-channel-detail.png` | B Samsung | Offline Channel detail for joined channel `TL-OFF-XVZG` | PARTIAL evidence |
| `06-device-a-nearby-no-channel-fail.png` | A Xiaomi | Nearby Peers says create/join channel first despite active trip/channel | FAIL evidence |
| `07-device-a-connectivity-no-channel-fail.png` | A Xiaomi | Connectivity Guidance says create/join channel first despite active trip/channel | FAIL evidence |
| `08-device-a-ptt-routes-trip-setup-fail.png` | A Xiaomi | Dashboard PTT opens Trip Setup Wizard instead of offline PTT | FAIL evidence |
| `09-device-a-offline-chat-result.png` | A Xiaomi | Offline Channel Chat opens blank; composer absent | FAIL evidence |

## Requested Screenshot Coverage

| Requested screenshot | Captured file | Status |
| --- | --- | --- |
| Offline Channels list after offline trip creation | `04-device-a-offline-channels-list.png` | Captured |
| Nearby Peers after offline trip creation | `06-device-a-nearby-no-channel-fail.png` | Captured, failing state |
| Connectivity Guidance after offline trip creation | `07-device-a-connectivity-no-channel-fail.png` | Captured, failing state |
| Offline PTT screen from dashboard PTT card | `08-device-a-ptt-routes-trip-setup-fail.png` | Captured, wrong route |
| Offline Chat with visible composer | `09-device-a-offline-chat-result.png` | Captured, composer missing/blank |
