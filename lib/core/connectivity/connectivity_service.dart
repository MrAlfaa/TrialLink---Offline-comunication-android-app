import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInterfaceState {
  const NetworkInterfaceState({
    required this.hasNetworkInterface,
    required this.connectionTypes,
  });

  final bool hasNetworkInterface;
  final List<ConnectivityResult> connectionTypes;

  String get label {
    if (!hasNetworkInterface) return 'none';
    return connectionTypes
        .where((type) => type != ConnectivityResult.none)
        .map((type) => type.name)
        .join(', ');
  }
}

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<NetworkInterfaceState> get onNetworkChanged {
    return _connectivity.onConnectivityChanged.map(_fromResults);
  }

  Future<NetworkInterfaceState> currentState() async {
    return _fromResults(await _connectivity.checkConnectivity());
  }

  NetworkInterfaceState _fromResults(List<ConnectivityResult> results) {
    final hasInterface = results.any((type) => type != ConnectivityResult.none);
    return NetworkInterfaceState(
      hasNetworkInterface: hasInterface,
      connectionTypes: results,
    );
  }
}
