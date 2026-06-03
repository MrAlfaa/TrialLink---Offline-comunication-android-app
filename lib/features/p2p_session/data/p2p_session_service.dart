import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/identity/local_identity_repository.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/p2p_peer_connection_model.dart';
import 'models/p2p_session_model.dart';
import 'models/p2p_session_state.dart';
import 'p2p_session_repository.dart';

final p2pSessionServiceProvider = Provider<P2PSessionService>((ref) {
  return P2PSessionService(
    repository: ref.read(p2pSessionRepositoryProvider),
    identityRepository: ref.read(localIdentityRepositoryProvider),
  );
});

final activeP2PSessionProvider = FutureProvider<P2PSessionModel?>((ref) async {
  final service = ref.read(p2pSessionServiceProvider);
  await service.cleanupStalePeers();
  return service.getActiveSession();
});

final activeP2PPeersProvider =
    FutureProvider<List<P2PPeerConnectionModel>>((ref) async {
  final service = ref.read(p2pSessionServiceProvider);
  await service.cleanupStalePeers();
  return service.getActiveSessionPeers();
});

class P2PSessionService {
  P2PSessionService({
    required P2PSessionRepository repository,
    required LocalIdentityRepository identityRepository,
    Uuid? uuid,
  })  : _repository = repository,
        _identityRepository = identityRepository,
        _uuid = uuid ?? const Uuid();

  final P2PSessionRepository _repository;
  final LocalIdentityRepository _identityRepository;
  final Uuid _uuid;

  Future<P2PSessionModel?> getActiveSession() {
    return _repository.getActiveSession();
  }

  Future<List<P2PPeerConnectionModel>> getActiveSessionPeers() {
    return _repository.getActiveSessionPeers();
  }

  Future<bool> hasActiveConnectedSession() async {
    final session = await getActiveSession();
    return session?.blocksTripSwitch == true;
  }

  Future<P2PSessionModel> startSessionForTrip({
    required String tripId,
    required String channelId,
    required String channelCode,
    P2PSessionState state = P2PSessionState.idle,
  }) async {
    final identity = await _identityRepository.getCurrentIdentity();
    if (identity == null) {
      throw StateError('Create your TrailLink profile before using Nearby.');
    }
    final existing = await _repository.getActiveSession();
    final sameContext = existing != null &&
        existing.tripId == tripId &&
        existing.channelId == channelId &&
        existing.channelCode == channelCode;
    return _repository.upsertActiveSession(
      sessionId: sameContext ? existing.sessionId : _uuid.v4(),
      tripId: tripId,
      channelId: channelId,
      channelCode: channelCode,
      localUserId: identity.localUserId,
      state: state,
    );
  }

  Future<void> stopActiveSession({String reason = 'manual_disconnect'}) async {
    final session = await _repository.getActiveSession();
    if (session == null) return;
    await _repository.updateActiveSessionState(
      P2PSessionState.disconnected,
      errorMessage: reason,
      endSession: true,
    );
    await _repository.markAllPeers(
      session.sessionId,
      P2PPeerConnectionState.disconnected,
    );
  }

  Future<void> disconnectPeer(String endpointId) {
    return _repository.updatePeerState(
      endpointId,
      P2PPeerConnectionState.disconnected,
    );
  }

  Future<void> disconnectAllPeers({String reason = 'manual_disconnect'}) async {
    final session = await _repository.getActiveSession();
    if (session == null) return;
    await _repository.markAllPeers(
      session.sessionId,
      P2PPeerConnectionState.disconnected,
    );
    await _repository.updateActiveSessionState(
      P2PSessionState.disconnected,
      errorMessage: reason,
      endSession: true,
    );
  }

  Future<void> markPeerConnected(NearbyPeerModel peer) async {
    await _markPeer(peer, P2PPeerConnectionState.connected);
    await _repository.updateActiveSessionState(P2PSessionState.connected);
  }

  Future<void> markPeerConnecting(NearbyPeerModel peer) async {
    await _markPeer(peer, P2PPeerConnectionState.connecting);
    await _repository.updateActiveSessionState(P2PSessionState.connecting);
  }

  Future<void> markPeerDiscovered(NearbyPeerModel peer) {
    return _markPeer(peer, P2PPeerConnectionState.discovered);
  }

  Future<void> markPeerDisconnected(String endpointId) async {
    await _repository.updatePeerState(
      endpointId,
      P2PPeerConnectionState.disconnected,
    );
  }

  Future<void> markPeerDisconnectedByLocalId(String peerLocalId) async {
    await _repository.updatePeerStateByLocalId(
      peerLocalId,
      P2PPeerConnectionState.disconnected,
    );
  }

  Future<void> markPeerLost(String endpointId) async {
    await _repository.updatePeerState(endpointId, P2PPeerConnectionState.lost);
  }

  Future<void> updateHeartbeat({
    required String peerLocalId,
    required String peerDisplayName,
    required String channelId,
    required String channelCode,
  }) async {
    final session = await _repository.getActiveSession();
    if (session == null || session.channelCode != channelCode) return;
    await _repository.upsertPeer(
      session: session,
      peerLocalId: peerLocalId,
      peerDisplayName: peerDisplayName,
      state: P2PPeerConnectionState.connected,
      heartbeat: true,
    );
  }

  Future<void> cleanupStalePeers() async {
    await _repository.cleanupStalePeers();
    final session = await _repository.getActiveSession();
    if (session == null || session.state != P2PSessionState.connected) {
      return;
    }
    final peers = await _repository.getPeersForSession(session.sessionId);
    final hasConnectedPeer = peers.any(
      (peer) => peer.connectionState == P2PPeerConnectionState.connected,
    );
    if (hasConnectedPeer) return;
    await _repository.updateActiveSessionState(
      P2PSessionState.disconnected,
      errorMessage: 'stale_peer_cleanup',
      endSession: true,
    );
  }

  Future<void> _markPeer(
    NearbyPeerModel peer,
    P2PPeerConnectionState state,
  ) async {
    final session = await _repository.getActiveSession();
    if (session == null || session.channelCode != peer.activeChannelCode) {
      return;
    }
    await _repository.upsertPeer(
      session: session,
      endpointId: peer.endpointId,
      peerLocalId: peer.userId,
      peerDisplayName: peer.displayName,
      state: state,
      heartbeat: state == P2PPeerConnectionState.connected,
    );
  }

  Future<void> markPeerFromNearby(NearbyPeerModel peer) {
    switch (peer.status) {
      case PeerConnectionStatus.discovered:
        return markPeerDiscovered(peer);
      case PeerConnectionStatus.connecting:
        return markPeerConnecting(peer);
      case PeerConnectionStatus.connected:
        return markPeerConnected(peer);
      case PeerConnectionStatus.disconnected:
        return markPeerDisconnected(peer.endpointId);
      case PeerConnectionStatus.lost:
        return markPeerLost(peer.endpointId);
      case PeerConnectionStatus.failed:
        return _markPeer(peer, P2PPeerConnectionState.failed);
    }
  }
}
