# TrailLink Phase 14A Bug Backlog

## Bug ID: TL-QA-14A-001
Title: Device B shows blank Flutter shell after successful app-data clear  
Severity: High  
Area: UI / Startup  
Steps to reproduce:
1. Install `build\app\outputs\flutter-apk\app-debug.apk` on Device B `R58R85Q2HWH`.
2. Run `adb -s R58R85Q2HWH shell pm clear com.example.traillink`.
3. Launch `com.example.traillink/.MainActivity`.
4. Capture screenshot and UI tree.
Expected: Splash or setup flow appears.  
Actual: Screenshot shows a blank white/empty Flutter surface; UI tree contains only root Flutter views without readable setup nodes.  
Evidence: `docs/qa/screenshots/phase14a/01-device-b-after-clear-launch.png`.  
Likely cause: Startup route or Flutter rendering may be waiting on async initialization after fresh data clear, or the capture happened before first visible frame. Needs manual device observation and longer logcat.  
Suggested fix: Reproduce manually on Device B, capture full logcat from app process, then inspect splash/auth-access/app-lock initialization ordering.  
Status: Superseded by retest - Samsung reached first-run setup after relaunch/wait and valid PNG capture. Keep watch during future cold-start QA.

## Bug ID: TL-QA-14A-002
Title: Device A app data cannot be cleared through adb  
Severity: Low  
Area: QA Environment  
Steps to reproduce:
1. Run `adb -s HAF6ZXGI5TINKJCA shell pm clear com.example.traillink`.
Expected: App data clears, local SQLite reset occurs.  
Actual: Android throws `SecurityException` for `CLEAR_APP_USER_DATA`.  
Evidence: Command output during Phase 14A device reset.  
Likely cause: Xiaomi/MIUI shell permission restriction.  
Suggested fix: Clear app data manually from Android Settings, uninstall/reinstall manually, or use a test device/emulator that allows shell app-data clear.  
Status: Open

## Bug ID: TL-QA-14A-003
Title: Device A cannot be navigated with `adb shell input tap`  
Severity: Low  
Area: QA Environment  
Steps to reproduce:
1. Launch app on Device A `HAF6ZXGI5TINKJCA`.
2. Run `adb -s HAF6ZXGI5TINKJCA shell input tap 355 2143`.
Expected: Bottom navigation tap triggers Messages tab.  
Actual: Android throws `SecurityException` for `INJECT_EVENTS`.  
Evidence: Command output during Phase 14A screenshot attempt.  
Likely cause: Device/ROM security setting blocks shell input injection.  
Suggested fix: Enable USB debugging security settings if available, use manual taps by tester, or use a device/emulator that permits shell input.  
Status: Resolved in retest - after Xiaomi developer setting changes, `adb shell input keyevent`, `tap`, and `swipe` returned cleanly on `HAF6ZXGI5TINKJCA`, and first-run setup was completed to Home.

## Bug ID: TL-QA-14A-004
Title: Messages Hub screenshot is not valid due blocked navigation
Severity: Low  
Area: QA Evidence  
Steps to reproduce:
1. Attempt to navigate from Home to Messages using `adb shell input tap`.
2. Capture `docs/qa/screenshots/phase14a/02-messages-hub.png`.
Expected: Messages Hub screenshot.  
Actual: Navigation command failed, so screenshot cannot be treated as Messages Hub evidence.  
Evidence: `INJECT_EVENTS` failure; screenshot capture after failed tap.  
Likely cause: QA device automation limitation, not app behavior.  
Suggested fix: Capture manually on device or use a navigable test target.  
Status: Superseded by retest - valid `02-messages-hub.png` and `02-messages-hub-active.png` were captured on Samsung.

## Bug ID: TL-QA-14A-005
Title: PowerShell blocks direct `npm` command
Severity: Low  
Area: Backend / QA Environment  
Steps to reproduce:
1. Run `npm run` from PowerShell in `backend`.
Expected: npm scripts are listed.  
Actual: PowerShell refuses `npm.ps1` because it is not digitally signed.  
Evidence: Phase 14A command output.  
Likely cause: Windows PowerShell execution policy.  
Suggested fix: Use `npm.cmd run`, `cmd /c npm run`, or update local execution policy.  
Status: Open

