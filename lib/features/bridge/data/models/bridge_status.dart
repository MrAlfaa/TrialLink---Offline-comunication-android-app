enum BridgeStatus {
  pending,
  bridged,
  failed,
  duplicateIgnored,
}

extension BridgeStatusX on BridgeStatus {
  String get value {
    return switch (this) {
      BridgeStatus.pending => 'pending',
      BridgeStatus.bridged => 'bridged',
      BridgeStatus.failed => 'failed',
      BridgeStatus.duplicateIgnored => 'duplicate_ignored',
    };
  }
}
