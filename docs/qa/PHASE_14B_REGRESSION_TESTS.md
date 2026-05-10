# Phase 14B Regression Tests

Date: 2026-05-09

## Automated Tests Added

File:

`test/phase14b_active_channel_resolution_test.dart`

Coverage:

| Test | Result |
| --- | --- |
| Resolver exposes required active-channel API | PASS |
| Providers centralize active channel resolution through resolver | PASS |
| Nearby, Connectivity, Dashboard, and Messages Hub use resolver-backed providers/routes | PASS |
| Debug route exposes diagnostics only outside production | PASS |
| Offline composer stays visible with no connected peers | PASS |
| Resolver type is importable | PASS |

Updated:

`test/main_ui_redesign_test.dart`

Reason:

Messages Hub now correctly shows the active trip summary and the resolver-backed offline channel shortcut, so duplicated trip/channel labels can appear legitimately in the widget tree.

## Verification Commands

| Command | Result | Notes |
| --- | --- | --- |
| `flutter analyze` | PASS | No analyzer issues. |
| `flutter test test\phase14b_active_channel_resolution_test.dart` | PASS | 6 tests passed. |
| `flutter test` | PASS | 93 tests passed. |
| `flutter build apk --debug` | PASS | Debug APK built successfully. |

## Device Verification

| Device | Action | Result |
| --- | --- | --- |
| Samsung `R58R85Q2HWH` | Install debug APK | PASS |
| Xiaomi `HAF6ZXGI5TINKJCA` | Install debug APK | PASS |
| Samsung `R58R85Q2HWH` | UI tree inspection after launch | BLOCKED |
| Xiaomi `HAF6ZXGI5TINKJCA` | UI tree inspection after launch | BLOCKED |

Blocker:

`uiautomator dump` returned `ERROR: null root node returned by UiTestAutomationBridge`. Because of this, manual visual confirmation is still required before marking device flows PASS.

## Manual Regression Checklist

| ID | Test | Expected | Result |
| --- | --- | --- | --- |
| 14B-M01 | Create or retain Offline Only trip | Home shows active trip/channel | NOT TESTED |
| 14B-M02 | Open Offline Channels | Active trip-created channel appears | NOT TESTED |
| 14B-M03 | Open Nearby Peers | Channel code and discovery controls appear | NOT TESTED |
| 14B-M04 | Open Connectivity Guidance | Channel-aware empty peer state appears | NOT TESTED |
| 14B-M05 | Tap Home PTT card | Offline PTT route opens | NOT TESTED |
| 14B-M06 | Open Offline Channel Chat with zero peers | Composer visible; queue hint shown | NOT TESTED |
| 14B-M07 | Open ended channel chat if available | Composer hidden; read-only message shown | NOT TESTED |
| 14B-M08 | Open online group chat | Existing online behavior remains available | NOT TESTED |

## Notes

The automated tests are primarily source/widget regressions. They prove the resolver exists and that screens are wired to it, but they do not replace physical two-device validation of Nearby, PTT, and offline chat delivery.

