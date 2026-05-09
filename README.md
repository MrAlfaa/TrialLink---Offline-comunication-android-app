# TrailLink

TrailLink is a hybrid outdoor communication and safety app for hikers, campers, and outdoor groups. Phase 01 builds the foundation only: Flutter mobile app structure, Node.js backend structure, MongoDB Atlas connectivity checks, SQLite local storage readiness, environment configuration, polished navigation, and system health screens.

This phase does not implement authentication, chat, BLE, Wi-Fi Direct, offline mesh, SOS, map, or voice features.

## Tech Stack

Frontend:

- Flutter and Dart
- Riverpod for state management
- go_router for navigation
- Dio for backend API calls
- sqflite for local SQLite storage
- flutter_dotenv for environment configuration
- Flutter-native animations

Backend:

- Node.js
- Express.js
- MongoDB Atlas with Mongoose
- dotenv, cors, helmet, morgan
- nodemon for development

## Folder Structure

```text
TrailLink-Android Flutter App/
  lib/
    main.dart
    app/
    core/
    features/
    shared/
  backend/
    src/
      app.js
      server.js
      config/
      routes/
      controllers/
      models/
      middleware/
      utils/
    .env.example
    package.json
    README.md
  .env.example
  pubspec.yaml
```

## Environment Setup

Flutter app:

```env
API_BASE_URL=http://10.0.2.2:5000/api
APP_ENV=development
```

Android emulator uses `10.0.2.2` to reach the host machine. For a physical Android phone, replace `API_BASE_URL` with your computer's LAN IP address, for example:

```env
API_BASE_URL=http://192.168.1.20:5000/api
APP_ENV=development
```

Backend:

```env
PORT=5000
NODE_ENV=development
MONGO_URI=your_mongodb_atlas_connection_string
```

## Backend Setup

```powershell
cd backend
cmd /c npm install
Copy-Item .env.example .env
cmd /c npm run dev
```

Health endpoints:

- `GET http://localhost:5000/`
- `GET http://localhost:5000/api/health`
- `GET http://localhost:5000/api/health/db`

`/api/health/db` returns a failed status until `MONGO_URI` is set to a valid MongoDB Atlas connection string.

## MongoDB Atlas Setup

1. Create a MongoDB Atlas project and cluster.
2. Create a database user with a secure password.
3. Add your current IP address to Network Access.
4. Copy the connection string.
5. Put the connection string in `backend/.env` as `MONGO_URI`.
6. Restart the backend and test `GET /api/health/db`.

## Flutter Setup

If this folder does not yet contain generated Android platform files, run this once after installing Flutter:

```bash
flutter create . --platforms=android
```

Then run:

```bash
flutter pub get
flutter analyze
flutter run
```

The app loads `.env`, initializes SQLite, creates a local anonymous session, and starts with the TrailLink splash screen.

## Run on Physical Android Phone using Git Bash

Use this section when your Android phone is connected to the laptop with USB debugging enabled. The current test device is:

```text
SM A127F (mobile) • R58R85Q2HWH • android-arm64 • Android 13
```

Open **Git Bash** in the project root, or run:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
```

If the `android/` folder does not exist yet, generate the Android platform files:

```bash
flutter create . --platforms=android
```

Install Flutter dependencies and confirm that the phone is detected:

```bash
flutter pub get
flutter devices
```

You should see a device like:

```text
SM A127F (mobile) • R58R85Q2HWH • android-arm64 • Android 13
```

### 1. Start the backend in a second Git Bash terminal

Open another Git Bash terminal and run:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm install
cp .env.example .env
npm run dev
```

The backend should run on:

```text
http://localhost:5000
```

Keep this backend terminal open while running the Flutter app.

### 2. Configure the Flutter API URL for a physical phone

For an Android emulator, `.env` can use:

```env
API_BASE_URL=http://10.0.2.2:5000/api
APP_ENV=development
```

For a real Android phone, `10.0.2.2` will not work. The phone must call your laptop using the laptop's LAN IPv4 address.

Find your laptop IP address from Git Bash:

```bash
ipconfig.exe
```

Look for the Wi-Fi adapter's `IPv4 Address`, then update the Flutter `.env` file in the project root:

