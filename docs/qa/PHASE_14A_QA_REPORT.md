# TrailLink Phase 14A QA Report

Date: 2026-05-09  
Scope: QA documentation, source audit, automated checks, limited Android screenshot capture.  
Rule: A feature is marked PASS only where there is direct command, source-test, backend-health, or screenshot evidence.

## Overall Readiness

| Item | Result | Evidence |
| --- | --- | --- |
| Ready for final demo | No | Automated checks pass and screenshots are now valid, but active offline channel lookup is broken across Offline Channels/Nearby/Connectivity/PTT and two-device P2P remains blocked. |
| Ready for two-device testing | No | Two Android devices are connected, APK builds, and ADB input now works on both. Functional two-device P2P testing remains blocked by the active offline channel lookup/navigation failure. |
| Critical blockers | None confirmed by automated checks | No Flutter analyzer/test/build blocker found. |
| High priority bugs | 3 | Active offline channel lookup failure, PTT wrong-route failure, and two-device lifecycle/P2P verification blocker. |
| Recommended next phase | Phase 14B active offline channel lookup/navigation fix | Fix active-channel resolution before continuing two-device P2P QA. |

## Automated Checks

| Check | Command | Result | Evidence / Notes |
| --- | --- | --- | --- |
| Flutter dependencies | `flutter pub get` | PASS | Dependencies resolved. 32 packages have newer versions outside current constraints. |
| Flutter static analysis | `flutter analyze` | PASS | `No issues found!` |
| Flutter tests | `flutter test` | PASS | 87 tests passed. Includes app lock, trip wizard, media, live radio source contracts, local-first consistency, mode engine, map fallback, settings, and lifecycle tests. |
| Debug APK build | `flutter build apk --debug` | PASS | Built `build\app\outputs\flutter-apk\app-debug.apk`. |
| Backend syntax checks | `node --check backend\src\app.js`, `server.js`, group service/routes/controller | PASS | No syntax errors reported. |
| Backend scripts through PowerShell `npm` | `npm run` | BLOCKED | PowerShell execution policy blocks `npm.ps1`. Use `npm.cmd` on this Windows environment. |
| Backend scripts through `npm.cmd` | `npm.cmd run` | PASS | Scripts listed: `start`, `dev`, `test:phase02`, `test:phase03`, `test:phase09`, `test:phase10`, `test:phase12`, `test:phase13e`, `test:phase13f`, `test:phase13g`, `test:phase13h`. |
| Backend health | temporary `node src/server.js`, then `GET /api/health` | PASS | HTTP 200: `TrailLink backend is running`. |
| Backend DB health | `GET /api/health/db` | PASS | HTTP 200: `MongoDB Atlas connected`, `dbState=connected`. |
| Backend smoke scripts | `npm.cmd run test:*` | NOT TESTED | Not run because the plan requires MongoDB reset confirmation before smoke scripts that may mutate backend data. |

## Database And API Configuration

| Item | Result | Evidence / Notes |
| --- | --- | --- |
| Backend `.env` exists | PASS | Keys present: `PORT`, `NODE_ENV`, `MONGO_URI`, `JWT_SECRET`, `JWT_EXPIRES_IN`. Values were not printed into this report. |
| Flutter `.env.example` exists | PASS | Contains `API_BASE_URL` and `APP_ENV`. |
| Health endpoint | PASS | `backend/src/app.js` mounts `/api/health`; health request returned HTTP 200. |
| DB health endpoint | PASS | `/api/health/db` returned connected state. |
| Identity bootstrap endpoint | PASS | `/api/identity/bootstrap` route exists; `/api/auth/identity/bootstrap` also exists in auth routes. |
| Group archive/member routes | PASS | `DELETE /api/groups/:groupId`, member list/remove/leave/role routes exist behind auth middleware. |
| MongoDB reset | NOT TESTED | Not performed. The exact target database must be confirmed before destructive reset. |
| SQLite reset | PARTIAL | Device B app data clear succeeded. Device A app data clear failed due OS permission denial. |

## Android Device QA Evidence

| Device | Result | Evidence / Notes |
| --- | --- | --- |
| `HAF6ZXGI5TINKJCA` | PASS for setup navigation | APK installed and app launched after tester uninstall/reinstall. ADB tap/swipe input now works after Xiaomi developer setting changes. First-run setup was completed to Home and a valid screenshot was captured. |
| `R58R85Q2HWH` | PARTIAL | APK installed and fresh setup was completed to Home. Valid screenshots captured through setup, no-active Home, active offline trip, map, SOS, settings, and App Lock. Offline channel lookup blocks P2P continuation. |

## Screenshot Evidence Captured

Stored under `docs/qa/screenshots/phase14a/`.

| File | Result | Notes |
| --- | --- | --- |
| `01-home-dashboard.png` | PASS | Samsung fresh no-active-trip Home dashboard. |
| `01-device-b-after-clear-launch.png` | PASS | Samsung first-run agreement after relaunch/wait; valid PNG. |
| `02-messages-hub.png` | PASS | Samsung Messages Hub no-active-trip prompt. |
| `14-xiaomi-retest-home-dashboard.png` | PASS | Xiaomi fresh setup completed to no-active-trip Home after developer setting changes. Valid PNG. |
| `15-samsung-retest-offline-channel-state.png` | FAIL | Valid PNG, but it confirms the Offline Channel screen still shows no channels during retest. |

