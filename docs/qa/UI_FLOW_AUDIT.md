# TrailLink Phase 14A UI Flow Audit

Result values: PASS, FAIL, PARTIAL, NOT TESTED, BLOCKED.

## Retest Addendum - 2026-05-09

| Flow | Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- | --- |
| Fresh Xiaomi reinstall launch | Safety agreement or setup flow appears | Xiaomi shows setup flow after reinstall. After developer setting changes, ADB input works and setup was completed to Home. | PASS | None in this pass. | No |
| Fresh Samsung setup | Agreement -> profile -> mode -> features -> security -> trip -> permissions -> dashboard | Completed to Dashboard using ADB input. | PASS | None in this pass. | No |
| No-active-trip Home | Shows focused Start Trip / Join Trip guidance | Home shows `No Active Trip`, Start Trip, Join Trip, and disabled feature previews. | PASS | None in this pass. | No |
| Offline-only trip creation | Creates local active trip and active offline channel | Dashboard shows active offline trip and channel code `TL-OFF-BL4C`; SQLite contains matching active channel/member/session. | PASS | None in creation path. | No |
| Offline Channels list after trip creation | Shows the created active channel | List says `No offline channels yet` despite SQLite active channel. | FAIL | TL-QA-14A-007 | No |
| Nearby after trip creation | Uses the active offline channel | Nearby says to create/join an offline channel first. | FAIL | TL-QA-14A-008 | No |
| Connectivity after trip creation | Uses the active offline channel for guidance | Connectivity says to create/join an offline channel first. | FAIL | TL-QA-14A-008 | No |
| PTT from offline trip dashboard | Opens offline PTT / Walkie-talkie | Opens My Groups/backend-not-reachable screen. | FAIL | TL-QA-14A-009 | No |
| Offline chat from Messages Hub | Opens offline chat with visible composer | Opens offline chat header/chips, but composer is not visible. | PARTIAL | TL-QA-14A-010 | No |

## Retest Addendum 2 - 2026-05-09

| Flow | Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- | --- |
| Xiaomi ADB navigation after developer setting change | `adb shell input` can tap and swipe app UI | `keyevent`, `tap`, and `swipe` returned cleanly. Xiaomi setup was completed to the Home dashboard. | PASS | TL-QA-14A-003 resolved in retest | No |
| Xiaomi no-active-trip Home after reinstall | Home shows Start Trip / Join Trip guidance | Home shows `No Active Trip`, `Welcome, XiaomiTester`, Start Trip, Join Trip, How TrailLink Works, and disabled feature previews. | PASS | None | No |
| Samsung Offline Channel screen retest | Existing active offline trip channel appears in list | Offline Channel screen still says `No offline channels yet`. | FAIL | TL-QA-14A-007 | No |

## 1. Fresh Install / First Launch

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Splash -> Agreement -> Profile setup -> Startup mode -> Feature preferences -> Security -> Trip setup -> Permissions -> Dashboard | Source routes exist for `/splash`, `/setup/agreement`, `/setup/identity`, `/setup/mode`, `/setup/features`, `/setup/security`, `/setup/trip`, `/setup/permissions`. Device B after clear captured blank shell instead of visible setup. | FAIL | TL-QA-14A-001 | Yes |
| No old login/register screens in normal local-first setup | `/login` and `/register` remain in router for compatibility, but setup identity route is the local-first entry. Device flow not fully navigated. | PARTIAL | None confirmed | Yes |
| Agreement readable and scrollable | Source contains `SetupAgreementScreen`; manual scroll not tested. | NOT TESTED | None | Yes |
| Setup saves local identity | Source and tests cover local identity/bootstrap behavior; not manually verified on fresh device in Phase 14A. | PARTIAL | TL-QA-14A-001 blocks fresh verification | Yes |

