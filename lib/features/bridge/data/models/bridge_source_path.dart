enum BridgeSourcePath {
  online,
  offline,
  bridge,
}

extension BridgeSourcePathX on BridgeSourcePath {
  String get value => name;
}