```env
API_BASE_URL=http://YOUR_LAPTOP_IP:5000/api
APP_ENV=development
```

Example:

```env
API_BASE_URL=http://192.168.1.20:5000/api
APP_ENV=development
```

Before running the app, test the backend from the Android phone browser:

```text
http://YOUR_LAPTOP_IP:5000/api/health
```

If the page does not load, make sure the phone and laptop are on the same Wi-Fi network and allow port `5000` through Windows Firewall.

### 3. Run the app on the connected phone

Return to the project root Git Bash terminal:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
flutter run -d R58R85Q2HWH
```

After the app opens, go to **System Status** and test:

- Backend Connection
- MongoDB Connection
- Local SQLite
- Environment Config
- Local Session

MongoDB can show failed until you add a real MongoDB Atlas connection string to `backend/.env`.

### Optional USB-only backend route

If the LAN IP method is difficult, use Android Debug Bridge port reverse while the phone is connected by USB:

```bash
adb reverse tcp:5000 tcp:5000
```

If two phones are connected, always include the device id:

```bash
adb -s HAF6ZXGI5TINKJCA reverse tcp:5000 tcp:5000
adb -s R58R85Q2HWH reverse tcp:5000 tcp:5000
```

Then set the Flutter `.env` file to:

```env
API_BASE_URL=http://127.0.0.1:5000/api
APP_ENV=development
```

Now run:

```bash
flutter run -d R58R85Q2HWH
```

This USB-only route works only while the phone is connected and `adb reverse` is active.

## Phase 01 Completed Features

- Splash screen with fade animation
- Onboarding screen with animated concept cards
- Home dashboard with system foundation status cards
- System Status screen with manual health checks
- Backend API health endpoint
- MongoDB Atlas health endpoint
- Local SQLite setup with starter tables:
  - `local_messages`
  - `sync_queue`
  - `peer_nodes`
  - `app_settings`
  - `app_sessions`
- Local anonymous session stored in SQLite
- Placeholder screens for Chat, Offline Channel, SOS, Map, Connectivity, and Settings
- Outdoor safety color theme and responsive UI base

## Phase 02 Authentication and Group Management

Phase 02 adds account authentication and hiking/camping group management. It does not add chat, BLE, offline mesh, SOS, maps, voice, location sharing, or connectivity intelligence.

### Backend Environment

Add JWT settings to `backend/.env`:

```env
JWT_SECRET=replace_with_a_long_secure_random_secret
JWT_EXPIRES_IN=7d
```

The backend still requires:

```env
PORT=5000
NODE_ENV=development
MONGO_URI=your_mongodb_atlas_connection_string
```

### Auth API Routes

Register:

```http
POST /api/auth/register
Content-Type: application/json
```

```json
{
  "fullName": "Dhananjaya Kumara",
  "email": "test@example.com",
  "password": "Password@123",
  "phoneNumber": "0771234567"
}
```

Login:

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "email": "test@example.com",
  "password": "Password@123"
}
```

Current user:

```http
GET /api/auth/me
Authorization: Bearer <jwt_token>
```

Successful auth responses return:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "...",
      "fullName": "...",
      "email": "..."
    },
    "token": "jwt_token"
  }
}
```

### Group API Routes

All group routes require:

```http
Authorization: Bearer <jwt_token>
```

Create group:

```http
POST /api/groups
```

```json
{
  "groupName": "Knuckles Hiking Team",
  "description": "Weekend camping group"
}
```

Join group:

```http
POST /api/groups/join
```

```json
{
  "groupCode": "TL-8F3K2"
}
```

Other group routes:

- `GET /api/groups/my`
- `GET /api/groups/:groupId`
- `GET /api/groups/:groupId/members`

### Flutter Auth Flow

- JWT is stored using `flutter_secure_storage`.
- Minimal user/group summaries are cached in SQLite.
- Splash checks onboarding first, then restores the secure auth session using `/api/auth/me`.
- Invalid or expired tokens are cleared and the user is sent to login.
- Logout clears the secure token and local user/group cache.

### Run Phase 02 on Android Phone using Git Bash

Keep backend running in one Git Bash terminal:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm install
npm run dev
```

For USB-connected phone testing, keep the root `.env` as:

```env
API_BASE_URL=http://127.0.0.1:5000/api
APP_ENV=development
```

