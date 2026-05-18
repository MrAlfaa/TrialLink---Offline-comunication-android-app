# Phase 14J Cloud-Prepared Offline Metadata Report

## Summary
Phase 14J adds cloud-prepared offline metadata so an online-created or online-joined trip can continue with cached offline fallback data when backend connectivity fails. The implementation prepares a shared trip, primary offline channel, default `General` chat, and member/device roster in the backend, then caches the same metadata in SQLite.

Cloud metadata is used only for peer recognition and validation. It does not pretend to auto-connect Nearby/Bluetooth. Actual P2P still requires permissions, advertising, discovery, connection handshake, and available devices.

## Root Cause And Design Rationale
Before this phase, online/cloud trip creation and offline fallback metadata were not one atomic product concept. A user could create an online group/trip, then later lose backend connectivity without a complete local offline channel/chat/roster cache for the same trip. That made offline fallback depend on separate local trip/channel setup rather than the online trip itself.

The fix introduces cloud-prepared trip metadata:
- Backend creates or returns one shared `tripId`, `channelId`, `chatId`, `cloudGroupId`, and `channelCode`.
- Flutter writes those shared IDs into SQLite.
- Nearby advertisement stays compact as `TL3|...` for Android BLE endpoint limits.
- A full `peer_hello` JSON packet is sent after connection for stronger identity validation.
- Peers are marked as verified/cached/unknown/mismatch using cached roster data, never Bluetooth MAC address.

## Backend Changes
Added authenticated endpoints under `/api/trip-context`:
- `POST /cloud-prepared-trips`
- `POST /cloud-prepared-trips/join`
- `GET /cloud-prepared-trips/:tripId/metadata`

Added backend persistence:
- `memberDeviceProfile.model.js` stores `appDeviceId`, `publicUserId`, optional `localUserId`, display name, phone, capabilities, and `lastSeenAt`.
- `trip.model.js` now supports `ownerUserId`, `primaryChannelId`, `offlineBackupReady`, and `cloudPreparedAt`.
- `tripChannel.model.js` now supports `channelKeyHash`.

The smoke script `backend/scripts/phase14j-cloud-prepared-metadata-smoke.js` verifies owner create, member join, metadata refresh, shared IDs, roster entries, and absence of raw MAC fields.

## SQLite And Local Cache
`LocalDatabase` is now version `22`.

Added local metadata:
- `trip_sessions.offline_backup_ready`
- `trip_sessions.cloud_prepared_at`
- `trip_sessions.primary_channel_id`
- `offline_channels.offline_backup_ready`
- `offline_channels.cloud_prepared_at`
- `offline_channels.primary_channel_id`
- `offline_channels.channel_key_hash`
- `cloud_trip_member_devices`
- `nearby_peers.trip_id`
- `nearby_peers.public_user_id`
- `nearby_peers.app_device_id`
- `nearby_peers.verification_status`

`CloudPreparedTripRepository` writes backend metadata into:
- `local_groups`
- `trip_sessions`
- `offline_channels`
- `chat_rooms`
- `local_group_members`
- `offline_channel_members`
- `cloud_trip_member_devices`
- active channel settings
- default known-member validation policy for cloud-prepared trips

## Advertisement And Peer Validation
Nearby endpoint names now use compact TL3 format to stay below Android Nearby BLE endpoint-size constraints:

```text
TL3|channelCode|userId|channelId|tripId|publicUserId|appDeviceId|displayName|deviceName|capabilities
```

After a Nearby connection succeeds, the transport sends a `peer_hello` packet with full semantic fields:
- app id/protocol version
- trip id
- channel id/code
- local/public user ids
- app device id
- display name
- capabilities
- timestamp

`PeerValidationService` returns:
- `verifiedMember`
- `cachedMember`
- `unknownSameChannel`
- `mismatch`

Trip/channel mismatches are rejected. Same-channel unknown peers are only allowed when the trip policy allows them.

## UI Changes
Minimal UI changes only:
- Online create/join flows use `CloudPreparedTripRepository`.
- Successful online trip/group creation or join shows `Offline backup prepared`.
- Trip management cards show cloud/offline readiness, channel code, cached member count, and cached device count.
- Nearby peer cards show validation status: verified member, cached member, unknown peer, or trip mismatch.

## Files Changed
Backend:
- `backend/package.json`
- `backend/scripts/phase14j-cloud-prepared-metadata-smoke.js`
- `backend/src/models/memberDeviceProfile.model.js`
- `backend/src/models/trip.model.js`
- `backend/src/models/tripChannel.model.js`
- `backend/src/modules/tripContext/tripContext.controller.js`
- `backend/src/modules/tripContext/tripContext.routes.js`
- `backend/src/modules/tripContext/tripContext.service.js`
- `backend/src/modules/tripContext/tripContext.validation.js`