## Screenshots Needed From Tester

- Setup profile screen
- Dashboard no active trip
- Dashboard active online trip
- Dashboard active offline trip
- Messages hub
- Group details
- Chat online
- Chat offline fallback
- Offline channel details
- Nearby peers
- SOS screen
- Map screen
- PTT screen
- Live radio screen
- Connectivity guidance
- Settings main
- App lock screen

## Channel/Group Delete And Active/Inactive Lifecycle Audit

| Area | Result | Evidence / Notes |
| --- | --- | --- |
| SQLite lifecycle schema | PASS | `local_database.dart` is version 19 and includes `offline_channels.channel_status`, `ended_at`, `ended_by_user_id`, `ended_reason`. |
| Offline channel model | PASS | `test/channel_group_lifecycle_test.dart` verifies active/inactive/ended model mapping and `isUsable=false` for ended channels. |
| Offline channel repository | PASS | Source contains `endChannel`, `channel_status_update`, local ended marking, active-channel clearing behavior. |
| Offline packet router | PASS | Source/test verifies `case 'channel_status_update'` and read-only notice copy. |
| Cloud group archive backend | PASS | Source/test verifies `archiveGroup`, `status='archived'`, `emitGroupArchived`, and `DELETE /:groupId`. |
| Flutter group archive API | PASS | Source/test verifies `GroupRepository.archiveGroup`. |
| Two-device lifecycle propagation | NOT TESTED | Requires connected physical device flow where Device A ends channel/group and Device B receives status update. |

## Result Summary

| Category | Result |
| --- | --- |
| Automated build/test health | PASS |
| Backend health | PASS |
| Source-level lifecycle implementation | PASS |
| Fresh install/first launch on both devices | PARTIAL |
| Screenshot capture set | PARTIAL |
| Two-device P2P QA | NOT TESTED |
| MongoDB destructive reset | NOT TESTED |

## Retest Update - 2026-05-09

Reason: tester reported that captured screenshots would not open and requested a fresh Xiaomi reinstall retest plus another two-device pass.

### Screenshot Capture Fix

Root cause found: the earlier screenshots were corrupted by PowerShell binary redirection from `adb exec-out screencap -p > file.png`. The bad files started with `FF FE FD FF 50 00 4E 00`, which is not a PNG header.

New capture method used:

```powershell
adb -s <serial> shell screencap -p /sdcard/Download/<name>.png
adb -s <serial> pull /sdcard/Download/<name>.png docs\qa\screenshots\phase14a\<name>.png
adb -s <serial> shell rm /sdcard/Download/<name>.png
```

All retained PNG files in `docs/qa/screenshots/phase14a/` now start with the valid PNG header `89 50 4E 47 0D 0A 1A 0A`.

### Device Retest Results

| Device | Result | Evidence / Notes |
| --- | --- | --- |
| `HAF6ZXGI5TINKJCA` Xiaomi | PASS for fresh setup navigation | APK installed and launched after the tester uninstall/reinstall. ADB screenshots work. ADB tap/swipe input now works after the Xiaomi developer setting change. Setup was completed through trip skip and permissions to the no-active-trip Home dashboard. |
| `R58R85Q2HWH` Samsung | PARTIAL | APK installed and launched. First-run setup was completed with ADB input through agreement, profile, mode, features, security skip, trip skip, permissions, and Home. A second offline-only trip was created for active-trip screenshots. |

### Fresh Retest Screenshots

| File | Result | Notes |
| --- | --- | --- |
| `00-device-a-initial-launch.png` | PASS | Valid PNG. Xiaomi first-run agreement after reinstall. |
| `01-device-b-after-clear-launch.png` | PASS | Valid PNG. Samsung first-run agreement after relaunch/wait. This supersedes the earlier blank/corrupted evidence. |
| `01-home-dashboard.png` | PASS | Valid PNG. Fresh no-active-trip Home on Samsung. |
| `02-messages-hub.png` | PASS | Valid PNG. Messages prompt with no active trip. |
| `02-messages-hub-active.png` | PASS | Valid PNG. Active offline trip Messages Hub. |
| `03-home-active-offline-trip.png` | PASS | Valid PNG. Active offline-only trip dashboard with generated channel code. |
| `04-offline-channel-details.png` | PARTIAL | Valid PNG, but it shows the offline chat header because channel detail navigation did not complete from the tested path. |
| `05-offline-chat.png` | PARTIAL | Valid PNG. Offline chat opened, but the composer/input was not visible in the captured state. |
| `06-map.png` | PASS | Valid PNG. OSM map rendered with compact status chips and controls. |
| `07-sos.png` | PASS | Valid PNG. SOS screen rendered with compact status chips. |
| `08-nearby-peers.png` | FAIL | Valid PNG. Nearby screen incorrectly says to create/join an offline channel even though the active trip created `offline_channels.channel_status='active'` and `is_active=1` in SQLite. |
| `09-ptt.png` | FAIL | Valid PNG. PTT card navigation opened My Groups/backend-not-reachable instead of the offline PTT screen. |
| `10-settings.png` | PASS | Valid PNG. Settings main screen captured. |
| `11-app-lock.png` | PASS | Valid PNG. App Lock & Privacy screen captured. |
| `12-connectivity-guidance.png` | FAIL | Valid PNG. Connectivity screen incorrectly says to create/join an offline channel even though the active trip has an active offline channel in SQLite. |
| `13-offline-channels.png` | FAIL | Valid PNG. Offline Channel list says no offline channels, while SQLite contains active channel `TL-OFF-BL4C`. |
| `14-xiaomi-retest-home-dashboard.png` | PASS | Valid PNG. Xiaomi reached Home after fresh setup; no-active-trip guidance is visible. |
| `15-samsung-retest-offline-channel-state.png` | FAIL | Valid PNG. Samsung retest confirms Offline Channel screen still says no channels. |