Then run in another Git Bash terminal:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
adb reverse tcp:5000 tcp:5000
flutter pub get
flutter run -d R58R85Q2HWH
```

### Phase 02 Manual Test Checklist

1. Register a new user.
2. Logout and login again.
3. Restart the app and confirm auto-login.
4. Create a hiking/camping group.
5. Copy the generated group code.
6. Join a group using a valid group code.
7. View joined groups.
8. Open group details.
9. View group members.
10. Open System Status and confirm Phase 01 checks still work.

## Phase 03 Online Group Chat

Phase 03 adds authenticated real-time group chat for existing TrailLink groups. Chat uses Socket.IO for live delivery and MongoDB Atlas for server history.

### Backend Chat Routes

All routes require:

```http
Authorization: Bearer <jwt_token>
```

Fetch chat history:

```http
GET /api/groups/:groupId/messages?page=1&limit=30
```

Sync pending local messages:

```http
POST /api/groups/:groupId/messages/sync
```

```json
{
  "messages": [
    {
      "clientMessageId": "uuid-from-flutter",
      "content": "Pending message text",
      "messageType": "text",
      "createdAt": "2026-05-02T10:30:00.000Z"
    }
  ]
}
```

### Socket.IO Events

Flutter connects to the backend socket root, not the `/api` path. If `API_BASE_URL` is:

```env
API_BASE_URL=http://127.0.0.1:5000/api
```

the socket URL is:

```text
http://127.0.0.1:5000
```

Socket auth uses:

```js
auth: { token: "jwt_token" }
```

Events:

- Client sends `join_group` with `{ "groupId": "..." }`
- Server sends `group_joined`
- Client sends `send_group_message`
- Server sends `message_sent_ack`
- Server broadcasts `new_group_message`
- Server sends `socket_error` for auth, membership, validation, or server errors

### MongoDB Message Schema

Messages are stored with:

- `clientMessageId`
- `groupId`
- `senderId`
- `messageType`
- `content`
- `status`
- `createdAt`
- `updatedAt`

The backend uses a unique compound index on `{ clientMessageId, senderId }`. This prevents duplicate MongoDB messages when the mobile app retries offline queued messages.

## Phase 04 SQLite Offline Foundation

Phase 04 makes chat local-first. Every outgoing chat message is saved to SQLite before the app attempts socket delivery.

SQLite tables:

- `local_messages`
- `message_queue`
- `sync_queue`

Delivery statuses:

- `pending`: saved locally but not sent yet
- `sending`: socket send is in progress
- `sent`: backend accepted the message
- `failed`: send failed but the message remains local
- `synced`: backend and local state are reconciled

Offline behavior:

1. User sends a message.
2. Flutter generates `clientMessageId`.
3. Message is saved to `local_messages`.
4. Queue records are saved to `message_queue` and `sync_queue`.
5. If socket/internet is unavailable, the message stays visible as pending.
6. When connectivity returns, the app calls `/api/groups/:groupId/messages/sync`.
7. The backend deduplicates by `clientMessageId + senderId`.
8. Local status changes to `sent` or `synced`.

### Phase 03/04 Git Bash Test Flow

Start backend:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm install
npm run dev
```

Run backend chat smoke test in another Git Bash terminal:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm run test:phase03
```

Run Flutter on the connected Android phone:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
adb reverse tcp:5000 tcp:5000
flutter pub get
flutter run -d R58R85Q2HWH
```

Manual test:

1. Login.
2. Open **Groups**.
3. Open a group.
4. Tap **Open Group Chat**.
5. Send a message online.
6. Confirm the message appears immediately and status changes from pending/sending to sent/synced.
7. Turn off phone internet and send another message.
8. Restart the app and confirm the pending message still appears.
9. Turn internet back on and confirm the message syncs without duplication.

### Troubleshooting

- Android emulator backend URL: `http://10.0.2.2:5000/api`
- Physical phone over Wi-Fi: `http://YOUR_LAPTOP_IP:5000/api`
- Physical phone over USB reverse: `http://127.0.0.1:5000/api` plus `adb reverse tcp:5000 tcp:5000`. With two phones connected, use `adb -s <deviceId> reverse tcp:5000 tcp:5000` for each phone.
- Socket URL is derived automatically from `API_BASE_URL` by removing `/api`.
- If duplicate local rows appear during development, clear app storage from Android settings or uninstall/reinstall the debug app.
- If MongoDB rejects a duplicate `clientMessageId`, the backend returns the existing message instead of creating a second copy.

