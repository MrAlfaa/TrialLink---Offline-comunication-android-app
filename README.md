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
  assets/                  App branding and bundled assets
  android/                  Android project
  backend/                  Node.js API and Socket.IO backend
  .env.example              Flutter environment template
  pubspec.yaml              Flutter package config
```

The `deploy` branch contains runtime source only. QA evidence, test sources,
generated uploads, build output, and machine-specific files are excluded.

## Prerequisites

Install these before running the project:

- Flutter SDK
- Android Studio or Android SDK command-line tools
- JDK 17 (Android Studio's bundled JDK is recommended)
- Node.js LTS
- Git
- MongoDB Atlas connection string or a reachable MongoDB instance
- Android phone with USB debugging, or an Android Studio emulator

Check Flutter:

```bash
flutter doctor
flutter devices
```

## Clone And Initial Setup

Clone the deployment branch.

Git Bash:

```bash
git clone -b deploy https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
cd TrialLink---Offline-comunication-android-app
cp .env.example .env
cp backend/.env.example backend/.env
flutter pub get
cd backend
npm install
cd ..
```

PowerShell:

```powershell
git clone -b deploy https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
Set-Location "TrialLink---Offline-comunication-android-app"
Copy-Item .env.example .env
Copy-Item backend/.env.example backend/.env
flutter pub get
Set-Location backend
npm install
Set-Location ..
```

## Configure Environment Files

Edit `backend/.env` and provide a real MongoDB connection and a long random JWT secret:

```env
PORT=5001
NODE_ENV=development
MONGO_URI=your_mongodb_connection_string
JWT_SECRET=replace_with_a_long_random_secret
JWT_EXPIRES_IN=7d
```

The root `.env` depends on the Android target.

For an Android Studio emulator:

```env
API_BASE_URL=http://10.0.2.2:5001/api
APP_ENV=development
```

For a USB-connected physical Android phone using `adb reverse`:

```env
API_BASE_URL=http://127.0.0.1:5000/api
APP_ENV=development
```

Never commit real `.env` files, MongoDB credentials, or JWT secrets.

## Start The Backend

Keep the backend running in its own terminal while using Online Trip features.

Git Bash:

```bash
cd backend
npm run dev
```

In a second Git Bash terminal, verify it:

```bash
curl http://127.0.0.1:5001/api/health
```

PowerShell:

```powershell
Set-Location backend
npm run dev
```

In a second PowerShell terminal, verify it:

```powershell
Invoke-RestMethod http://127.0.0.1:5001/api/health
```

The backend URL on the laptop is `http://127.0.0.1:5001/api`.

## Run With Android Studio Emulator

1. Open Android Studio and choose **Open**.
2. Select the cloned repository root, not only the `android/` folder.
3. Confirm the Flutter and Dart plugins are installed.
4. Open **Tools > Device Manager**, create an Android virtual device, and start it.
5. Set the root `.env` to use `http://10.0.2.2:5001/api`.
6. Start the backend in Android Studio's Terminal or a separate terminal.
7. Select the emulator in the device selector and run `lib/main.dart`.

The same emulator can be launched from either shell.

Git Bash:

```bash
flutter devices
flutter run -d emulator-5554
```

PowerShell:

```powershell
flutter devices
flutter run -d emulator-5554
```

Replace `emulator-5554` with the ID shown by `flutter devices`.

## Run On A Physical Android Phone With USB Debugging

On the phone:

1. Open **Settings > About phone** and tap **Build number** seven times.
2. Open **Developer options** and enable **USB debugging**.
3. Connect the phone with a data-capable USB cable.
4. Accept the **Allow USB debugging** prompt on the phone.
5. Some Xiaomi devices also require **Install via USB** to be enabled.

Set the root `.env` to use `http://127.0.0.1:5000/api`, then confirm the phone ID.

Git Bash:

```bash
adb devices
flutter devices
adb -s <device_id> reverse tcp:5000 tcp:5001
adb -s <device_id> reverse --list
flutter run -d <device_id>
```

PowerShell:

```powershell
adb devices
flutter devices
adb -s <device_id> reverse tcp:5000 tcp:5001
adb -s <device_id> reverse --list
flutter run -d <device_id>
```

`adb reverse` maps phone port `5000` to backend port `5001` on the laptop. Run it again after reconnecting the USB cable or restarting ADB.

## Run On Two Physical Android Phones

Use two Git Bash terminals. Terminal 1 runs the backend continuously. Terminal 2 runs Flutter and ADB commands from the project root.

