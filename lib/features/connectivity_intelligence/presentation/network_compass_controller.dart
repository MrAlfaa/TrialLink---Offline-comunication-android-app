import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models/network_speed_sample_model.dart';
import '../data/network_compass_repository.dart';

class NetworkCompassState {
  const NetworkCompassState({
    this.currentSample,
    this.bestSample,
    this.recentSamples = const [],
    this.distanceToBestMeters,
    this.bearingToBestDegrees,
    this.isMeasuring = false,
    this.errorMessage,
  });

  final NetworkSpeedSampleModel? currentSample;
  final NetworkSpeedSampleModel? bestSample;
  final List<NetworkSpeedSampleModel> recentSamples;
  final double? distanceToBestMeters;
  final double? bearingToBestDegrees;
  final bool isMeasuring;
  final String? errorMessage;

  String get qualityLabel => currentSample?.qualityLabel ?? 'No internet';
  double get currentMbps => currentSample?.downloadMbps ?? 0;
  double get headingDegrees => currentSample?.heading ?? 0;

  NetworkCompassState copyWith({
    NetworkSpeedSampleModel? currentSample,
    NetworkSpeedSampleModel? bestSample,
    List<NetworkSpeedSampleModel>? recentSamples,
    double? distanceToBestMeters,
    double? bearingToBestDegrees,
    bool? isMeasuring,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NetworkCompassState(
      currentSample: currentSample ?? this.currentSample,
      bestSample: bestSample ?? this.bestSample,
      recentSamples: recentSamples ?? this.recentSamples,
      distanceToBestMeters: distanceToBestMeters ?? this.distanceToBestMeters,
      bearingToBestDegrees: bearingToBestDegrees ?? this.bearingToBestDegrees,
      isMeasuring: isMeasuring ?? this.isMeasuring,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class NetworkCompassController extends StateNotifier<NetworkCompassState> {
  NetworkCompassController({
    NetworkCompassRepository? repository,
  })  : _repository = repository ?? NetworkCompassRepository(),
        super(const NetworkCompassState()) {
    _loadSavedSamples();
    measureNow();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => measureNow());
  }

  final NetworkCompassRepository _repository;
  Timer? _timer;

  Future<void> measureNow() async {
    if (state.isMeasuring) return;
    state = state.copyWith(isMeasuring: true, clearError: true);
    try {
      final sample = await _repository.measureAndSave();
      final recent = await _repository.recentSamples();
      final best = await _repository.bestRecentSample();
      final guidance = _bestSpotGuidance(sample, best);
      if (!mounted) return;
      state = NetworkCompassState(
        currentSample: sample,
        bestSample: best,
        recentSamples: recent,
        distanceToBestMeters: guidance.$1,
        bearingToBestDegrees: guidance.$2,
      );
    } catch (error) {
      final recent = await _repository.recentSamples();
      final best = await _repository.bestRecentSample();
      if (!mounted) return;
      state = state.copyWith(
        recentSamples: recent,
        bestSample: best,
        isMeasuring: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> _loadSavedSamples() async {
    final recent = await _repository.recentSamples();
    final best = await _repository.bestRecentSample();
    if (!mounted) return;
    state = state.copyWith(recentSamples: recent, bestSample: best);
  }

  (double?, double?) _bestSpotGuidance(
    NetworkSpeedSampleModel current,
    NetworkSpeedSampleModel? best,
  ) {
    if (best == null ||
        current.latitude == null ||
        current.longitude == null ||
        best.latitude == null ||
        best.longitude == null) {
      return (null, null);
    }
    final distance = Geolocator.distanceBetween(
      current.latitude!,
      current.longitude!,
      best.latitude!,
      best.longitude!,
    );
    final bearing = _bearing(
      current.latitude!,
      current.longitude!,
      best.latitude!,
      best.longitude!,
    );
    return (distance, bearing);
  }

  double _bearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaLon = (lon2 - lon1) * pi / 180;
    final y = sin(deltaLon) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final networkCompassControllerProvider = StateNotifierProvider.autoDispose<
    NetworkCompassController, NetworkCompassState>(
  (ref) => NetworkCompassController(),
);