## Phase 05 Auto Online/Offline Mode Switching

Phase 05 adds a global app mode that decides whether TrailLink should use backend communication or local-first queueing.

Mode detection uses two checks:

- Network interface availability from `connectivity_plus`
- Backend reachability using `GET /api/health/ping` or `GET /api/health`

Mode states:

- `online`: network exists and backend health checks are stable
- `offline`: no network interface or backend is unavailable
- `reconnecting`: network exists and the app is checking the backend
- `unstable`: backend checks alternate between success and failure

Sending path:

- `online` -> save message to SQLite first, then send through Socket.IO/backend
- `offline`, `reconnecting`, or `unstable` -> save message to SQLite and queue only

When mode changes back to `online`, TrailLink automatically retries pending message sync.

Manual test:

1. Start backend and open the app.
2. Confirm Dashboard and Chat show `Online`.
3. Stop backend while phone network stays on.
4. Confirm the app changes to `Reconnecting`, `Offline`, or `Unstable`.
5. Send a chat message and confirm it stays pending.
6. Restart backend.
7. Confirm the app returns to `Online` and pending messages sync.

## Phase 06 Offline Channel System

Phase 06 adds local-only Offline Channels. An Offline Channel Code is a software-based group code used to identify which nearby users should communicate together in a future offline mode. It is not a real radio frequency.

Offline channel examples:

```text
TL-OFF-8K2P
HIKER-25
CAMP-92KD
```

SQLite tables:

- `offline_channels`
- `offline_channel_members`
- `offline_channel_packets`

Current behavior:

- Create a local offline channel
- Join a local offline channel by channel code
- Save channels and members locally in SQLite
- Set one active offline channel
- Show local channel details and current user as a local member
- Run a packet filter test for future peer discovery

Packet filter rules:

- Process packet if `channelId` matches the active channel
- Or process packet if `channelCode` matches the active channel code
- Ignore expired packets with `ttl <= 0`
- Ignore packets above max hop count
- Ignore duplicate packet IDs

Phase 06 does not implement BLE, Wi-Fi Direct, real peer discovery, real mesh relay, SOS, map, voice, or offline message transfer.

Manual test:

1. Open **Offline Channel** from the bottom navigation.
2. Create a channel with a generated code.
3. Create another channel with a valid custom code.
4. Try invalid codes with spaces or symbols and confirm validation.
5. Join a new channel code.
6. Set a channel active.
7. Open channel details.
8. Copy the channel code.
9. Confirm the current user appears as a local member.
10. Run **Packet Filter Test** and confirm same-channel packets process while different, expired, and duplicate packets are ignored.

## Phase 07 Nearby Peer Discovery

Phase 07 adds Android offline peer discovery using Google Nearby Connections through the Flutter `nearby_connections` package. Nearby Connections is the primary offline transport because it uses Bluetooth, BLE, and Wi-Fi technologies underneath depending on device support.

Important requirements:

- Use two real Android phones for reliable testing.
- Bluetooth, Wi-Fi, and Location should be enabled on both phones.
- Both phones must use the same active Offline Channel Code.
- The app filters discovered peers by TrailLink app id, protocol version, and active channel code.
- Offline packets never include JWT tokens, passwords, backend secrets, or MongoDB credentials.

Android permissions added:

- `BLUETOOTH_SCAN`
- `BLUETOOTH_ADVERTISE`
- `BLUETOOTH_CONNECT`
- `BLUETOOTH`
- `BLUETOOTH_ADMIN`
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `NEARBY_WIFI_DEVICES`
- Wi-Fi state permissions required by Nearby Connections

SQLite tables:

- `nearby_peers`
- `peer_connection_events`

Peer statuses:

- `discovered`
- `connecting`
- `connected`
- `disconnected`
- `lost`
- `failed`

Nearby workflow:

1. Create or join an Offline Channel.
2. Set that channel active.
3. Open **Nearby Peers**.
4. Grant nearby, Bluetooth, and Location permissions.
5. Start Advertising.
6. Start Discovery.
7. Connect to a same-channel peer.

