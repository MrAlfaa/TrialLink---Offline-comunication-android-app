import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class NearbyPermissionState {
  const NearbyPermissionState({
    required this.granted,
    this.message,
  });

  final bool granted;
  final String? message;
}

class NearbyPermissionService {
  Future<NearbyPermissionState> checkAndRequest() async {
    if (!Platform.isAndroid) {
      return const NearbyPermissionState(
        granted: false,
        message: 'Nearby offline discovery is available on Android devices.',
      );
    }

    final android = await DeviceInfoPlugin().androidInfo;
    final permissions = <Permission>[Permission.location];

    if (android.version.sdkInt >= 31) {
      permissions.addAll([
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ]);
    } else {
      permissions.add(Permission.bluetooth);
    }

    if (android.version.sdkInt >= 33) {
      permissions.add(Permission.nearbyWifiDevices);
    }

    final statuses = await permissions.request();
    final denied = statuses.entries
        .where((entry) => !entry.value.isGranted && !entry.value.isLimited)
        .map((entry) => entry.key)
        .toList();

    if (denied.isNotEmpty) {
      return const NearbyPermissionState(
        granted: false,
        message: 'Nearby permissions are required for offline communication.',
      );
    }

    final locationEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!locationEnabled) {
      return const NearbyPermissionState(
        granted: false,
        message: 'Please turn on Location services for Nearby discovery.',
      );
    }

    return const NearbyPermissionState(granted: true);
  }
}