### SQLite Evidence For Active Offline Trip

Samsung local DB was inspected after creating `QA_Offline_Trip`.

| Table | Evidence |
| --- | --- |
| `offline_channels` | Contains `channel_id=8f1ec8f7-27d4-4293-a499-72f93dad5880`, `channel_code=TL-OFF-BL4C`, `channel_name=QA_Offline_Trip`, `is_active=1`, `channel_status=active`. |
| `offline_channel_members` | Contains current local user as `owner`, `membership_status=active`, `presence_status=connected`, `connection_status=connected`. |
| `trip_sessions` | Contains active offline trip pointing to the same `offline_channel_id` and `channel_code=TL-OFF-BL4C`. |

### Retest Readiness Summary

| Category | Result | Notes |
| --- | --- | --- |
| Screenshot files open correctly | PASS | Valid PNG headers confirmed for all retained screenshots. |
| Fresh setup on Samsung | PASS | Completed to Home. |
| Fresh setup on Xiaomi | PASS | Completed to Home after tester enabled the needed Xiaomi developer setting. |
| ADB input on Xiaomi | PASS | `adb shell input keyevent`, `tap`, and `swipe` returned cleanly. The earlier `INJECT_EVENTS` blocker is resolved. |
| ADB input on Samsung | PASS | `adb shell input keyevent`, `tap`, and `swipe` returned cleanly. |
| Active offline trip creation | PASS | Dashboard and SQLite show trip/channel created. |
| Offline channel list/active lookup | FAIL | UI does not show the created active channel. |
| Nearby and connectivity active-channel awareness | FAIL | Both screens say no channel exists. |
| PTT access from active offline trip | FAIL | Tapping PTT opens My Groups/backend error instead of offline PTT. |
| Two-device P2P functional test | BLOCKED | Blocked by active-channel lookup/navigation failure. Device automation is no longer the blocker. |

## Retest Update 2 - 2026-05-09

Reason: tester enabled Xiaomi developer settings and requested another QA report update.

### Commands Re-run

| Check | Command | Result | Evidence / Notes |
| --- | --- | --- | --- |
| Flutter dependencies | `flutter pub get` | PASS | Dependencies resolved. 32 packages remain newer but outside constraints. |
| Flutter static analysis | `flutter analyze` | PASS | `No issues found!` |
| Flutter tests | `flutter test` | PASS | 87 tests passed. |
| Debug APK build | `flutter build apk --debug` | PASS | Built `build\app\outputs\flutter-apk\app-debug.apk`. |
| Device list | `adb devices` | PASS | `HAF6ZXGI5TINKJCA` and `R58R85Q2HWH` connected. |
| Xiaomi ADB input | `adb -s HAF6ZXGI5TINKJCA shell input keyevent/tap/swipe` | PASS | No `INJECT_EVENTS` error after developer setting changes. |
| Samsung ADB input | `adb -s R58R85Q2HWH shell input keyevent/tap/swipe` | PASS | Input commands returned cleanly. |

### New Device Evidence

| Device | Result | Evidence / Notes |
| --- | --- | --- |
| Xiaomi `HAF6ZXGI5TINKJCA` | PASS for setup-to-Home | Started from setup, accepted agreement, saved profile `XiaomiTester`, skipped trip, finished permissions, and reached Home. Screenshot: `14-xiaomi-retest-home-dashboard.png`. |
| Samsung `R58R85Q2HWH` | FAIL for offline channel list consistency | Offline Channel screen still says `No offline channels yet`; this confirms TL-QA-14A-007 remains open. Screenshot: `15-samsung-retest-offline-channel-state.png`. |

### Updated Blocking Assessment

The Xiaomi device automation issue is resolved. The remaining blocker for two-device Nearby/offline chat/PTT/lifecycle propagation testing is the app-level active offline channel lookup/navigation mismatch: the trip wizard can create an active channel in SQLite, but Offline Channels, Nearby, Connectivity Guidance, and PTT do not consistently resolve it.
