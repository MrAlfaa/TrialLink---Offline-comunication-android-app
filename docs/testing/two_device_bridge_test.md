# TrailLink Two-Device Bridge Test Guide

## Prerequisites

- Two physical Android devices connected to the laptop.
- Backend running on the laptop and reachable from both phones by local machine IP.
- TrailLink installed on both devices.
- Nearby/Bluetooth/Wi-Fi permissions granted.
- Bluetooth and Wi-Fi enabled on both devices.
- Do not use airplane mode if it disables Nearby transport.
- Use Manual Offline Mode on the offline device to test offline logic.

## Device Setup

Device 1:
- Login online.
- Join or create a cloud group.
- Create or select an active trip.
- Ensure the trip has an offline channel code.
- Enable Bridge Mode in Settings.
- Set mode to Auto or Online.
- Start Nearby discovery/advertising.

Device 2:
- Continue as offline guest or cached user.
- Join the same offline channel code.
- Set mode to Offline.
- Start Nearby discovery/advertising.
- Connect to Device 1.

## Test A: Offline Text To Online Bridge

1. Device 2 sends an offline chat message.
2. Device 1 receives the offline packet.
3. Device 1 uploads it to the backend as `sourcePath=bridge`.
4. Online chat shows the message with bridge metadata.

## Test B: Online To Offline Bridge

1. Device 1 sends an online group chat message.
2. Device 1 forwards that message to nearby offline peers.
3. Device 2 stores the received packet locally.
4. Device 2 shows the message as delivered via bridge.

## Test C: Offline SOS Bridge

1. Device 2 sends offline SOS.
2. Device 1 receives and shows the local SOS alert.
3. Device 1 uploads SOS to backend.
4. Backend stores the event as `sourcePath=bridge`.
5. UI labels the alert as bridged via Device 1.

SOS without location is valid. If Device 2 disabled SOS location consent, the bridge must upload the SOS without coordinates.

## Test D: Offline Location Bridge

1. Device 2 shares location offline.
2. Device 1 receives the location packet.
3. Device 1 uploads it to the backend with origin metadata.
4. Online map/backend shows the location as bridged.

## Test E: Duplicate Prevention

1. Resend the same packet.
2. Device 1 should save a duplicate ignored record.
3. No duplicate upload or duplicate UI message should appear.

## ADB Notes

```powershell
flutter devices
flutter run -d <device_1_id>
flutter run -d <device_2_id>
```

Use different user accounts or an offline guest identity on one device.
