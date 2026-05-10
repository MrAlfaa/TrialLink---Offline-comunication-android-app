# Phase 14G Trip Channel Chat Architecture Report

Date: 2026-05-09

## Bug Summary

TrailLink had several overlapping state concepts: active trip, active offline channel, online group, offline chat, nearby peers, and local/cloud messages. Older screens could resolve an active offline channel, but there was no single local-first context that represented the user-facing hierarchy:

Trip -> Channel -> Chat.

This phase implements the practical MVP hierarchy:

- one active trip
- one active channel for that trip
- one active default `General` chat for the channel
- nullable `chat_id` metadata on offline and cloud messages for future multiple-chat support

## Root Cause

The active state was stored and resolved in separate places. `TripSessionRepository` managed trip activation, `OfflineChannelRepository` managed a globally active offline channel, and chat messages were tied only to group/channel IDs. That made it hard for tools like Nearby, Connectivity, PTT, SOS, and Chat to agree on the same active operational context.

The previous active-channel resolver was useful, but it only solved one level of the model. Phase 14G folds that behavior into `TripContextService`, while preserving the older provider names so existing screens continue to work.

## Files Changed

Flutter:

- `lib/core/database/local_database.dart`
- `lib/features/trip/data/trip_session_model.dart`
- `lib/features/trip/data/trip_session_repository.dart`
- `lib/features/trip/data/trip_session_service.dart`
- `lib/features/offline_channel/data/models/offline_channel_model.dart`
- `lib/features/offline_channel/presentation/offline_channel_controller.dart`
- `lib/features/offline_chat/data/models/offline_text_message_model.dart`
- `lib/features/offline_chat/data/models/offline_packet_model.dart`
- `lib/features/offline_chat/data/offline_packet_service.dart`
- `lib/features/offline_chat/data/offline_message_local_data_source.dart`
- `lib/features/offline_chat/data/offline_chat_repository.dart`
- `lib/features/offline_chat/presentation/offline_chat_controller.dart`
- `lib/features/offline_chat/presentation/offline_chat_screen.dart`
- `lib/features/chat/data/models/chat_message_model.dart`
- `lib/features/chat/data/models/send_message_request.dart`
- `lib/features/chat/data/chat_api.dart`
- `lib/features/chat/data/chat_repository.dart`
- `lib/features/chat/data/message_dao.dart`
- `lib/features/chat/data/message_sync_service.dart`
- `lib/features/chat/presentation/chat_controller.dart`
- `lib/features/chat/presentation/chat_screen.dart`
- `lib/features/dashboard/dashboard_screen.dart`
- `lib/app/router.dart`
- `lib/features/trip_context/data/models/active_trip_context.dart`
- `lib/features/trip_context/data/models/chat_room_model.dart`
- `lib/features/trip_context/data/trip_context_service.dart`
- `lib/features/trip_context/presentation/trip_management_screen.dart`

Backend:

- `backend/src/app.js`
- `backend/src/models/message.model.js`
- `backend/src/models/trip.model.js`
- `backend/src/models/tripChannel.model.js`
- `backend/src/models/chatRoom.model.js`
- `backend/src/modules/messages/message.service.js`
- `backend/src/modules/messages/message.validation.js`
- `backend/src/socket/chat.socket.js`
- `backend/src/modules/tripContext/tripContext.routes.js`
- `backend/src/modules/tripContext/tripContext.controller.js`
- `backend/src/modules/tripContext/tripContext.service.js`
- `backend/src/modules/tripContext/tripContext.validation.js`
- `backend/scripts/phase14g-trip-context-smoke.js`
- `backend/package.json`

Tests:

- `test/phase14g_trip_channel_chat_context_test.dart`
- `test/phase14b_active_channel_resolution_test.dart`
- `test/chat_media_messaging_test.dart`
- `test/live_radio_experimental_test.dart`

## Schema Changes

Local SQLite was bumped from version 19 to version 20.

Added to `trip_sessions`:

- `active_channel_id`
- `last_opened_at`

Added to `offline_channels`:

- `trip_id`
- `is_primary`

Created:

- `chat_rooms`

Added nullable `chat_id`:

- `offline_messages`
- `offline_packet_queue`
- `processed_offline_packets`
- `offline_acks`
- `local_messages`
- `message_queue`

Also added nullable `trip_id` and `channel_id` to cloud message storage/queue tables so cloud messages can preserve trip context.

## Active-State Rules Implemented

- Activating a trip marks other active trips `inactive`, not `archived`.
- Activating a trip ensures a primary channel and default `General` chat.
- Switching active channel updates the active trip mirror fields and activates the channel default chat.
- Archiving/completing a trip clears active channel/chat flags for that trip.
- Orphan active offline channels can be repaired into a trip context when a local identity exists.

## Backend Sync

Added authenticated endpoints:

- `POST /api/trip-context/sync`
- `GET /api/trip-context/sync?updatedSince=...`

Server behavior:

- upserts trips by `{ ownerId, tripId }`
- upserts channels by `{ ownerId, channelId }`
- upserts chat rooms by `{ ownerId, chatId }`
- enforces one active trip per user when an incoming trip is active
- enforces one active channel/chat inside the incoming active context
- stores optional `tripId`, `channelId`, and `chatId` on messages

## UI Notes

Added a minimal Trip Management screen at `/trips`:

- lists trips
- shows active status
- activates trips
- archives trips
- lists trip channels
- creates additional channels
- activates a channel

The dashboard now exposes a `Manage Trips` action. No chat composer layout or P2P transport behavior was redesigned in this phase.

## Test Results

Passed:

- `flutter analyze`
- `flutter test test\phase14g_trip_channel_chat_context_test.dart`
- `flutter test test\phase14b_active_channel_resolution_test.dart`
- `flutter test`
- `flutter build apk --debug`
- backend Node syntax checks for new Phase 14G files
- backend smoke via `node backend/scripts/phase14g-trip-context-smoke.js` against `http://127.0.0.1:5010/api`

Backend smoke result:

- registered a user
- created a cloud group
- synced trip/channel/chat metadata
- re-synced same IDs and verified idempotency
- synced an active trip switch and verified the first trip became inactive
- synced a message with `tripId`, `channelId`, and `chatId`
- fetched history and verified message metadata was preserved

## Device Verification

Samsung device:

- serial: `R58R85Q2HWH`
- APK install: passed
- launch: passed
- package/activity: `com.example.traillink/.MainActivity`

Captured evidence:

- `docs/qa/phase14g_trip_context_device.png`
- `docs/qa/phase14g_window.xml`

Manual navigation into trip flows was blocked because the installed app opened at the TrailLink app-lock screen and requires user PIN/biometric unlock. No trip-management functional pass is claimed from device QA until the app is unlocked.

## Remaining Risks

- The Flutter test added for Phase 14G is primarily a source/model contract test, not a full transactional SQLite integration test.
- Device UI flow validation for creating two trips and switching active trip still needs an unlocked app session.
- The backend sync endpoint stores per-user metadata and enforces active flags, but conflict resolution is still last-write-wins by request order.
- Multiple chat rooms per channel are schema-ready but intentionally not exposed in UI.