## Phase 08 Offline Channel Text Chat

Phase 08 adds local-only offline channel text messaging over connected Nearby peers. It does not use the backend, Socket.IO, MongoDB, or internet.

SQLite tables:

- `offline_messages`
- `offline_packet_queue`
- `processed_offline_packets`
- `offline_acks`

Offline packet behavior:

- `packetId` is the duplicate-prevention key.
- `messageId` identifies the text message.
- `channelCode` must match the active Offline Channel Code.
- `ttl <= 0` packets are ignored.
- `hopCount > 5` packets are ignored.
- Duplicate packet IDs are ignored.
- Text packets are saved locally, displayed, ACKed, and relayed.
- ACK packets update the sender message to `delivered`.
- If no peer is connected, outgoing messages stay queued.

Delivery statuses:

- `pending`: saved locally, waiting for a connected peer
- `sent`: packet sent to at least one nearby peer
- `delivered`: ACK received from a nearby peer
- `failed`: send failed
- `received`: incoming message saved locally

### Run on Two Android Phones using Git Bash

Confirm both phones are connected:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
adb devices
```

Current tested device ids:

```text
HAF6ZXGI5TINKJCA
R58R85Q2HWH
```

If `.env` uses USB reverse mode:

```env
API_BASE_URL=http://127.0.0.1:5000/api
APP_ENV=development
```

configure reverse separately for both phones:

```bash
adb -s HAF6ZXGI5TINKJCA reverse --remove-all
adb -s R58R85Q2HWH reverse --remove-all
adb -s HAF6ZXGI5TINKJCA reverse tcp:5000 tcp:5000
adb -s R58R85Q2HWH reverse tcp:5000 tcp:5000
adb -s HAF6ZXGI5TINKJCA reverse --list
adb -s R58R85Q2HWH reverse --list
```

Both `reverse --list` commands should show:

```text
UsbFfs tcp:5000 tcp:5000
```

Install/run on Phone A:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
flutter run -d HAF6ZXGI5TINKJCA
```

Install/run on Phone B from a second Git Bash terminal:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
flutter run -d R58R85Q2HWH
```

If you only want to install the latest debug APK after building:

```bash
flutter build apk --debug
adb -s HAF6ZXGI5TINKJCA install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s R58R85Q2HWH install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Two-Phone Offline Test

1. Enable Bluetooth, Wi-Fi, and Location on both phones.
2. Open TrailLink on both phones.
3. Login on both phones.
4. On Phone A, create an Offline Channel and copy its Channel Code.
5. On Phone B, join the same Channel Code.
6. Set the same channel active on both phones.
7. Open **Nearby Peers** on both phones.
8. Grant all nearby permissions.
9. Tap **Start Advertising** on both phones.
10. Tap **Start Discovery** on both phones.
11. Confirm each phone shows the other as a peer.
12. Tap **Connect** from one phone.
13. Open the Offline Channel details on both phones.
14. Tap **Open Offline Chat**.
15. Send a message from Phone A.
16. Confirm Phone B receives the message.
17. Confirm Phone A status changes to `delivered` after ACK.
18. Turn off internet and repeat. Nearby offline chat should still work.
19. Disconnect peers, send a message, reconnect, and confirm the queued packet sends.

Useful QA commands:

```bash
adb devices
adb -s HAF6ZXGI5TINKJCA logcat -c
adb -s R58R85Q2HWH logcat -c
adb -s HAF6ZXGI5TINKJCA exec-out screencap -p > build/phone-a-nearby.png
adb -s R58R85Q2HWH exec-out screencap -p > build/phone-b-nearby.png
adb -s HAF6ZXGI5TINKJCA logcat -d > build/phone-a-logcat.txt
adb -s R58R85Q2HWH logcat -d > build/phone-b-logcat.txt
```

Troubleshooting:

- Use real Android phones, not emulators, for Nearby Connections.
- Keep both phones close to each other.
- Ensure both phones use the same active Channel Code.
- Ensure Location service is turned on.
- Restart Advertising and Discovery if peers are not visible.
- If logcat shows `Bluetooth permission missing in manifest` on Android 12/13, the app is requesting the wrong legacy Bluetooth runtime permission; rebuild with the SDK-specific Nearby permission fix and reinstall.
- If builds show Kotlin cache errors on Windows with project and pub cache on different drives, keep `kotlin.incremental=false` in `android/gradle.properties`.

