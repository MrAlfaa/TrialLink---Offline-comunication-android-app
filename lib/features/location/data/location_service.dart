import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/models/user_model.dart';
import 'models/location_update_model.dart';

class LocationService {
  LocationService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<LocationUpdateModel> captureCurrentLocation({
    required UserModel user,
    String? groupId,
    String? offlineChannelId,
    String? channelCode,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is permanently denied.');
    }
    if (permission == LocationPermission.denied) {
      throw StateError(
          'Location permission is required to share your position.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );

    final now = DateTime.now();
    return LocationUpdateModel(
      localLocationId: _uuid.v4(),
      groupId: groupId,
      offlineChannelId: offlineChannelId,
      channelCode: channelCode,
      userId: user.id,
      userName: user.fullName,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      speed: position.speed,
      heading: position.heading,
      capturedAt: position.timestamp,
      source: 'gps',
      shareStatus: 'queued',
      syncState: groupId == null ? 'local_only' : 'needs_sync',
      createdAt: now,
    );
  }
}
