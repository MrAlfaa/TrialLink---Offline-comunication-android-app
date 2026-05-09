import '../mode/mode_models.dart';
import 'app_connection_mode.dart';

enum SendPath {
  backendSocket,
  backendRest,
  offlineNearby,
  localQueueOnly,
  hybridQueue,
}

class SendPathDecider {
  const SendPathDecider._();

  static SendPath decide(AppConnectionMode mode) {
    return mode == AppConnectionMode.online
        ? SendPath.backendSocket
        : SendPath.localQueueOnly;
  }

  static SendPath decideForMode({
    required ModeState modeState,
    bool socketConnected = false,
    bool hasOfflineContext = false,
    bool hasConnectedPeers = false,
  }) {
    return decideForEffectiveMode(
      effectiveMode: modeState.effectiveMode,
      backendReachable: modeState.backendReachable,
      socketConnected: socketConnected || modeState.socketConnected,
      hasOfflineContext: hasOfflineContext,
      hasConnectedPeers: hasConnectedPeers || modeState.connectedPeerCount > 0,
    );
  }

  static SendPath decideForEffectiveMode({
    required EffectiveMode effectiveMode,
    required bool backendReachable,
    required bool socketConnected,
    required bool hasOfflineContext,
    required bool hasConnectedPeers,
  }) {
    return switch (effectiveMode) {
      EffectiveMode.online => backendReachable
          ? socketConnected
              ? SendPath.backendSocket
              : SendPath.backendRest
          : SendPath.localQueueOnly,
      EffectiveMode.offline => hasOfflineContext && hasConnectedPeers
          ? SendPath.offlineNearby
          : SendPath.localQueueOnly,
      EffectiveMode.hybridLimited => hasOfflineContext || backendReachable
          ? SendPath.hybridQueue
          : SendPath.localQueueOnly,
    };
  }
}
