# TrailLink Phase 14C P2P Results

## Phase 14D Retest Update - 2026-05-09

| Test | Result | Notes |
|---|---:|---|
| Xiaomi active channel resolution | PASS | Xiaomi Home, Offline Channels, Nearby, Connectivity, and PTT all resolve `TL-OFF-XVZG`. |
| Samsung same-channel join after fix | PARTIAL | Not rerun after Phase 14D APK install; available Samsung evidence still shows old channel `TL-OFF-BL4C`. |
| Nearby discovery/connect | NOT TESTED | Requires fresh same-channel state on both devices. |
| Offline text chat transfer | NOT TESTED | Requires peer connection. |
| Offline SOS transfer | NOT TESTED | Requires peer connection. |
| Offline location sharing | NOT TESTED | Requires peer connection and GPS permission. |
| Voice-note PTT transfer | NOT TESTED | Requires peer connection and microphone permission. |
| Live radio gating | NOT TESTED | Requires live radio setting enabled and connected peers. |
| Offline media guard | NOT TESTED | Not rerun after Phase 14D. |
| Offline Chat composer visual | PARTIAL | Source/tests updated; final device screenshot not captured after Xiaomi entered setup flow. |

Phase 14D is a runtime routing/resolution fix pass, not a completed P2P PASS. The P2P transfer matrix remains pending.

Date: 2026-05-09

## Test Matrix

| Test | Device(s) | Result | Actual |
| --- | --- | --- | --- |
| Build debug APK | Local | PASS | APK built successfully. |
| Install APK | A + B | PASS | Both installs returned `Success`. |
| Create Offline Only trip | A | PASS | `QA_P2P_Trip_A`, `TL-OFF-XVZG` created. |
| Join channel code | B | PARTIAL | B opened `TL-OFF-XVZG` detail, but Home stayed on old `TL-OFF-BL4C`. |
| Offline Channels list | A | PASS | A listed `QA_P2P_Trip_A`, `TL-OFF-XVZG`, `Active`. |
| Nearby active channel detection | A | FAIL | Nearby still showed create/join prompt. |
| Connectivity active channel detection | A | FAIL | Connectivity still showed create/join prompt. |
| Nearby discovery/connect | A + B | BLOCKED | Could not start because Nearby did not resolve active channel. |
| Offline text chat | A + B | FAIL | A Offline Chat opened blank; no composer. |
| Offline SOS | A + B | BLOCKED | No peer connection. |
| Offline location | A + B | BLOCKED | No peer connection. |
| Voice-note PTT | A + B | FAIL | Dashboard PTT opened trip setup instead of offline PTT. |
| Live Radio | A + B | NOT TESTED | Requires connected peers and enabled setting. |
| Disconnect presence | A + B | BLOCKED | No connected peer state. |
| Offline media guard | A | BLOCKED | Offline Chat blank. |
| Mode switch | A | NOT TESTED | Stopped after active-channel blockers. |

## Key Evidence

### Device A

- Active Home trip: `QA_P2P_Trip_A`
- Active Home channel: `TL-OFF-XVZG`
- Offline Channels list: channel visible and active
- Nearby: no-channel prompt
- Connectivity: no-channel prompt
- PTT card: trip setup wizard
- Offline Chat: blank surface

### Device B

- Joined channel detail: `TL-OFF-XVZG`
- Home active trip remained: `QA_Offline_Trip`
- Home active channel remained: `TL-OFF-BL4C`

## Runtime Conclusion

Phase 14B source/widget tests passed, but Phase 14C device testing shows the runtime provider/navigation state is still inconsistent. The resolver-backed logic is not reaching all runtime paths after real trip creation and route navigation.

P2P transfer tests could not be executed because the app could not reliably place both devices into the same active channel with Nearby discovery controls available.