## Bug ID: TL-QA-14A-006
Title: Two-device lifecycle propagation remains unverified
Severity: Medium  
Area: Offline Channel / Groups / Sync  
Steps to reproduce:
1. Device A creates offline channel/group.
2. Device B joins and connects.
3. Device A ends channel or archives group.
4. Observe Device B state.
Expected: Device B receives ended/archived state, clears active channel/group, disables send/connect/PTT, keeps history read-only.  
Actual: Not tested in Phase 14A due navigation automation blockers.  
Evidence: Source tests pass, but no physical propagation evidence.  
Likely cause: Manual two-device test still pending.  
Suggested fix: Run the manual test in `TWO_DEVICE_TEST_PLAN.md`.  
Status: Open

## Bug ID: TL-QA-14A-007
Title: Offline-only trip creates SQLite channel but Offline Channel UI says no channels  
Severity: High  
Area: Offline Channel / Trip / Data  
Steps to reproduce:
1. Complete first-run setup on Samsung.
2. Create an Offline Only trip named `QA_Offline_Trip`.
3. Open Home and confirm active trip summary shows channel `TL-OFF-BL4C`.
4. Open Offline Channels from the Home Channels card.
Expected: Offline Channel list shows `QA_Offline_Trip` / `TL-OFF-BL4C`, active status, and detail/chat actions.  
Actual: Offline Channel list shows `No offline channels yet`.  
Evidence: `docs/qa/screenshots/phase14a/03-home-active-offline-trip.png`, `13-offline-channels.png`; SQLite inspection showed `offline_channels.is_active=1`, `channel_status=active`, `channel_code=TL-OFF-BL4C`, and active owner membership.  
Likely cause: Offline channel list repository/query is not reading the same `offline_channels` rows created by `TripSessionRepository.createOfflineOnlyTrip`, or filtering on a stale/legacy field not populated by the trip wizard.  
Suggested fix: Trace OfflineChannelRepository list/active-channel queries against the trip-wizard creation path; add a regression test that an offline-only trip-created channel appears in Offline Channel list and active-channel provider.  
Status: PARTIAL after Phase 14C - Device A Offline Channels list shows the trip-created channel, but Device B join did not update Home active trip/channel. See TL-QA-14C-001.

## Bug ID: TL-QA-14A-008
Title: Nearby Peers and Connectivity Guidance do not detect active offline trip channel  
Severity: High  
Area: Nearby / Connectivity / Offline Channel  
Steps to reproduce:
1. Create Offline Only trip `QA_Offline_Trip`.
2. Confirm Home shows active channel `TL-OFF-BL4C`.
3. Open Nearby Peers.
4. Open Connectivity Guidance.
Expected: Both screens use the active offline channel and show discovery/guidance controls for that channel.  
Actual: Nearby Peers says `Please create or join an offline channel first`; Connectivity Guidance says `Create or join an offline channel to use peer guidance`.  
Evidence: `08-nearby-peers.png`, `12-connectivity-guidance.png`, plus SQLite evidence in the QA report.  
Likely cause: Same active-channel lookup mismatch as TL-QA-14A-007.  
Suggested fix: Centralize active offline channel resolution so Home, Offline Channels, Nearby, Connectivity, Offline Chat, PTT, and trip session all resolve the same active channel id/code.  
Status: Reopened in Phase 14C - Device A Nearby Peers and Connectivity Guidance still showed create/join channel prompts after active trip/channel creation. See TL-QA-14C-002 and TL-QA-14C-003.

## Bug ID: TL-QA-14A-009
Title: PTT card opens My Groups/backend screen instead of offline PTT for active offline trip  
Severity: High  
Area: PTT / Navigation / Offline Channel  
Steps to reproduce:
1. Create Offline Only trip `QA_Offline_Trip`.
2. Scroll Home to Offline Tools.
3. Tap the `PTT` card.
Expected: Group Walkie-Talkie / PTT screen opens for the active offline channel.  
Actual: My Groups screen opens and shows `Backend not reachable`.  
Evidence: `09-ptt.png`.  
Likely cause: Dashboard PTT route falls back to cloud group route when active offline channel lookup fails, or the card route is incorrectly wired for offline trips.  
Suggested fix: In Dashboard feature routing, when active trip mode is `offline`, route PTT to `/offline-channel/:channelId/ptt` using the active trip's `offline_channel_id`; add a widget/source test for offline trip PTT card navigation.  
Status: Reopened in Phase 14C - Device A Dashboard PTT card routed to Trip Setup Wizard instead of offline PTT. See TL-QA-14C-004.