## Phase 09 Emergency SOS

Phase 09 adds emergency SOS for both online groups and offline channels.

Backend routes:

- `POST /api/groups/:groupId/emergency`
- `GET /api/groups/:groupId/emergency`
- `POST /api/groups/:groupId/emergency/:eventId/ack`
- `POST /api/groups/:groupId/emergency/:eventId/resolve`

Socket events:

- `emergency_alert`
- `emergency_ack`
- `emergency_resolved`
- Client event: `ack_emergency`

SQLite tables:

- `emergency_events`
- `emergency_packet_queue`
- `emergency_acks`

SOS behavior:

- SOS is confirmed before sending to reduce accidental alerts.
- Every SOS is saved locally first.
- Online SOS is posted to the backend and broadcast through Socket.IO.
- Offline SOS is sent as a high-priority Nearby packet on the active Offline Channel.
- SOS packets use priority `emergency`, TTL, hop count, duplicate prevention, and ACK handling.
- Offline packets never include JWT tokens, passwords, backend secrets, or MongoDB credentials.
- Offline SOS receivers now see a full-screen emergency alert while the app is open.
- The receiver can acknowledge, track the SOS location on the map, or dismiss the alert locally.

Important Phase 08 regression fix:

- Offline packet handling is now app-wide while TrailLink is open.
- Text ACKs, SOS ACKs, and location packets are processed even when the Offline Chat screen is not open.
- This prevents normal offline chat messages from staying at `ack timeout` only because the receiver was on another screen.

Backend smoke test:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm run test:phase09
```

Manual online SOS test:

1. Start backend.
2. Login as User A and User B.
3. Put both users in the same group.
4. Open the group SOS screen.
5. User A sends SOS.
6. User B receives `emergency_alert`.
7. User B acknowledges.
8. User A sees the alert acknowledged.
9. Confirm MongoDB stores the emergency event.

Manual offline SOS test:

1. Phone A and Phone B join the same Offline Channel Code.
2. Set the channel active on both phones.
3. Start Nearby advertising and discovery on both phones.
4. Connect the peers.
5. Turn off internet.
6. Phone A opens SOS and sends an alert.
7. Phone B receives a full-screen emergency alert.
8. Phone B taps **Acknowledge**.
9. Phone A updates the alert to acknowledged.
10. Phone B taps **Track on Map** and confirms the map opens on the SOS coordinates.
11. Phone B can tap **Dismiss Locally** to hide the alert while keeping it in emergency history.

## Phase 10 Location And Map

Phase 10 adds GPS capture, local location caching, online/offline location sharing, and a map view.

The map uses Google Maps on Android through `google_maps_flutter`. The Android API key is read from `android/local.properties` using:

```properties
google.maps.api.key=YOUR_GOOGLE_MAPS_ANDROID_KEY
```

For safety, restrict the key in Google Cloud Console:

- API restriction: Maps SDK for Android
- Android app package: `com.example.traillink`
- Add debug and release SHA-1 fingerprints

Backend routes:

- `POST /api/groups/:groupId/locations`
- `POST /api/groups/:groupId/locations/sync`
- `GET /api/groups/:groupId/locations/latest`

Socket event:

- `location_update`

Flutter packages:

- `geolocator`
- `google_maps_flutter`

SQLite tables:

- `location_updates`
- `teammate_locations`
- `location_packet_queue`

Freshness labels:

- `fresh`: location age is 5 minutes or less
- `old`: location age is more than 5 minutes and up to 30 minutes
- `stale`: location age is more than 30 minutes

Offline map limitation:

- TrailLink does not pre-download offline map tiles in this phase.
- Google map tiles display when internet or previous Google Maps cache is available.
- Offline mode still shows saved coordinates, current user location, teammate location cards, and last-known markers.
- Future enhancement: pre-download offline map tiles for a selected hiking area.

Backend smoke test:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm run test:phase10
```

Manual online location test:

1. Grant Location permission.
2. Open a group map.
3. Tap **Share**.
4. Confirm location is saved locally.
5. Confirm backend stores the location.
6. Confirm another group member sees a teammate marker.

