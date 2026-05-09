enum PeerConnectionStatus {
  discovered,
  connecting,
  connected,
  disconnected,
  lost,
  failed,
}

extension PeerConnectionStatusX on PeerConnectionStatus {
  String get label {
    switch (this) {
      case PeerConnectionStatus.discovered:
        return 'Discovered';
      case PeerConnectionStatus.connecting:
        return 'Connecting';
      case PeerConnectionStatus.connected:
        return 'Connected';
      case PeerConnectionStatus.disconnected:
        return 'Disconnected';
      case PeerConnectionStatus.lost:
        return 'Lost';
      case PeerConnectionStatus.failed:
        return 'Failed';
    }
  }

  static PeerConnectionStatus fromString(String value) {
    return PeerConnectionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PeerConnectionStatus.discovered,
    );
  }
}