Flutter:
- `lib/core/database/local_database.dart`
- `lib/core/identity/current_user_actor.dart`
- `lib/features/groups/presentation/create_group_screen.dart`
- `lib/features/groups/presentation/join_group_screen.dart`
- `lib/features/nearby/data/models/nearby_advertisement_payload.dart`
- `lib/features/nearby/data/models/nearby_peer_model.dart`
- `lib/features/nearby/data/nearby_connections_transport.dart`
- `lib/features/nearby/data/nearby_packet_transport.dart`
- `lib/features/nearby/data/nearby_repository.dart`
- `lib/features/nearby/data/peer_validation_service.dart`
- `lib/features/nearby/presentation/nearby_controller.dart`
- `lib/features/nearby/presentation/widgets/peer_card.dart`
- `lib/features/trip/data/trip_session_model.dart`
- `lib/features/trip/presentation/trip_setup_screen.dart`
- `lib/features/trip/presentation/trip_setup_wizard_screen.dart`
- `lib/features/trip_context/data/cloud_prepared_trip_api.dart`
- `lib/features/trip_context/data/cloud_prepared_trip_repository.dart`
- `lib/features/trip_context/data/models/cloud_prepared_trip_metadata.dart`
- `lib/features/trip_context/data/trip_member_device_roster_repository.dart`
- `lib/features/trip_context/presentation/trip_management_screen.dart`

Tests:
- `test/phase14j_cloud_prepared_offline_metadata_test.dart`
- Updated schema-version/source-contract expectations in existing tests after DB v22/TL3 migration.

## Command Results
Source verification:
- `flutter analyze` - PASS, no issues.
- `flutter test test\phase14j_cloud_prepared_offline_metadata_test.dart` - PASS, 5 tests.
- `flutter test test\phase14i_p2p_session_lifecycle_test.dart` - PASS, 6 tests.
- `flutter test test\phase14g_trip_channel_chat_context_test.dart` - PASS, 7 tests.
- `flutter test test\phase14n_fresh_p2p_sos_location_test.dart` - PASS, 6 tests.
- `flutter test` - PASS, 171 tests.
- `flutter build apk --debug` - PASS.
- `node --check` for changed backend modules and smoke script - PASS.
- `cd backend && npm.cmd run test:phase14j` - PASS.

Backend runtime:
- Backend started on port `5001`.
- `/api/health` returned success.
- `npm.cmd install` was required because `backend/node_modules` was missing locally.
- `npm install` reported one moderate dependency vulnerability; no dependency update was made in this phase.

## Device QA Evidence
Evidence folder:
- `docs\qa\phase14j_cloud_prepared_metadata\`

Captured:
- `launch-xiaomi.png`
- `launch-samsung.png`
- `launch-samsung.xml`
- `logcat-xiaomi.txt`
- `logcat-samsung.txt`
- `device-install-reset.txt`

Device setup:
- Xiaomi `HAF6ZXGI5TINKJCA`
- Samsung `R58R85Q2HWH`
- `adb reverse tcp:5000 tcp:5001` applied on both devices.
- Debug APK installed on both devices.
- `pm clear com.example.traillink` succeeded on both devices after install verification.

Physical QA status:
- Fresh install launch verified on both devices.
- Samsung reached the setup agreement screen and UI XML was captured.
- Xiaomi launch screenshot showed the splash screen in landscape with `BOTTOM OVERFLOWED BY 24 PIXELS`; this is an existing splash/orientation UI issue unrelated to cloud-prepared metadata.
- Full physical online create/join/offline-fallback validation was not completed in this automated pass because setup requires reliable device interaction through Flutter screens. Backend smoke verifies the cloud create/join metadata contract, but two-device user-flow QA remains pending.

## Manual Two-Device QA Guide
1. Start backend on port `5001`.
2. Run:
   ```powershell
   adb -s HAF6ZXGI5TINKJCA reverse tcp:5000 tcp:5001
   adb -s R58R85Q2HWH reverse tcp:5000 tcp:5001
   ```
3. Fresh install the debug APK on both devices.
4. Device A completes setup in Online or Auto mode.
5. Device A creates a cloud-prepared trip.
6. Confirm Device A shows `Offline backup prepared`.
7. Device B joins the same online trip/group code.
8. Confirm both devices show the same trip id/channel code/general chat.
9. Stop backend or block network.
10. Confirm both devices still resolve the cached active trip/channel/chat.
11. Open Nearby on both devices, connect peers, and confirm peer cards show verified/cached membership where roster data matches.
12. Test offline text delivery after backend is unavailable.

## Remaining Risks
- Cloud metadata improves recognition and validation only; it does not remove the need for Android permissions, radios, Nearby discovery, advertising, and connection handshake.
- TL3 endpoint data is intentionally compact and may include shortened identifiers; the full `peer_hello` packet is the stronger validation source after connection.
- Physical two-device end-to-end cloud create/join/offline fallback still needs a manual QA pass.
- Xiaomi splash landscape overflow should be fixed separately because it can block or confuse fresh-install setup on landscape devices.
