# TrailLink MVP System Documentation

## 1. Product Overview

TrailLink is an outdoor communication and safety app for hikers, campers, field teams, and remote-area groups. The app provides two practical communication paths:

- **Online Trip** for normal internet-based team communication.
- **Offline Trip** for nearby phone-to-phone communication when the team is away from internet coverage.

The app keeps the user flow simple:

1. Create Online Trip.
2. Create Offline Trip.
3. Join Trip.

TrailLink uses the right tools for the active mode. Online Mode shows online group and chat tools. Offline Mode shows nearby communication and safety tools.

## 2. Main User Roles

### Trip Owner

The trip owner is the user who creates the trip.

Owner abilities:

- Create the trip.
- Share the trip code with teammates.
- View trip details.
- View member list.
- Remove members where supported.
- End, archive, or delete owner-created trips.

### Trip Member

Trip members join using the trip code.

Member abilities:

- Join an online or offline trip.
- View the active trip and trip code.
- Chat with the team.
- Use safety tools available for the active mode.
- Leave the trip from their device.

## 3. Communication Modes

TrailLink supports three mode controls:

- **Online Mode**: uses internet and backend services.
- **Offline Mode**: uses nearby phone-to-phone communication.
- **Auto Mode**: selects the suitable mode based on backend/network reachability.

The app keeps the active online trip and active offline trip separately. This prevents online groups and offline channels from being mixed in the same screen.

## 4. Online Trip Flow

Online Trip is used when the team has internet access.

### Create Online Trip

Steps:

1. User opens TrailLink.
2. User chooses Online Mode.
3. User selects Create Trip.
4. User enters trip name and basic trip details.
5. TrailLink creates a backend group.
6. Backend generates a trip code using the `TL-ONLI-XXXXX` format.
7. Trip becomes the active online trip.
8. Online tools become available.

### Join Online Trip

Steps:

1. Member chooses Join Trip.
2. Member enters the online trip code.
3. Backend validates membership.
4. TrailLink downloads group/trip details.
5. Member sees the same trip name, code, and team context.

### Online Trip Data

Online trips use:

- Backend group id.
- Generated online trip code.
- Owner/member roles.
- Backend chat history.
- Socket.IO live message delivery.
- Local cache for quick reopen.

## 5. Offline Trip Flow

Offline Trip is used when team members need local communication between nearby phones.

### Create Offline Trip

Steps:

1. User chooses Offline Mode.
2. User selects Create Trip.
3. User enters a trip name.
4. TrailLink creates one primary offline channel for that trip.
5. TrailLink generates an offline code such as `TL-OFF-ABCD`.
6. The new trip becomes the active offline trip.
7. Offline tools become available.

### Join Offline Trip

Steps:

1. Member chooses Join Trip.
2. Member enters the offline trip code.
3. TrailLink creates a local membership record.
4. Member opens Connect Phones.
5. Phones connect through the same offline channel.
6. Member sees the active offline trip and tools.

### Offline Trip Data

Offline trips use:

- Local trip id.
- One primary offline channel.
- Offline trip code.
- Local member records.
- Local chat history.
- Nearby connection state.
- Local SOS, location, and voice records.

## 6. Trip And Channel Model

TrailLink uses a simple MVP model:

- One online trip can be selected for Online Mode.
- One offline trip can be selected for Offline Mode.
- One offline trip has one primary offline channel.

The trip is the team activity, such as a hike or camp. The channel is the communication room used by that trip. The user normally thinks in terms of trips, while the app uses the channel internally to keep nearby messages and safety packets grouped correctly.

## 7. Home Screen

The Home screen summarizes the active mode and trip.

Online Mode home shows:

- Active online trip name.
- Trip code.
- Online trip status.
- Online tools.

Offline Mode home shows:

- Active offline trip name.
- Offline trip code.
- Offline tools.
- Connect Phones shortcut.
- Nearby Chat shortcut.
- SOS and Map actions.

## 8. Messages

The Messages screen shows chat choices for the active mode.

### Online Mode Messages

Online Mode shows cloud/online groups and online chat entries.

Online chat uses:

- Backend APIs.
- Socket.IO live delivery.
- Local message cache.
- Backend message history.

### Offline Mode Messages

Offline Mode shows only the active offline trip/channel chat.

Offline chat uses:

- Nearby connected phones.
- Local SQLite message timeline.
- Delivery acknowledgement packets.
- Active offline trip/channel code matching.

## 9. Connect Phones

Connect Phones is used in Offline Mode.

Purpose:

- Make a phone visible to teammates.
- Find nearby teammate phones.
- Connect phones in the same offline trip.
- Show connected teammate count.
- Show reconnect action for previously seen phones.

Flow:

1. Owner/member opens Connect Phones.
2. One phone selects **Make My Phone Visible**.
3. Another phone selects **Find Nearby Phones**.
4. Matching phones appear in the list.
5. User connects to the teammate phone.
6. Offline chat and safety tools use the active nearby connection.

## 10. Offline Chat

Offline Chat sends text between connected phones in the same offline trip.

Message lifecycle:

1. Sender writes a message.
2. Message is saved locally.
3. TrailLink sends the message packet to connected phones.
4. Receiver stores and displays the message.
5. Receiver sends an acknowledgement.
6. Sender updates the delivery status.

Offline chat is scoped to the active offline trip and its channel code.

## 11. Voice-Note PTT

Voice-note PTT is a hold-to-record voice message tool for offline trips.

Flow:

1. User opens Talk/PTT.
2. User holds the record action.
3. TrailLink records a valid voice note.
4. User releases the action.
5. Voice note is sent to connected teammates.
6. Teammates can play the received voice note.

