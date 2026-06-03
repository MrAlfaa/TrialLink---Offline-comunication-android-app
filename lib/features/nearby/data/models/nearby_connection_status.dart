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
        return 'Available';
      case PeerConnectionStatus.connecting:
        return 'Connecting';
      case PeerConnectionStatus.connected:
        return 'Connected';
      case PeerConnectionStatus.disconnected:
        return 'Disconnected';
      case PeerConnectionStatus.lost:
        return 'Recently seen';
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
