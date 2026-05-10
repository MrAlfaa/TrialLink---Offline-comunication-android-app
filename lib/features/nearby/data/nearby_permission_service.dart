import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum NearbyPermissionReadiness { ready, missing, blocked, optional }

class NearbyPermissionState {
  const NearbyPermissionState({
    required this.granted,
    required this.readiness,
    this.message,
  });

  final bool granted;
  final NearbyPermissionReadiness readiness;
  final String? message;
}

class NearbyPermissionService {
  Future<NearbyPermissionState> checkNearbyPermissionStatus() => check();

  Future<NearbyPermissionState> check() => _checkNearbyPermissions(
        requestPermissions: false,
      );

  Future<NearbyPermissionState> checkAndRequest() async {
    return _checkNearbyPermissions(requestPermissions: true);
  }

  Future<NearbyPermissionState> _checkNearbyPermissions({
    required bool requestPermissions,
  }) async {
    if (!Platform.isAndroid) {
      return const NearbyPermissionState(
        granted: true,
        readiness: NearbyPermissionReadiness.optional,
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

    final statuses = requestPermissions
        ? await permissions.request()
        : Map<Permission, PermissionStatus>.fromEntries(
            await Future.wait(
              permissions.map((permission) async {
                return MapEntry(permission, await permission.status);
              }),
            ),
          );
    return mapStatusesForReadiness(
      statuses.values,
      locationServiceEnabled: await Permission.location.serviceStatus.isEnabled,
    );
  }

  static NearbyPermissionState mapStatusesForReadiness(
    Iterable<PermissionStatus> statuses, {
    required bool locationServiceEnabled,
  }) {
    if (statuses
        .any((status) => status.isPermanentlyDenied || status.isRestricted)) {
      return const NearbyPermissionState(
        granted: false,
        readiness: NearbyPermissionReadiness.blocked,
        message:
            'Nearby permissions are blocked. Enable them in Android Settings.',
      );
    }

    final denied =
        statuses.where((status) => !status.isGranted && !status.isLimited);
    if (denied.isNotEmpty) {
      return const NearbyPermissionState(
        granted: false,
        readiness: NearbyPermissionReadiness.missing,
        message: 'Nearby permissions are required for offline communication.',
      );
    }

    if (!locationServiceEnabled) {
      return const NearbyPermissionState(
        granted: false,
        readiness: NearbyPermissionReadiness.missing,
        message: 'Please turn on Location services for Nearby discovery.',
      );
    }

    return const NearbyPermissionState(
      granted: true,
      readiness: NearbyPermissionReadiness.ready,
    );
  }
}
