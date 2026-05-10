# Active Offline Channel Resolution Report

Date: 2026-05-09

## Problem

The app had multiple active offline channel sources:

- Home dashboard could read the active trip directly from `trip_sessions`.
- Offline Channels, Nearby Peers, Connectivity Guidance, PTT, and Offline Chat depended on active channel queries/settings that could be stale.

This caused an active Offline Only trip to appear on Home while downstream offline tools claimed no channel existed.

## Central Resolver

New resolver:

`lib/features/offline_channel/data/active_offline_channel_resolver.dart`

Public methods:

- `getActiveOfflineChannel()`
- `getActiveOfflineChannelForActiveTrip()`
- `getActiveUsableOfflineChannel()`
- `hasActiveUsableOfflineChannel()`
- `setActiveChannel(String channelId)`
- `repairActiveChannelFromActiveTripIfNeeded()`
- `repairAndListChannels()`
- `diagnostics()`

## Database Fields Used

### `offline_channels`

- `channel_id`
- `channel_code`
- `channel_name`
- `channel_status`
- `is_active`
- `created_by_user_id`
- `created_by_name`

### `trip_sessions`

- `id`
- `trip_name`
- `mode`
- `status`
- `offline_channel_id`
- `channel_code`

### `offline_channel_members`

- `channel_id`
- `member_local_id`
- `membership_status`

### settings

- `active_offline_channel_id`

The settings key remains supported for compatibility, but it is no longer the only source of truth.

## Resolution Order

1. Query `offline_channels` for `is_active = 1` and `channel_status = active`.
2. If none exists, inspect the active trip where `trip_sessions.status = active` and `mode` is `offline` or `hybrid`.
3. Match the trip to `offline_channels` by `offline_channel_id`.
4. If not found, match by `channel_code`.
5. If a channel row exists but is not marked active, clear other active flags and mark it active.
6. If the trip has a channel code but no local channel row, create a local repaired channel row.
7. Ensure the local owner/member row exists when possible.
8. Do not return ended channels from `getActiveUsableOfflineChannel()`.

## Repair Rules

Repair is intentionally conservative:

- No database reset.
- No row deletion.
- No schema migration.
- No destructive update to messages, members, packets, or trip sessions.
- No duplicate channel creation when channel id or channel code already exists.
- Only one local offline channel is marked active at a time.

## Provider Integration

Provider updates live in:

`lib/features/offline_channel/presentation/offline_channel_controller.dart`

Added or updated providers:

- `activeOfflineChannelResolverProvider`
- `activeOfflineChannelProvider`
- `activeUsableOfflineChannelProvider`
- `activeTripChannelProvider`
- `offlineChannelListProvider`
- `rawOfflineChannelListProvider`

`offlineChannelListProvider` repairs from active trip before listing, so trip-created channels appear immediately in the Offline Channels screen.

## Screens Using Resolver-Backed State

- Home dashboard PTT routing
- Offline Channels list
- Nearby Peers
- Connectivity Guidance
- Connectivity controller
- Messages Hub offline shortcuts
- Offline Chat
- Mode Bottom Sheet

## Debug Diagnostics

Route:

`/debug/active-channel`

The route is guarded by `EnvConfig.appEnv != 'production'`. It shows:

- active trip id/name/mode/status
- trip `offline_channel_id`
- trip `channel_code`
- active offline channel id/code/status/is_active
- local identity id
- member count
- resolver result
- null reason when no usable channel is found

## Expected Behavior After Fix

Given an active Offline Only trip with channel `TL-OFF-BL4C`:

- Home shows the trip/channel.
- Offline Channels lists the channel.
- Nearby Peers shows `TL-OFF-BL4C` and discovery controls.
- Connectivity Guidance shows channel-aware no-peer guidance.
- PTT opens `/offline-channel/:channelId/ptt`.
- Offline Chat shows the composer even when no peers are connected.

