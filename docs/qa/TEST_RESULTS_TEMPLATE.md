# TrailLink Phase 14A Test Results Template

Use result values only: PASS, FAIL, PARTIAL, NOT TESTED, BLOCKED.

## Setup Flow

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SETUP-01 | Fresh launch | Clear app data, launch app | Splash/setup appears |  |  |  |
| SETUP-02 | Agreement | Open agreement, scroll, accept | Agreement readable and accepted |  |  |  |
| SETUP-03 | Profile setup | Enter name/email/phone/note | Local identity saved |  |  |  |
| SETUP-04 | Trip setup | Start/join trip | Dashboard shows active trip |  |  |  |

## Mode Flow

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| MODE-01 | Auto online | Backend reachable, set Auto | Online status/features |  |  |  |
| MODE-02 | Auto offline | Stop backend/network, set Auto | Offline status/features |  |  |  |
| MODE-03 | Manual offline | Internet available, set Offline | Offline tools, sync paused |  |  |  |
| MODE-04 | Manual online backend down | Backend unavailable, set Online | Warning/queue behavior |  |  |  |

## Online Chat

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| CHAT-ON-01 | Send text | Open cloud chat, send text | Local first, then synced |  |  |  |
| CHAT-ON-02 | Send image | Use plus attachment | Preview, upload, receiver sees image |  |  |  |
| CHAT-ON-03 | Send voice media | Record online voice note | Upload and playback work |  |  |  |

## Offline Chat

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| CHAT-OFF-01 | Send text connected | A sends to B | B receives and ACKs |  |  |  |
| CHAT-OFF-02 | Send text disconnected | Disconnect B, A sends | A queues message |  |  |  |
| CHAT-OFF-03 | Media blocked | Try media offline | Online-only message/no picker |  |  |  |

## Nearby Peers

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| NEAR-01 | Discovery | Start discovery on both phones | Peers visible |  |  |  |
| NEAR-02 | Connect | Tap connect | Connected status |  |  |  |
| NEAR-03 | Disconnect presence | Disable one peer | Recently seen/disconnected shown |  |  |  |

## SOS

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SOS-01 | Online SOS | Send with backend | Saved locally and uploaded |  |  |  |
| SOS-02 | Offline SOS | Send over Nearby | Peer receives emergency |  |  |  |
| SOS-03 | No location | Disable location, send | SOS not blocked |  |  |  |

## Location / Map

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| MAP-01 | Map render/fallback | Open Map | Tiles or fallback, not blank |  |  |  |
| MAP-02 | Get GPS | Tap Get GPS | Permission/GPS flow works |  |  |  |
| MAP-03 | Share location | Tap Share Location | Saved locally and delivered/synced |  |  |  |

## PTT

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| PTT-01 | Voice note send | Hold/release | Voice note sent |  |  |  |
| PTT-02 | Voice note receive | Peer plays note | Playback works |  |  |  |
| PTT-03 | Floor control | Both try speaking | One speaker at a time |  |  |  |

## Live Radio

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| RADIO-01 | Disabled default | Open PTT | Live Radio disabled by default |  |  |  |
| RADIO-02 | Enable acknowledgement | Enable in settings | Experimental acknowledgement stored |  |  |  |
| RADIO-03 | Stream | A streams, B listens | Near-live audio or fallback |  |  |  |

## Media

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| MEDIA-01 | Image upload | Online cloud chat plus image | Upload and render |  |  |  |
| MEDIA-02 | Voice upload | Online voice note | Upload and playback |  |  |  |
| MEDIA-03 | Offline guard | Offline chat | Attach hidden/blocked |  |  |  |

## App Lock

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| LOCK-01 | PIN setup | Set 4 digit PIN | PIN accepted |  |  |  |
| LOCK-02 | PIN unlock | Lock then PIN | Dashboard opens |  |  |  |
| LOCK-03 | Biometric unlock | Lock then fingerprint | Dashboard opens once, no relock |  |  |  |
| LOCK-04 | Quick SOS | Lock screen SOS | SOS remains available |  |  |  |

## Sync

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| SYNC-01 | Pending offline item | Send offline/no peer | Pending saved |  |  |  |
| SYNC-02 | Resume online | Restore backend | Pending syncs once |  |  |  |
| SYNC-03 | Duplicate prevention | Replay same packet | No duplicate server row |  |  |  |

## Bridge Mode

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| BRIDGE-01 | Bridge text | B offline -> A online bridge | Backend receives bridged text |  |  |  |
| BRIDGE-02 | Bridge SOS | B offline SOS -> A bridge | Backend receives emergency |  |  |  |
| BRIDGE-03 | Bridge duplicate | Replay packet | Duplicate skipped |  |  |  |

## Back Navigation

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| BACK-01 | Details back | Open details, press back | Returns to previous hub/list |  |  |  |
| BACK-02 | Chat back | Open chat, press back | Returns to Messages/details |  |  |  |

## UI Quality

| Test ID | Test Case | Steps | Expected | Actual | Result | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| UI-01 | No overflow | Inspect all main screens | No RenderFlex overflow |  |  |  |
| UI-02 | Bottom nav padding | Scroll lists/chat | Content not hidden |  |  |  |
| UI-03 | Compact mode UI | Open feature screens | No giant mode banners |  |  |  |