## 2. Second Launch

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Splash -> app unlock if enabled -> Dashboard | App-lock routing tests passed; Device A opened Dashboard with existing state. | PARTIAL | None confirmed | App lock screen needed |
| PIN/fingerprint OR behavior | Automated tests cover PIN validation, biometric grace, router refresh, setup handoff. Physical biometric test not run. | PARTIAL | None confirmed | Yes |
| No private data before unlock | Source tests cover lock routing; manual locked launch not tested. | PARTIAL | None confirmed | Yes |

## 3. Home Dashboard

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Trip-first dashboard, Start/Join if no active trip | Source/tests verify no-trip guidance. Device A screenshot shows active offline trip hero. No-active screenshot not captured. | PARTIAL | None confirmed | Yes |
| No repeated giant warning cards | Automated source/widget tests verify feature screens do not render large mode banners. Device A Home shows compact status. | PASS | None | Captured active trip |
| Compact status chips and correct online/offline feature set | Device A Home shows Offline Mode, Cached User, Trip Active, Sync Paused, and Offline Tools. | PASS | None | Captured |

## 4. Messages Flow

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Messages tab opens Messages Hub | Source/router and tests verify `/chat` hub and trip prompt behavior. Device navigation blocked by `adb input` restriction. | PARTIAL | TL-QA-14A-004 | Yes |
| Cloud groups, offline channels, recent tabs | Source shows segmented tabs. Widget tests cover query intents. Not manually captured. | PARTIAL | None confirmed | Yes |
| Cards open details/chat | Source routes exist. Manual navigation not tested. | NOT TESTED | None | Yes |

## 5. Chat Screen

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Compact header, no giant banner | Automated tests verify compact header and no `ConnectionModeBanner`. | PASS | None | Yes |
| Media plus button only online cloud chat | Automated tests verify online plus button and offline hidden/hint behavior. | PASS | None | Yes |
| Local-first status labels | Source/model tests cover message status metadata; device send not tested. | PARTIAL | None confirmed | Yes |

## 6. Map Screen

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Actual map or fallback, no silent white box | Automated map fallback tests pass. Device screenshot not captured. | PARTIAL | None confirmed | Yes |
| GPS/share/center/refresh controls | Source contains map controls. Manual permission flow not tested. | PARTIAL | None confirmed | Yes |
| Teammate cards and compact chips | Source contains compact chips and teammate cards. Manual state not tested. | PARTIAL | None confirmed | Yes |

## 7. SOS Screen

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Compact chips and clear SOS action | Source uses `ModeStatusChip`; manual screenshot not captured. | PARTIAL | None confirmed | Yes |
| Location optional | Automated mode/SOS tests cover location omission. Manual SOS not sent. | PARTIAL | None confirmed | Yes |
| Latest emergency shown | Source contains emergency history/latest sections; manual not tested. | NOT TESTED | None | Yes |

## 8. PTT / Live Radio Screen

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Voice-note PTT stable default | Automated/source tests cover PTT and live radio contracts. Manual audio test not run. | PARTIAL | None confirmed | Yes |
| Live radio experimental gated | Source/tests cover settings and eligibility gating. Two-device live audio not tested. | PARTIAL | None confirmed | Yes |
| Voice notes not hidden by bottom nav | Source uses bottom padding; device screen not captured. | NOT TESTED | None | Yes |

## 9. Connectivity Guidance

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Compact status chips, no giant mode card | Source uses `ModeStatusChip`; automated source sweep passed. | PASS | None | Yes |
| Empty no-channel/no-peer guidance clear | Source contains active-channel conditional. Manual screen not captured. | PARTIAL | None confirmed | Yes |

## 10. Settings Screen

| Expected | Actual | Result | Bugs Found | Screenshot Needed |
| --- | --- | --- | --- | --- |
| Profile, communication, safety/privacy, voice/advanced layout | Automated settings reorganization tests pass. Manual screenshot not captured. | PARTIAL | None confirmed | Yes |
| Live Radio only in Voice & Walkie-Talkie | Automated tests verify no duplicated feature controls. | PASS | None | Yes |
| No System Status links/no-op actions | Automated tests verify no technical status entry points. | PASS | None | Yes |
