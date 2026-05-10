# TrailLink Phase 14A Next Fix Recommendations

## 1. Must Fix Before Final Demo

1. Fix active offline channel lookup across Trip, Offline Channels, Nearby, Connectivity, Offline Chat, and PTT.
   - Category: two-device P2P fix / data sync fix
   - Reason: The trip wizard creates an active SQLite channel, but user-facing offline tools still say no channel exists. This blocks two-device testing.
2. Fix offline PTT navigation from the active offline trip dashboard.
   - Category: PTT/live radio fix / UI navigation fix
   - Reason: The PTT card currently opens My Groups/backend error instead of offline PTT for an offline-only trip.
3. Fix offline chat composer visibility for active offline channels.
   - Category: offline chat UI fix
   - Reason: Offline chat opens, but the input/composer was not visible in the captured state.
4. Complete manual two-device Nearby test after the active-channel bug is fixed.
   - Category: two-device P2P fix
   - Reason: Offline chat, SOS relay, location sharing, PTT, live radio, and lifecycle propagation depend on this.
5. Verify channel/group end/archive propagation on real devices.
   - Category: two-device P2P fix / backend fix
   - Reason: Source tests pass, but the user-visible lifecycle behavior is not yet physically verified.

## 2. Should Fix Before Supervisor Review

1. Create a deterministic QA reset path.
   - Category: data sync fix
   - Reason: Xiaomi still blocks `pm clear`; QA needs a reliable app-level reset method without touching production data.
2. Add a debug-only route launcher or QA build flag.
   - Category: UI polish / QA tooling
   - Reason: ADB input now works on both connected phones, but a route launcher would still make repeat screenshot capture and regression testing faster.
3. Confirm physical-device API base URL.
   - Category: backend fix
   - Reason: Physical phones need LAN backend URL, not emulator-only `10.0.2.2`.
4. Run backend smoke tests against a disposable QA MongoDB.
   - Category: backend fix / data sync fix
   - Reason: Current backend health passes, but mutation flows were not run in Phase 14A.
5. Keep the corrected screenshot capture method in the QA runbook.
   - Category: QA tooling
   - Reason: PowerShell redirection corrupts `adb exec-out screencap -p` binary output on this machine.

## 3. Nice To Have

1. Add automated screenshot tests for stable widget states.
   - Category: UI polish
2. Add a QA checklist page inside the app for debug builds only.
   - Category: UI polish / QA tooling
3. Add explicit diagnostics for map provider and API base URL in developer-only mode.
   - Category: map fix / backend fix

## 4. Future Work

1. Offline tile caching strategy for maps.
   - Category: map fix
2. Live radio quality telemetry and audio glitch reporting.
   - Category: PTT/live radio fix
3. Production media storage migration from local backend disk to object storage.
   - Category: backend fix

## Recommended Next Codex Prompt Category

Recommended next prompt: active offline channel lookup and navigation fix.

Reason: Automated checks are healthy, but the retest shows the app creates an active offline channel in SQLite while Offline Channels, Nearby, Connectivity, and PTT cannot resolve it. Two-device P2P testing should resume only after this blocker is fixed.
