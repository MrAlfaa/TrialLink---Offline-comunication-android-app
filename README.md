# TrailLink

TrailLink is a hybrid outdoor communication and safety app for hiking, camping, and field teams. It supports two clear trip types:

- **Online Trip**: internet-based team chat and group management through the TrailLink backend.
- **Offline Trip**: nearby phone-to-phone communication for local chat, SOS, location sharing, voice notes, and Live Radio.

The app keeps one selected online trip and one selected offline trip so users can switch modes without mixing online groups and offline channels.

## Tech Stack

Mobile app:

- Flutter and Dart
- Riverpod state management
- GoRouter navigation
- SQLite local storage through `sqflite`
- Dio REST API client
- Socket.IO client for online chat
- Nearby Connections for offline phone-to-phone communication
- Local Android notifications
- Location, map, voice recording, playback, and app lock support

Backend:

- Node.js and Express
- MongoDB with Mongoose
- Socket.IO
- JWT authentication
- REST APIs for users, groups, chat, SOS, location, trip context, and network probe

## Project Structure

```text
TrailLink-Android Flutter App/
  lib/                     Flutter app source
  assets/branding/          App branding assets
  android/                  Android project
  backend/                  Node.js API and Socket.IO backend
  docs/                     Product, QA, and system documents
  test/                     Flutter regression tests
  .env.example              Flutter environment template
  pubspec.yaml              Flutter package config
```

## Prerequisites

Install these before running the project:

- Flutter SDK
- Android Studio or Android SDK command-line tools
- Java/JDK supported by your Android Gradle setup
- Node.js LTS
- Git
- MongoDB Atlas connection string or a reachable MongoDB instance
- Android phone with USB debugging, or an Android Studio emulator

Check Flutter:

```bash
flutter doctor
flutter devices
```

## Clone And Install

```bash
git clone <github-repository-url>
cd "TrailLink-Android Flutter App"
flutter pub get
```

Install backend dependencies:

```bash
cd backend
npm install
cd ..
```

## Environment Files

Create Flutter `.env` in the project root:

```env
API_BASE_URL=http://10.0.2.2:5001/api
APP_ENV=development
```

Create backend `.env` in `backend/`:

```env
PORT=5001
NODE_ENV=development
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=replace_with_a_secure_secret
JWT_EXPIRES_IN=7d
```

Do not commit real `.env` files.

## Git Bash Runbook

Most local development can be run from Git Bash on Windows. Use two terminals:

- **Terminal 1** keeps the backend running.
- **Terminal 2** builds, installs, and launches the Flutter app.

### 1. Start The Backend

From the repository root:

```bash
cd backend
npm install
npm run dev
```

Keep this terminal open. The backend runs on:

```text
http://127.0.0.1:5001/api
```

Health check from another Git Bash terminal:

```bash
curl http://127.0.0.1:5001/api/health
```

The backend must stay running when testing Online Trip features.

### 2. Run On Android Emulator

Use this Flutter `.env`:

```env
API_BASE_URL=http://10.0.2.2:5001/api
APP_ENV=development
```

Then run:

```bash
flutter pub get
flutter run -d <emulator_id>
```

Example:

```bash
flutter devices
flutter run -d emulator-5554
```

### 3. Run On Physical Android Phones With USB Reverse

This is the recommended setup for local backend testing on real phones.

Use this Flutter `.env`:

```env
API_BASE_URL=http://127.0.0.1:5000/api
APP_ENV=development
```

Confirm connected devices:

```bash
adb devices
flutter devices
```

Current two-device development IDs:

```text
Xiaomi  : HAF6ZXGI5TINKJCA
Samsung : R58R85Q2HWH
```

Start backend on laptop port `5001`, then reverse each phone's port `5000` to laptop port `5001`:

```bash
adb -s HAF6ZXGI5TINKJCA reverse tcp:5000 tcp:5001
adb -s R58R85Q2HWH reverse tcp:5000 tcp:5001
adb -s HAF6ZXGI5TINKJCA reverse --list
adb -s R58R85Q2HWH reverse --list
```

Install dependencies and run source checks:

```bash
flutter pub get
flutter analyze
flutter test
```

Build and install the same APK on both devices:

```bash
flutter build apk --debug
adb -s HAF6ZXGI5TINKJCA install -r -g build/app/outputs/flutter-apk/app-debug.apk
adb -s R58R85Q2HWH install -r -g build/app/outputs/flutter-apk/app-debug.apk
```

Launch both installed apps:

```bash
adb -s HAF6ZXGI5TINKJCA shell am start -n com.example.traillink/.MainActivity
adb -s R58R85Q2HWH shell am start -n com.example.traillink/.MainActivity
```

Run directly on one device instead of installing the APK manually:

```bash
flutter run -d HAF6ZXGI5TINKJCA
```

Run on the second phone from another terminal:

```bash
flutter run -d R58R85Q2HWH
```

Clear app data for a fresh test:

```bash
adb -s HAF6ZXGI5TINKJCA shell pm clear com.example.traillink
adb -s R58R85Q2HWH shell pm clear com.example.traillink
```

Capture logs during two-phone testing:

```bash
adb -s HAF6ZXGI5TINKJCA logcat -c
adb -s R58R85Q2HWH logcat -c
adb -s HAF6ZXGI5TINKJCA logcat | grep TrailLink
adb -s R58R85Q2HWH logcat | grep TrailLink
```

