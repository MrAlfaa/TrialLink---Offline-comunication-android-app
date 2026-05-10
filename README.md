# TrailLink Frontend-Only Demo

This branch contains only the Flutter/Android frontend for TrailLink. The Node.js backend has been removed from this branch on purpose.

The app runs as a local-first demo with seeded data:

- local demo profile: `TrailLink Demo User`
- manual offline mode
- active trip: `Demo Ridge Hike`
- active channel: `TL-OFF-DEMO`
- seeded offline chat messages
- no MongoDB, Node.js, Socket.IO server, or backend API required

## Requirements

- Flutter SDK
- Android SDK
- Android emulator or physical Android phone with USB debugging enabled

## Setup

Create a local `.env` from the example:

```powershell
Copy-Item .env.example .env
```

Git Bash:

```bash
cp .env.example .env
```

The frontend-only `.env` intentionally leaves `API_BASE_URL` blank:

```env
API_BASE_URL=
APP_ENV=frontend_demo
APP_FRONTEND_ONLY=true
```

If `.env` is missing, this branch still defaults to frontend-only demo mode.

## Run

PowerShell:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Git Bash:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Run on a specific physical device:

```powershell
flutter run -d R58R85Q2HWH
```

## Demo Behavior

On launch, the app seeds local SQLite data when frontend demo mode is enabled. It marks setup as complete and opens the local offline app shell. Cloud and backend sync are paused by default.

Use the seeded channel `TL-OFF-DEMO` to inspect:

- Home
- Messages
- Offline Chat
- Nearby Peers
- PTT
- SOS
- Map and location sharing UI

P2P functions still require real Android Nearby permissions and two nearby phones. They do not require the removed backend.

## Important Branch Notes

- `master` keeps the full Flutter + backend history.
- `final` was created from `master` and is intentionally untouched.
- `frontendonly` removes the backend folder and runs with local demo data.
