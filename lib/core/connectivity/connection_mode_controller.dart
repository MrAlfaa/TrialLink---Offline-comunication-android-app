import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_connection_mode.dart';
import 'backend_reachability_service.dart';
import 'connectivity_service.dart';

class ConnectionModeState {
  const ConnectionModeState({
    required this.mode,
    required this.hasNetworkInterface,
    required this.backendReachable,
    this.lastCheckedAt,
    this.message,
    this.connectionTypes = 'unknown',
    this.consecutiveFailures = 0,
    this.consecutiveSuccesses = 0,
    this.recentChecks = const [],
    this.isChecking = false,
  });

  factory ConnectionModeState.initial() {
    return const ConnectionModeState(
      mode: AppConnectionMode.reconnecting,
      hasNetworkInterface: false,
      backendReachable: false,
      message: 'Checking TrailLink connection...',
    );
  }

  final AppConnectionMode mode;
  final bool hasNetworkInterface;
  final bool backendReachable;
  final DateTime? lastCheckedAt;
  final String? message;
  final String connectionTypes;
  final int consecutiveFailures;
  final int consecutiveSuccesses;
  final List<bool> recentChecks;
  final bool isChecking;

  ConnectionModeState copyWith({
    AppConnectionMode? mode,
    bool? hasNetworkInterface,
    bool? backendReachable,
    DateTime? lastCheckedAt,
    String? message,
    String? connectionTypes,
    int? consecutiveFailures,
    int? consecutiveSuccesses,
    List<bool>? recentChecks,
    bool? isChecking,
  }) {
    return ConnectionModeState(
      mode: mode ?? this.mode,
      hasNetworkInterface: hasNetworkInterface ?? this.hasNetworkInterface,
      backendReachable: backendReachable ?? this.backendReachable,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      message: message ?? this.message,
      connectionTypes: connectionTypes ?? this.connectionTypes,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      recentChecks: recentChecks ?? this.recentChecks,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

class ConnectionModeController extends StateNotifier<ConnectionModeState> {
  ConnectionModeController({
    required ConnectivityService connectivityService,
    required BackendReachabilityService reachabilityService,
  })  : _connectivityService = connectivityService,
        _reachabilityService = reachabilityService,
        super(ConnectionModeState.initial()) {
    _start();
  }

  final ConnectivityService _connectivityService;
  final BackendReachabilityService _reachabilityService;
  StreamSubscription<NetworkInterfaceState>? _connectivitySubscription;
  Timer? _timer;

  Future<void> checkNow() async {
    await _evaluateConnectivity(await _connectivityService.currentState());
  }

  Future<void> _start() async {
    _connectivitySubscription =
        _connectivityService.onNetworkChanged.listen(_evaluateConnectivity);
    await checkNow();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => checkNow());
  }

  Future<void> _evaluateConnectivity(NetworkInterfaceState networkState) async {
    if (!networkState.hasNetworkInterface) {
      state = state.copyWith(
        mode: AppConnectionMode.offline,
        hasNetworkInterface: false,
        backendReachable: false,
        connectionTypes: networkState.label,
        consecutiveFailures: state.consecutiveFailures + 1,
        consecutiveSuccesses: 0,
        recentChecks: _appendRecent(false),
        lastCheckedAt: DateTime.now(),
        message: 'No network interface detected. Offline mode active.',
        isChecking: false,
      );
      return;
    }

    state = state.copyWith(
      mode: state.mode == AppConnectionMode.online
          ? AppConnectionMode.online
          : AppConnectionMode.reconnecting,
      hasNetworkInterface: true,
      connectionTypes: networkState.label,
      message: 'Network detected. Checking TrailLink server.',
      isChecking: true,
    );

    final reachable = await _reachabilityService.checkBackendReachable();
    final recent = _appendRecent(reachable);
    final nextSuccesses = reachable ? state.consecutiveSuccesses + 1 : 0;
    final nextFailures = reachable ? 0 : state.consecutiveFailures + 1;
    final nextMode = _decideMode(
      reachable: reachable,
      recentChecks: recent,
      consecutiveSuccesses: nextSuccesses,
      consecutiveFailures: nextFailures,
    );
    state = state.copyWith(
      mode: nextMode,
      backendReachable: reachable,
      consecutiveSuccesses: nextSuccesses,
      consecutiveFailures: nextFailures,
      recentChecks: recent,
      lastCheckedAt: DateTime.now(),
      message: _messageFor(nextMode),
      isChecking: false,
    );

    if (reachable && nextMode == AppConnectionMode.reconnecting) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) return checkNow();
      }));
    }
  }

  AppConnectionMode _decideMode({
    required bool reachable,
    required List<bool> recentChecks,
    required int consecutiveSuccesses,
    required int consecutiveFailures,
  }) {
    if (_isAlternating(recentChecks)) return AppConnectionMode.unstable;
    if (reachable && consecutiveSuccesses >= 2) return AppConnectionMode.online;
    if (!reachable && consecutiveFailures >= 2) {
      return AppConnectionMode.offline;
    }
    return AppConnectionMode.reconnecting;
  }

  String _messageFor(AppConnectionMode mode) {
    return switch (mode) {
      AppConnectionMode.online => 'Connection restored. Syncing pending data.',
      AppConnectionMode.offline =>
        'Offline mode active. Backend features are paused.',
      AppConnectionMode.reconnecting => 'Checking TrailLink server.',
      AppConnectionMode.unstable =>
        'Connection is unstable. Messages may be queued.',
    };
  }

  List<bool> _appendRecent(bool result) {
    final recent = [...state.recentChecks, result];
    return recent.length > 4 ? recent.sublist(recent.length - 4) : recent;
  }

  bool _isAlternating(List<bool> checks) {
    if (checks.length < 4) return false;
    for (var i = 1; i < checks.length; i++) {
      if (checks[i] == checks[i - 1]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