### 4. Run On A Physical Android Phone Over Wi-Fi

Use this Flutter `.env`, replacing the IP with your laptop LAN IP:

```env
API_BASE_URL=http://192.168.1.20:5001/api
APP_ENV=development
```

Then run:

```bash
flutter run -d <device_id>
```

The phone and laptop must be on the same network, and Windows Firewall must allow the backend port.

## Useful Commands

Analyze and test:

```bash
flutter analyze
flutter test
```

Build debug APK:

```bash
flutter build apk --debug
```

Clear app data on a device:

```bash
adb -s <device_id> shell pm clear com.example.traillink
```

Install debug APK:

```bash
adb -s <device_id> install -r -g build/app/outputs/flutter-apk/app-debug.apk
```

Backend smoke checks:

```bash
cd backend
npm run test:phase02
npm run test:phase03
npm run test:phase09
npm run test:phase10
npm run test:phase12
npm run test:phase14j
```

## App Flow

1. Open TrailLink.
2. Create or load a local profile.
3. Choose a communication mode.
4. Create or join an Online Trip or Offline Trip.
5. Use the tools shown for the active mode.

Online mode shows online trip tools and cloud chat. Offline mode shows offline trip tools and nearby communication features.

## Online Trip

Online Trip is used when the team has internet access.

User flow:

1. Select Online Mode.
2. Create an Online Trip.
3. TrailLink creates a backend group and generates a code such as `TL-ONLI-ABCDE`.
4. Other members join using the generated trip code.
5. Team chat uses the backend and Socket.IO.
6. Group details show trip code, owner/member roles, and member list.

Online Trip features:

- Backend group creation
- Join by trip code
- Online team chat
- Member list
- Owner/member role display
- Owner trip management
- Local cache for fast reopen

## Offline Trip

Offline Trip is used when the team needs local communication between nearby phones.

User flow:

1. Select Offline Mode.
2. Create an Offline Trip.
3. TrailLink creates one primary offline channel and generates a code such as `TL-OFF-ABCD`.
4. Other members join using the offline trip code.
5. Open Connect Phones.
6. One phone selects **Make My Phone Visible**.
7. Another phone selects **Find Nearby Phones**.
8. Members communicate through the active offline channel.

Offline Trip features:

- Nearby Chat
- Connect Phones
- Voice-note PTT
- Live Radio
- Offline SOS
- Offline location sharing
- Network Compass
- Member list and owner actions
- Trip delete for owner-created trips

## Connect Phones

Connect Phones is used in Offline Mode to link nearby teammates in the same offline trip.

The screen shows:

- The active offline trip and code
- Phone visibility state
- Finding phones state
- Connected teammate count
- Nearby teammate cards
- Reconnect actions when a phone was seen before

TrailLink filters nearby phones by the active trip/channel code so another trip does not appear in the active offline team.

## Nearby Chat

Nearby Chat sends text messages through connected phones in the same offline trip.

Message behavior:

- Sent messages appear in the local chat timeline.
- Received messages appear in the same offline chat.
- Delivery state updates when the other phone acknowledges the packet.
- Messages remain attached to the active offline trip/channel.

## Voice-Note PTT

Voice-note PTT lets users hold, record, send, and replay short voice notes in an offline trip.

The voice note UI shows:

- Play/pause button
- Duration
- Progress timeline
- Sent/received state
- Delivery state

## Live Radio

Live Radio provides hold-to-talk near-live audio for connected offline teammates.

Flow:

1. User opens Talk/PTT.
2. User selects Live Radio.
3. User holds the talk button.
4. Connected teammates hear the live audio.
5. Releasing the button stops the stream and releases the speaking turn.

## SOS

SOS lets users alert teammates in online or offline contexts.

Online SOS:

- Uses the backend and online group context.
- Sends alert details to the online team.

Offline SOS:

- Uses the active offline channel.
- Sends a nearby SOS packet to connected teammates.
- Supports QA-safe emergency wording and local alert display.

Locked-screen SOS:

- App lock can protect normal app access.
- SOS remains available as a safety action according to app-lock settings.

## Map And Location Sharing

Map tools show user and teammate location context.

Online mode:

- Uses backend-backed group context.
- Shows online trip location updates.

Offline mode:

- Uses the active offline channel.
- Share Location sends a nearby location packet.
- Received teammate locations are stored locally and displayed in the offline trip context.

## Network Compass

Network Compass helps users find better internet signal while moving.

It measures:

- Backend reachability
- Ping
- Download speed
- Current movement/location context

It stores samples locally and highlights the best measured nearby spot.

## Notifications

TrailLink uses local Android notifications for app events such as:

- New chat activity
- Offline message packet activity
- SOS activity
- Internet availability updates

Notification text is privacy-aware and controlled by local app settings.

## Trip And Member Management

Trip management supports:

- One selected online trip
- One selected offline trip
- Owner/member role display
- Member list
- Owner-only member removal
- Owner-only trip delete
- Member leave action

Deleting an owner-created trip removes the trip, its saved channel, membership cache, and local communication data from the device.

## Settings

Settings include:

- Profile details
- Online/offline feature toggles
- Notifications
- SOS preferences
- App lock and PIN behavior
- Location and safety preferences

## Client System Document

See the detailed system guide:

```text
docs/TRAILLINK_MVP_SYSTEM_DOCUMENTATION.md
```
