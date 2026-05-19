# Phase 14I P2P Session Lifecycle Report

## Summary

Phase 14I adds an app-level P2P session lifecycle above Android Nearby. The goal is to prevent TrailLink from silently keeping an old Nearby/Bluetooth session alive when the user creates, joins, or activates another trip/channel.

## Root Cause

Trip and channel activation previously updated SQLite active trip/channel flags, but Nearby connection state lived only in the transport and `nearby_peers` compatibility table. That meant the app could show a new active trip while the live Nearby session still belonged to an old channel.

## Architecture

- SQLite version is bumped to `21`.
- `p2p_connection_sessions` stores the single app-level active P2P session.
- `p2p_connected_peers` stores peers for that session, including `stale` state for the 30-120 second heartbeat window.
- `P2PSessionService` owns session start/stop and peer state updates.
- `P2PDisconnectService` sends a best-effort `trip_session_leave` packet, stops Nearby, disconnects endpoints, and clears the active session.
- `P2PSessionGuard` provides trip-switch decisions and disconnect-before-switch behavior.

## Trip Switch Rules

- Switching to the same trip is allowed.
- Switching while a session is advertising, discovering, connecting, connected, or disconnecting requires confirmation.
- `Disconnect & Switch` releases the current P2P session first.
- `Create as Inactive` saves the new trip/channel without changing the active session.
- `Cancel` leaves the current trip/session unchanged.

## UI Behavior

- Nearby shows whether the current active trip owns the P2P session.
- If the active P2P session belongs to another trip, Nearby shows a warning and a disconnect action.
- Trip setup, join channel, channel details, and trip management use the disconnect validation dialog before switching.

## Packet Handling

- New `trip_session_leave` packet type marks the sender disconnected without deleting membership or history.
- Heartbeat packets update the app-level P2P peer heartbeat state.

## Automated Tests

Planned command set:

```powershell
flutter analyze
flutter test test\phase14i_p2p_session_lifecycle_test.dart
flutter test test\phase14b_active_channel_resolution_test.dart
flutter test test\phase14g_trip_channel_chat_context_test.dart
flutter test test\phase14n_fresh_p2p_sos_location_test.dart
flutter test
flutter build apk --debug
```

Results from this implementation pass:

| Command | Result |
| --- | --- |
| `flutter analyze` | PASS - no issues found |
| `flutter test test\phase14i_p2p_session_lifecycle_test.dart` | PASS - 6 tests |
| `flutter test test\phase14b_active_channel_resolution_test.dart` | PASS - 14 tests |
| `flutter test test\phase14g_trip_channel_chat_context_test.dart` | PASS - 7 tests |
| `flutter test test\phase14n_fresh_p2p_sos_location_test.dart` | PASS - 6 tests |
| `flutter test` | PASS - 166 tests |
| `flutter build apk --debug` | PASS - `build\app\outputs\flutter-apk\app-debug.apk` |

## Manual Two-Phone QA Guide

1. Fresh install the debug APK on both phones.
2. Use Manual Mode -> Offline.
3. Device A creates Trip A and starts Nearby advertising/discovery.
4. Device B joins Trip A and connects.
5. On Device A, try to create/join/activate Trip B.
6. Confirm the validation dialog appears.
7. Test `Cancel`: Trip A session remains active.
8. Test `Create as Inactive`: Trip B exists but Trip A remains active and connected.
9. Test `Disconnect & Switch`: leave packet is sent, endpoints disconnect, Trip B becomes active.
10. Leave one peer idle for more than 30 seconds and verify stale state; after 120 seconds verify disconnected/lost state.

## Remaining Risks

- `trip_session_leave` is best-effort. If Android Nearby drops the payload during disconnect, the peer still becomes stale/lost by heartbeat cleanup.
- Existing `nearby_peers` remains for compatibility; new P2P session tables are the authoritative lifecycle source.
- Physical Nearby behavior still depends on Android radio state, permissions, distance, and OS background limits.