Voice note bubbles show:

- Play/pause control.
- Duration.
- Progress timeline.
- Sent/received status.
- Delivery state.

## 12. Live Radio

Live Radio is a hold-to-talk near-live audio feature for connected offline teammates.

Flow:

1. User opens Talk/PTT.
2. User selects Live Radio.
3. User holds the talk button.
4. TrailLink opens the speaking turn.
5. Connected teammates hear the live voice stream.
6. User releases the button.
7. TrailLink stops the stream and releases the speaking turn.

The Live Radio state keeps one active speaker at a time so teammates can take turns.

## 13. SOS

SOS is used to send an emergency alert to the active team context.

### Online SOS

Online SOS uses:

- Active online trip/group.
- Backend API.
- Socket.IO team notification.
- Stored emergency event.

### Offline SOS

Offline SOS uses:

- Active offline trip/channel.
- Nearby connected phones.
- Local emergency event storage.
- SOS packets sent to teammates.

### Locked-Screen SOS

TrailLink includes app-lock support. The SOS safety action remains available according to the configured safety settings.

## 14. Map And Location Sharing

The map feature displays local and teammate location context.

### Online Map

Online Map uses backend group context and synced location updates.

### Offline Map

Offline Map uses the active offline trip/channel.

Flow:

1. User opens Map in Offline Mode.
2. User taps Share Location.
3. TrailLink captures the current location.
4. TrailLink sends a nearby location packet.
5. Receiver stores and displays teammate location.

## 15. Network Compass

Network Compass helps users find a better internet spot while moving.

It measures:

- Backend reachability.
- Ping.
- Download speed.
- Movement/location context.

It stores samples locally and shows the best measured nearby location so the user can move toward stronger connectivity.

## 16. Notifications

TrailLink uses local Android notifications.

Notification use cases:

- New online chat activity.
- New offline chat activity.
- SOS activity.
- Voice or packet activity.
- Internet availability updates.

Notifications use privacy-aware wording. Message previews are controlled by local settings.

## 17. App Lock

App Lock protects normal app access with a PIN/security flow.

Protected areas:

- Private profile data.
- Trip screens.
- Team data.
- Message screens.

Safety actions remain available according to configured SOS behavior.

## 18. Trip Management

Trip management lets users manage saved trips by mode.

Owner actions:

- Activate trip.
- Archive trip.
- Delete trip.
- Remove members where supported.

Member actions:

- Activate joined trip.
- Leave trip.

Delete Trip removes the trip from the device together with its saved channel, member cache, message cache, voice notes, SOS records, location records, and nearby connection records for that trip.

## 19. Member Management

Member screens show:

- Owner.
- Current user as You.
- Joined members.
- Presence wording.
- Remove member action for owner.
- Leave action for member.

Offline member state is stored locally and updated when phones exchange trip/member packets.

## 20. Settings

Settings provide controls for:

- Profile information.
- Notification preferences.
- Feature toggles.
- SOS settings.
- Location sharing.
- App lock.
- Voice and radio settings.

## 21. Backend Services

Backend services support online features:

- Authentication.
- User profile.
- Online groups/trips.
- Group membership.
- Online chat.
- SOS events.
- Location updates.
- Trip metadata.
- Network probe.

Backend runs on port `5001` in local development.

## 22. Local Storage

TrailLink stores app data locally with SQLite.

Local storage includes:

- Profile identity.
- Active mode and selected trips.
- Offline channels.
- Offline members.
- Chat records.
- Nearby phone records.
- SOS and location records.
- Voice note metadata.
- Network Compass samples.

This local storage keeps the app usable in offline conditions and supports fast app reopening.

## 23. Permissions

TrailLink uses Android permissions for:

- Location.
- Nearby/Bluetooth connection.
- Microphone.
- Notifications.
- App lock/biometric flow where supported.

The setup flow guides users through required and optional readiness checks.

## 24. Developer Runbook

Start backend:

```bash
cd backend
npm install
npm run dev
```

Run Flutter on emulator:

```bash
flutter pub get
flutter run -d <emulator_id>
```

Run Flutter on physical phone through USB reverse:

```bash
adb -s <device_id> reverse tcp:5000 tcp:5001
flutter run -d <device_id>
```

Build APK:

```bash
flutter build apk --debug
```

Install APK:

```bash
adb -s <device_id> install -r -g build/app/outputs/flutter-apk/app-debug.apk
```

Run checks:

```bash
flutter analyze
flutter test
```

## 25. Demonstration Flow

### Online Demo

1. Start backend.
2. Open TrailLink on two phones.
3. Apply `adb reverse` to both phones.
4. Select Online Mode.
5. Owner creates Online Trip.
6. Member joins using the generated online trip code.
7. Open online chat.
8. Send messages both directions.
9. Open Group Details and show members.

### Offline Demo

1. Select Offline Mode on both phones.
2. Owner creates Offline Trip.
3. Member joins with the offline trip code.
4. Open Connect Phones.
5. Make one phone visible.
6. Find nearby phones on the other.
7. Connect phones.
8. Send offline chat messages.
9. Open Map and share location.
10. Open SOS and send a test alert.
11. Open Talk/PTT and test voice note.
12. Select Live Radio and test hold-to-talk.

## 26. Client Handoff Summary

TrailLink MVP provides:

- Online team trip creation and chat.
- Offline trip creation and nearby communication.
- Separate online/offline trip flows.
- Local safety tools for offline use.
- SOS, location, voice-note, and Live Radio tools.
- Local Android notifications.
- App lock and safety access.
- Owner/member management.
- Local cache for offline continuity.

