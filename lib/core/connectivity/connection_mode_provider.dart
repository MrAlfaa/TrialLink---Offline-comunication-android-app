import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_reachability_service.dart';
import 'connection_mode_controller.dart';
import 'connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final backendReachabilityServiceProvider =
    Provider<BackendReachabilityService>((ref) {
  return BackendReachabilityService();
});

final connectionModeProvider =
    StateNotifierProvider<ConnectionModeController, ConnectionModeState>((ref) {
  return ConnectionModeController(
    connectivityService: ref.read(connectivityServiceProvider),
    reachabilityService: ref.read(backendReachabilityServiceProvider),
  );
});