## Bug ID: TL-QA-14A-010
Title: Offline chat opens but composer/input is not visible in captured state  
Severity: Medium  
Area: Offline Chat / UI  
Steps to reproduce:
1. Create Offline Only trip `QA_Offline_Trip`.
2. Open Messages.
3. Tap `Offline Channel Chat`.
Expected: Offline chat shows header, message list, and text composer with media disabled/online-only copy.  
Actual: Captured screen shows header and chips, but no visible text composer/input at bottom.  
Evidence: `05-offline-chat.png`.  
Likely cause: Chat body/composer may be hidden behind the shell bottom navigation, not mounted for zero-message state, or blocked by missing active-channel state.  
Suggested fix: Inspect `OfflineChatScreen` layout and active-channel conditions; add a widget/device test that the offline composer is visible for an active usable channel.  
Status: Resolved in Phase 14I - Samsung `R58R85Q2HWH` now shows the offline chat header, message area, no-peer queue hint, composer/input, send button, and global bottom nav together. Zero-peer send creates a local queued/ack-timeout message. See `docs/qa/PHASE_14I_CHAT_SHELL_COMPOSER_QA_REPORT.md` and `docs/qa/final_offline_chat_composer_visible_wait.png`.

## Bug ID: TL-QA-14D-001
Title: Trip setup wizard keeps Nearby permission readiness missing after grant
Severity: Medium
Area: Trip Setup / Nearby Permission
Steps to reproduce:
1. Open Trip Setup Wizard readiness.
2. Grant Nearby permissions.
3. Return to readiness list.
Expected: Nearby permission status updates to Ready, or Blocked if Android reports permanently denied.
Actual: Readiness was hardcoded as Missing.
Evidence: `trip_setup_wizard_screen.dart` used `_ReadinessState.missing` for `Nearby permission`.
Likely cause: Readiness rendering did not use a check-only permission service result.
Suggested fix: Add check-only Nearby permission status mapping and refresh readiness after grant.
Status: Resolved in source and tests in Phase 14D - `NearbyPermissionService.check()` and `NearbyPermissionReadiness` now drive wizard readiness; `test/nearby_permission_readiness_test.dart` passes.

## Bug ID: TL-QA-14C-001
Title: Joining offline channel on second device does not update Home active trip/channel  
Severity: High  
Area: Trip / Offline Channel / Data  
Steps to reproduce:
1. Device A creates Offline Only trip `QA_P2P_Trip_A`.
2. Device A receives channel `TL-OFF-XVZG`.
3. Device B opens Join Channel and enters `TL-OFF-XVZG`.
4. Device B opens channel detail successfully.
5. Return Device B to Home.
Expected: Device B Home shows active trip/channel `TL-OFF-XVZG`, or the joined channel is clearly set as the active offline channel.  
Actual: Device B channel detail shows `TL-OFF-XVZG`, but Home still shows old active trip/channel `QA_Offline_Trip` / `TL-OFF-BL4C`.  
Evidence: `docs/qa/screenshots/phase14c/02-device-b-channel-joined.png`, `docs/qa/screenshots/phase14c/03-device-b-home-active-trip.png`.  
Likely cause: Join Channel flow creates/opens a channel row but does not update active trip session, active channel setting, or dashboard source-of-truth consistently.  
Suggested fix: After successful channel join, set the joined channel active and either create/update an active offline trip session or make Home resolve active joined channels without requiring an active trip row.  
Status: PARTIAL after Phase 14D - join activation code was added through `TripSessionRepository.activateOfflineChannelTrip(...)`, but Samsung was not freshly rejoined after installing the Phase 14D APK. Existing Phase 14D Samsung evidence still shows old `TL-OFF-BL4C`.

