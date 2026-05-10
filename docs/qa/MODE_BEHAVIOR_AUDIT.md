# TrailLink Phase 14A Mode Behavior Audit

Result values: PASS, FAIL, PARTIAL, NOT TESTED, BLOCKED.

## Retest Addendum - 2026-05-09

| Case | Result | Evidence / Notes |
| --- | --- | --- |
| Auto mode with backend unavailable | PARTIAL | Samsung UI showed `Auto - Offline`, `Sync Paused`, and offline tools after setup. |
| Offline tool routing with active offline trip | FAIL | Active offline trip dashboard shows channel `TL-OFF-BL4C`, but Nearby and Connectivity behave as if no channel exists, and PTT opens My Groups/backend error. |

| Case | Expected | Result | Evidence / Notes |
| --- | --- | --- | --- |
| Auto Mode, backend reachable | Online UI/features when backend reachable. | PARTIAL | Mode engine tests pass; manual Auto device switch not tested. |
| Auto Mode, backend unavailable | Offline UI/features when backend unavailable. | PARTIAL | Mode engine tests pass; backend-down device scenario not tested. |
| Manual Offline with internet available | App remains offline, cloud sync paused, offline tools visible. | PASS | Device A Home screenshot shows Offline Mode, Offline Tools, Sync Paused while device is network-capable. |
| Manual Online with backend unavailable | Online selected but data queued/warning shown. | NOT TESTED | Requires manual mode change and backend outage. |
| Auto mode button state | Auto switch disabled or automatic state indicated. | PARTIAL | Source and tests cover mode controls; manual bottom-sheet not captured. |
| Manual mode button state | Manual switch enabled and selected state persists. | PARTIAL | Source/tests cover mode keys; restart persistence not manually tested. |
| Mode bottom sheet works | User can switch Auto/Online/Offline. | NOT TESTED | Device input automation blocked. |
| Online feature cards appear online | Cloud tools visible online. | PARTIAL | Source logic verified. Device online mode not captured. |
| Offline feature cards appear offline | Offline tools visible offline. | PASS | Device A Home screenshot shows offline feature cards. |
| Disabled features show disabled state | Disabled cards should explain settings state. | PARTIAL | Source contains disabled card snackbar; manual not tested. |
| Cloud chat open then backend lost | Screen remains open and queues locally. | NOT TESTED | Requires live device/backend outage. |
| SOS during mode change | SOS remains available and location optional. | PARTIAL | Automated SOS location tests pass; live mode-change SOS not tested. |
| `/home/status` diagnostics removal | Technical status route should not open diagnostics. | PASS | Automated test verifies route redirects away from diagnostics. |