Before starting, replace the example project path and phone IDs with values from your computer. Do not type the `<` or `>` characters shown in placeholders.

Example Git Bash project paths:

```text
/d/Projects/TrialLink---Offline-comunication-android-app
/e/PROJECTS/Out Source Project/TrailLink-Android Flutter App
```

### Git Bash Terminal 1 - Start The Backend

Open Git Bash and run:

```bash
TRAILLINK_DIR="/d/Projects/TrialLink---Offline-comunication-android-app"
cd "$TRAILLINK_DIR/backend"
npm install
npm run dev
```

Leave Terminal 1 open. The backend must continue running on laptop port `5001`.

Open a second Git Bash terminal and confirm backend health:

```bash
curl http://127.0.0.1:5001/api/health
```

### Git Bash Terminal 2 - Build And Run Both Phones

The following commands must run from the Flutter project root, where `pubspec.yaml` is located:

```bash
TRAILLINK_DIR="/d/Projects/TrialLink---Offline-comunication-android-app"
cd "$TRAILLINK_DIR"

adb devices
flutter devices
```

Copy the two serial numbers shown under `List of devices attached`. Assign them once so later commands are easier to read:

```bash
DEVICE_A="your_first_phone_serial"
DEVICE_B="your_second_phone_serial"

adb -s "$DEVICE_A" reverse tcp:5000 tcp:5001
adb -s "$DEVICE_B" reverse tcp:5000 tcp:5001
adb -s "$DEVICE_A" reverse --list
adb -s "$DEVICE_B" reverse --list

flutter pub get
flutter analyze
flutter build apk --debug

APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
adb -s "$DEVICE_A" install -r -g "$APK_PATH"
adb -s "$DEVICE_B" install -r -g "$APK_PATH"

adb -s "$DEVICE_A" shell am start -n com.example.traillink/.MainActivity
adb -s "$DEVICE_B" shell am start -n com.example.traillink/.MainActivity
```

For this USB workflow, the root `.env` must contain:

```env
API_BASE_URL=http://127.0.0.1:5000/api
APP_ENV=development
```

### PowerShell Terminal 1 - Start The Backend

Replace the example path with the cloned repository path:

```powershell
$TrailLinkDir = "D:\Projects\TrialLink---Offline-comunication-android-app"
Set-Location "$TrailLinkDir\backend"
npm install
npm run dev
```

Leave Terminal 1 open. In another PowerShell terminal, verify backend health:

```powershell
Invoke-RestMethod http://127.0.0.1:5001/api/health
```

### PowerShell Terminal 2 - Build And Run Both Phones

```powershell
$TrailLinkDir = "D:\Projects\TrialLink---Offline-comunication-android-app"
Set-Location $TrailLinkDir

adb devices
flutter devices

$DeviceA = "your_first_phone_serial"
$DeviceB = "your_second_phone_serial"

adb -s $DeviceA reverse tcp:5000 tcp:5001
adb -s $DeviceB reverse tcp:5000 tcp:5001
adb -s $DeviceA reverse --list
adb -s $DeviceB reverse --list

flutter pub get
flutter analyze
flutter build apk --debug

$ApkPath = "build\app\outputs\flutter-apk\app-debug.apk"
adb -s $DeviceA install -r -g $ApkPath
adb -s $DeviceB install -r -g $ApkPath

adb -s $DeviceA shell am start -n com.example.traillink/.MainActivity
adb -s $DeviceB shell am start -n com.example.traillink/.MainActivity
```

### Optional Fresh Installation

Clearing app data deletes the local profile, trips, chats, and settings on that phone. Use it only when a fresh setup is required.

Git Bash:

```bash
adb -s "$DEVICE_A" shell pm clear com.example.traillink
adb -s "$DEVICE_B" shell pm clear com.example.traillink
```

PowerShell:

```powershell
adb -s $DeviceA shell pm clear com.example.traillink
adb -s $DeviceB shell pm clear com.example.traillink
```

## Build And Diagnostic Commands

Git Bash:

```bash
flutter doctor -v
flutter devices
flutter analyze
flutter build apk --debug
adb -s <device_id> logcat | grep TrailLink
```

PowerShell:

```powershell
flutter doctor -v
flutter devices
flutter analyze
flutter build apk --debug
adb -s <device_id> logcat | Select-String TrailLink
```

Debug APK output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

If Gradle reports an invalid `JAVA_HOME`, set it to Android Studio's bundled JDK path or an installed JDK 17. If Flutter reports duplicate asset files, run `flutter clean`, `flutter pub get`, and build again.

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