## Bug ID: TL-QA-14C-002
Title: Nearby Peers still says create/join channel after active offline trip exists  
Severity: High  
Area: Nearby / Offline Channel / Provider State  
Steps to reproduce:
1. Device A creates Offline Only trip `QA_P2P_Trip_A`.
2. Confirm Home shows `TL-OFF-XVZG`.
3. Confirm Offline Channels list shows `QA_P2P_Trip_A`, `TL-OFF-XVZG`, `Active`.
4. Tap Nearby Peers.
Expected: Nearby Peers shows active channel code and discovery/advertising controls.  
Actual: Nearby Peers shows `Please create or join an offline channel first.`  
Evidence: `docs/qa/screenshots/phase14c/06-device-a-nearby-no-channel-fail.png`.  
Likely cause: Runtime Nearby provider path is not resolving the same channel that Offline Channels list resolves, despite Phase 14B source wiring.  
Suggested fix: Add an integration/device-level provider test around real `TripSessionRepository.createOfflineOnlyTrip` followed by Nearby screen load; inspect provider invalidation and resolver instance/data-source lifecycle.  
Status: Resolved in Phase 14D on Xiaomi - `04-xiaomi-nearby-active-channel.png` shows `TL-OFF-XVZG` and discovery/advertising controls instead of the create/join prompt.

## Bug ID: TL-QA-14C-003
Title: Connectivity Guidance still shows no-channel prompt after active offline trip exists  
Severity: High  
Area: Connectivity / Offline Channel / Provider State  
Steps to reproduce:
1. Device A creates Offline Only trip `QA_P2P_Trip_A`.
2. Confirm Home and Offline Channels list show `TL-OFF-XVZG`.
3. Tap Compass / Connectivity Guidance.
Expected: Connectivity Guidance shows channel-aware no-peer state and Start Nearby Discovery.  
Actual: Connectivity Guidance shows `Create or join an offline channel to use peer guidance.`  
Evidence: `docs/qa/screenshots/phase14c/07-device-a-connectivity-no-channel-fail.png`.  
Likely cause: Connectivity controller/screen is not receiving the repaired active channel at runtime, or it reads before repair and is not invalidated.  
Suggested fix: Force resolver repair before Connectivity controller summary load and add runtime test using persisted trip/channel rows.  
Status: Resolved in Phase 14D on Xiaomi - `05-xiaomi-connectivity-active-channel.png` shows `TL-OFF-XVZG` and channel-aware no-peer guidance instead of the no-channel prompt.

## Bug ID: TL-QA-14C-004
Title: Dashboard PTT card opens Trip Setup Wizard instead of offline PTT  
Severity: High  
Area: PTT / Dashboard Routing / Offline Channel  
Steps to reproduce:
1. Device A creates Offline Only trip `QA_P2P_Trip_A`.
2. Scroll Home to Offline Tools.
3. Tap PTT card.
Expected: Offline PTT screen opens for `/offline-channel/:channelId/ptt`.  
Actual: Trip Setup Wizard opens.  
Evidence: `docs/qa/screenshots/phase14c/08-device-a-ptt-routes-trip-setup-fail.png`.  
Likely cause: Dashboard runtime PTT handler receives `null` from active channel provider even though Home displays active trip/channel.  
Suggested fix: Make Dashboard route resolution use the active trip's channel id/code fallback directly when the resolver returns null, then repair the resolver state.  
Status: Resolved in Phase 14D on Xiaomi - `06-xiaomi-offline-ptt-from-dashboard.png` shows the offline PTT screen for `QA_P2P_Trip_A`, not My Groups or Trip Setup Wizard.

## Bug ID: TL-QA-14C-005
Title: Offline Channel Chat from Messages Hub opens blank and composer is missing  
Severity: Critical  
Area: Offline Chat / Navigation / UI  
Steps to reproduce:
1. Device A creates Offline Only trip `QA_P2P_Trip_A`.
2. Open Messages.
3. Tap Offline Channel Chat.
Expected: Offline Chat opens with header, message list, queue hint, text composer, and send button.  
Actual: App displays a blank Flutter surface; UiAutomator only sees root `FrameLayout`; composer is absent.  
Evidence: `docs/qa/screenshots/phase14c/09-device-a-offline-chat-result.png`, `docs/qa/logs/phase14c/device-a-xiaomi-logcat-tail.txt`.  
Likely cause: Offline Chat route is entered with an invalid/null channel id, an unresolved provider future, or a render failure not captured as a fatal crash in the logcat tail.  
Suggested fix: Reproduce with full `flutter run` logs, add route parameter validation and visible error fallback, and add widget/integration coverage for Messages Hub -> Offline Channel Chat.  
Status: PARTIAL after Phase 14D - fallback channel routing, shell nav hiding for offline chat, and inline composer code were added; `flutter test` passes. Final physical screenshot proof is still not PASS because Xiaomi entered setup during route/deep-link attempts before a valid composer capture.