Manual offline location test:

1. Phone A and Phone B use the same active Offline Channel.
2. Connect both phones through Nearby Peers.
3. Turn off internet.
4. Phone A opens the offline channel map and taps **Share**.
5. Phone B receives the location packet.
6. Phone B map/list shows Phone A location as `fresh`.

## Phase 11 Connectivity Intelligence

Phase 11 adds peer quality scoring and movement guidance for offline channels.

Important RSSI note:

- RSSI is optional and may be `null` because Flutter Nearby Connections packages do not always expose it.
- When RSSI is unavailable, TrailLink uses ACK delay, packet success rate, retry count, disconnect count, last-seen freshness, and connection status as proxy metrics.
- The app shows connection quality, not precise distance.

SQLite tables:

- `peer_metric_samples`
- `peer_quality_scores`
- `connectivity_guidance_logs`

Quality labels:

- `excellent`: 80-100
- `good`: 60-79
- `fair`: 40-59
- `weak`: 20-39
- `lost`: 0-19

Connectivity screen:

- Open **Connect** from the bottom navigation.
- The screen shows active channel status, network health, queued packet count, ranked peers, ACK delay, trend direction, and movement guidance.

Manual Phase 11 test:

1. Phone A and Phone B join the same active offline channel.
2. Start Nearby advertising/discovery and connect peers.
3. Send offline text messages or SOS ACKs.
4. Open **Connect**.
5. Confirm peer quality score and label are shown.
6. Move phones farther/closer or disconnect a peer.
7. Confirm guidance changes toward `weak` or `lost` when connection quality degrades.

## Phase 12 Voice-Note Push-To-Talk

Phase 12 adds walkie-talkie style voice-note communication. This is not live streaming:

- press and hold to record
- release to send
- receivers play the recorded clip

Flutter packages:

- `record`
- `just_audio`

Android permission:

- `RECORD_AUDIO`

Backend routes:

- `POST /api/groups/:groupId/voice-notes`
- `GET /api/groups/:groupId/voice-notes`

Socket events:

- `ptt_request`
- `ptt_granted`
- `ptt_denied`
- `ptt_speaker_changed`
- `ptt_release`
- `ptt_speaker_released`
- `voice_note_received`

SQLite tables:

- `voice_notes`
- `ptt_floor_events`
- `voice_packet_queue`

Limits:

- online group voice note: 30 seconds
- offline Nearby voice note: 15 seconds
- offline encoded packet size: 250 KB

Backend smoke test:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm run test:phase12
```

Manual online PTT test:

1. Phone A and Phone B login as different users.
2. Both users join the same group.
3. Open **Walkie-Talkie / PTT** from Group Details.
4. User A holds the PTT button.
5. User B sees User A speaking and cannot record.
6. User A releases.
7. Voice note uploads.
8. User B receives and plays the voice note.
9. User B can talk after User A releases.

Manual offline PTT test:

1. Phone A and Phone B join the same active offline channel.
2. Start Nearby advertising/discovery and connect peers.
3. Turn off internet.
4. Open **Offline Walkie-Talkie** from Offline Channel Details.
5. User A holds the PTT button.
6. User B sees User A speaking.
7. User A releases.
8. Voice note sends through Nearby.
9. User B receives and plays the voice note.
10. User B sends ACK automatically.
11. User A status becomes delivered.

## Phase 11/12 Verification Commands

Static and build checks:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Backend checks:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App/backend"
npm install
npm run test:phase02
npm run test:phase03
npm run test:phase09
npm run test:phase10
npm run test:phase12
```

Two-phone run reminder:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
adb -s HAF6ZXGI5TINKJCA reverse tcp:5000 tcp:5000
adb -s R58R85Q2HWH reverse tcp:5000 tcp:5000
flutter run -d HAF6ZXGI5TINKJCA
```

Use a second Git Bash terminal for Phone B:

```bash
cd "/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App"
flutter run -d R58R85Q2HWH
```

## Next Phase Plan

Future phases can add encryption, richer mesh relay diagnostics, notification-based emergency alerts, privacy controls, cloud voice storage, or offline map tile downloads. True live voice streaming remains outside Phase 12.
