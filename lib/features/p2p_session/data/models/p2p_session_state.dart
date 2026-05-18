enum P2PSessionState {
  idle,
  advertising,
  discovering,
  connecting,
  connected,
  disconnecting,
  disconnected,
  lost,
  failed;

  static P2PSessionState parse(String value) {
    return P2PSessionState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => P2PSessionState.idle,
    );
  }

  bool get blocksTripSwitch {
    return this == P2PSessionState.advertising ||
        this == P2PSessionState.discovering ||
        this == P2PSessionState.connecting ||
        this == P2PSessionState.connected ||
        this == P2PSessionState.disconnecting;
  }
}

enum P2PPeerConnectionState {
  discovered,
  connecting,
  connected,
  stale,
  disconnecting,
  disconnected,
  lost,
  failed;

  static P2PPeerConnectionState parse(String value) {
    return P2PPeerConnectionState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => P2PPeerConnectionState.disconnected,
    );
  }
}

enum TripSwitchDecisionType {
  allowed,
  sameTrip,
  requiresDisconnect,
}

class TripSwitchDecision {
  const TripSwitchDecision({
    required this.type,
    this.currentTripName,
    this.newTripName,
  });

  final TripSwitchDecisionType type;
  final String? currentTripName;
  final String? newTripName;

  bool get canProceed =>
      type == TripSwitchDecisionType.allowed ||
      type == TripSwitchDecisionType.sameTrip;

  bool get requiresDisconnect =>
      type == TripSwitchDecisionType.requiresDisconnect;
}
