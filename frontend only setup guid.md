# TrailLink Frontend-Only Setup Guide

This guide explains how to download and run the `frontendonly` branch from GitHub.

This branch is frontend-only:

- no Node.js backend
- no MongoDB
- no API server
- no `adb reverse`
- no backend `.env`
- app runs with local demo data

The demo automatically seeds:

- user: `TrailLink Demo User`
- trip: `Demo Ridge Hike`
- channel: `TL-OFF-DEMO`
- mode: Manual Offline
- sample offline chat messages

Repository:

```text
https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
```

## 1. Required Software

Install these before running the app:

- Git
- Flutter SDK
- Android Studio
- Android SDK Platform Tools
- Android emulator or physical Android phone

Check Flutter:

```bash
flutter doctor
```

If Flutter reports Android license issues, run:

```bash
flutter doctor --android-licenses
```

## 2. Download From GitHub

### Windows Git Bash

Open Git Bash and run:

```bash
cd /e/PROJECTS
git clone https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
cd "TrialLink---Offline-comunication-android-app"
git checkout frontendonly
```

If you downloaded a ZIP instead of cloning, extract it, open Git Bash inside the extracted folder, then run:

```bash
git checkout frontendonly
```

### macOS Terminal

Open Terminal and run:

```bash
cd ~/Documents
git clone https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
cd "TrialLink---Offline-comunication-android-app"
git checkout frontendonly
```

## 3. Configure Frontend Demo Environment

The frontend-only branch uses this `.env.example`:

```env
API_BASE_URL=
APP_ENV=frontend_demo
APP_FRONTEND_ONLY=true
```

Create `.env`.

### Windows Git Bash

```bash
cp .env.example .env
```

### macOS Terminal

```bash
cp .env.example .env
```

The app still defaults to frontend demo mode if `.env` is missing, but keeping the file is better for consistency.

## 4. Install Flutter Packages

Run:

```bash
flutter pub get
```

Optional checks:

```bash
flutter analyze
flutter test
```

## 5. Run On Physical Android Device

Use this for a real Android phone connected by USB.

### Phone Setup

On the phone:

1. Enable Developer Options.
2. Enable USB Debugging.
3. Connect the phone to the computer using USB.
4. Accept the RSA debugging prompt on the phone.

### Check Device

Windows Git Bash or macOS Terminal:

```bash
adb devices
```

Expected:

```text
List of devices attached
R58R85Q2HWH    device
```

If it says `unauthorized`, unlock the phone and accept the USB debugging prompt.

### Run On Device

Use the device id shown by `adb devices`.

Example:

```bash
flutter run -d R58R85Q2HWH
```

If multiple devices are connected:

```bash
flutter devices
flutter run -d YOUR_DEVICE_ID
```

### Fresh Demo Reset

If the app shows old local data, clear app data and run again:

```bash
adb -s R58R85Q2HWH shell pm clear com.example.traillink
flutter run -d R58R85Q2HWH
```

After reset, the app should show:

```text
TrailLink Demo User
Demo Ridge Hike
TL-OFF-DEMO
Offline Mode
```

## 6. Run On Android Studio Emulator

### Create Emulator

In Android Studio:

1. Open Android Studio.
2. Go to Device Manager.
3. Create a virtual device.
4. Recommended: Pixel device with Android 13 or newer.
5. Start the emulator.

### Check Emulator

Run:

```bash
flutter devices
```

Example output:

```text
emulator-5554 • sdk gphone64 x86 64 • android-x64 • Android 14
```

### Run On Emulator

```bash
flutter run -d emulator-5554
```

Or run on the first available emulator:

```bash
flutter run
```

### Fresh Demo Reset On Emulator

```bash
adb -s emulator-5554 shell pm clear com.example.traillink
flutter run -d emulator-5554
```

## 7. Build Debug APK

If you only want to build the APK:

```bash
flutter build apk --debug
```

APK output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Install the APK manually:

```bash
adb -s R58R85Q2HWH install -r -g build/app/outputs/flutter-apk/app-debug.apk
adb -s R58R85Q2HWH shell am start -n com.example.traillink/com.example.traillink.MainActivity
```

For emulator:

```bash
adb -s emulator-5554 install -r -g build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.example.traillink/com.example.traillink.MainActivity
```

## 8. macOS Notes

If `adb` is not found on macOS, add Android platform tools to your shell profile.

For Apple Silicon or Intel macOS:

```bash
echo 'export ANDROID_HOME="$HOME/Library/Android/sdk"' >> ~/.zshrc
echo 'export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"' >> ~/.zshrc
source ~/.zshrc
adb devices
```

If Flutter is not found:

```bash
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
flutter doctor
```

Adjust `$HOME/development/flutter` if your Flutter SDK is installed somewhere else.

## 9. Windows Git Bash Notes

If `flutter` is not found in Git Bash, add Flutter to Windows PATH, then close and reopen Git Bash.

Common checks:

```bash
where.exe flutter
where.exe adb
flutter doctor
adb devices
```

If Git Bash path navigation fails, remember there is a space in `cd ..`:

```bash
cd ..
```

Not:

```bash
cd..
```

## 10. Troubleshooting

### App Opens Old Data

Clear local app data:

```bash
adb -s YOUR_DEVICE_ID shell pm clear com.example.traillink
flutter run -d YOUR_DEVICE_ID
```

### Device Not Detected

```bash
adb kill-server
adb start-server
adb devices
```

Then reconnect USB and accept the phone prompt.

### Emulator Black Screen Or Lost Connection

This is often emulator instability. Try:

```bash
adb devices
flutter devices
adb -s emulator-5554 shell pidof com.example.traillink
adb -s emulator-5554 logcat -d -b crash
```

If the emulator is unstable, restart it from Android Studio Device Manager.

### Backend Error

The `frontendonly` branch does not need a backend. Confirm `.env` has:

```env
API_BASE_URL=
APP_ENV=frontend_demo
APP_FRONTEND_ONLY=true
```

Then clear app data and rerun.

## 11. Quick Command Summary

### Windows Git Bash

```bash
cd /e/PROJECTS
git clone https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
cd "TrialLink---Offline-comunication-android-app"
git checkout frontendonly
cp .env.example .env
flutter pub get
flutter analyze
flutter test
adb devices
flutter run -d R58R85Q2HWH
```

### macOS Terminal

```bash
cd ~/Documents
git clone https://github.com/MrAlfaa/TrialLink---Offline-comunication-android-app.git
cd "TrialLink---Offline-comunication-android-app"
git checkout frontendonly
cp .env.example .env
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```
