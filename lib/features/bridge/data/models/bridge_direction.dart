enum BridgeDirection {
  onlineToOffline,
  offlineToOnline,
}

extension BridgeDirectionX on BridgeDirection {
  String get value {
    return switch (this) {
      BridgeDirection.onlineToOffline => 'online_to_offline',
      BridgeDirection.offlineToOnline => 'offline_to_online',
    };
  }
}
