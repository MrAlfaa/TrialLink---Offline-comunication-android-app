import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../core/connectivity/connectivity_service.dart';
import 'models/network_speed_sample_model.dart';
import 'network_speed_probe_service.dart';
import 'network_speed_sample_local_data_source.dart';

class NetworkCompassRepository {
  NetworkCompassRepository({
    NetworkSpeedProbeService? probe,
    NetworkSpeedSampleLocalDataSource? local,
    ConnectivityService? connectivity,
    Uuid? uuid,
  })  : _probe = probe ?? NetworkSpeedProbeService(),
        _local = local ?? NetworkSpeedSampleLocalDataSource(),
        _connectivity = connectivity ?? ConnectivityService(),
        _uuid = uuid ?? const Uuid();

  final NetworkSpeedProbeService _probe;
  final NetworkSpeedSampleLocalDataSource _local;
  final ConnectivityService _connectivity;
  final Uuid _uuid;

  Future<NetworkSpeedSampleModel> measureAndSave() async {
    final position = await _tryPosition();
    final network = await _connectivity.currentState();
    final probe = await _probe.measure();
    final sample = NetworkSpeedSampleModel(
      sampleId: _uuid.v4(),
      createdAt: DateTime.now(),
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      heading: position?.heading,
      movementSpeedMps: position?.speed,
      networkType: network.label,
      pingMs: probe.pingMs,
      downloadMbps: probe.downloadMbps,
      uploadMbps: probe.uploadMbps,
      backendReachable: probe.backendReachable,
      errorMessage: probe.errorMessage,
    );
    await _local.insert(sample);
    return sample;
  }

  Future<List<NetworkSpeedSampleModel>> recentSamples({int limit = 20}) {
    return _local.recent(limit: limit);
  }

  Future<NetworkSpeedSampleModel?> bestRecentSample() {
    return _local.bestRecent();
  }

  Future<Position?> _tryPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
