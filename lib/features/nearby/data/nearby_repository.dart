import 'dart:async';

import '../data/models/nearby_connection_status.dart';
import '../data/models/nearby_peer_model.dart';
import 'nearby_local_data_source.dart';
import 'nearby_packet_transport.dart';
import 'nearby_permission_service.dart';

class NearbyRepository {
  NearbyRepository({
    required NearbyPacketTransport transport,
    NearbyLocalDataSource? local,
    NearbyPermissionService? permissions,
  })  : _transport = transport,
        _local = local ?? NearbyLocalDataSource(),
        _permissions = permissions ?? NearbyPermissionService() {
    _subscriptions
      ..add(_transport.peerDiscoveredStream.listen(_persistPeer))
      ..add(_transport.peerConnectionChangedStream.listen(_persistPeer))
      ..add(_transport.peerLostStream.listen((endpointId) {
        unawaited(markLost(endpointId));
      }));
  }

  final NearbyPacketTransport _transport;
  final NearbyLocalDataSource _local;
  final NearbyPermissionService _permissions;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Stream<NearbyPeerModel> get peerDiscoveredStream =>
      _transport.peerDiscoveredStream;
  Stream<NearbyPeerModel> get peerConnectionChangedStream =>
      _transport.peerConnectionChangedStream;
  Stream<String> get peerLostStream => _transport.peerLostStream;
  Stream<String> get packetReceivedStream => _transport.packetReceivedStream;

  Future<NearbyPermissionState> requestPermissions() {
    return _permissions.checkAndRequest();
  }

  Future<List<NearbyPeerModel>> getPeers(String channelCode) {
    return _local.getPeersForChannel(channelCode);
  }

  Future<List<NearbyPeerModel>> connectedPeers(String channelCode) async {
    final stored = await _local.getPeersForChannel(channelCode);
    final live = _transport.connectedPeersForChannel(channelCode);
    final liveEndpointIds = live.map((peer) => peer.endpointId).toSet();
    for (final peer in live) {
      unawaited(_local.upsertPeer(peer));
    }
    for (final peer in stored) {
      if (peer.status == PeerConnectionStatus.connected &&
          !liveEndpointIds.contains(peer.endpointId)) {
        unawaited(markLost(peer.endpointId));
      }
    }
    return live.toList()..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
  }

  Future<void> savePeer(NearbyPeerModel peer) => _local.upsertPeer(peer);

  Future<void> markLost(String endpointId) {
    return _local.updateStatus(endpointId, PeerConnectionStatus.lost);
  }

  Future<void> startAdvertising({
    required String userId,
    required String displayName,
    required String activeChannelId,
    required String activeChannelCode,
  }) {
    return _transport.startAdvertising(
      userId: userId,
      displayName: displayName,
      activeChannelId: activeChannelId,
      activeChannelCode: activeChannelCode,
    );
  }

  Future<void> stopAdvertising() => _transport.stopAdvertising();

  Future<void> startDiscovery(String activeChannelCode) {
    return _transport.startDiscovery(activeChannelCode: activeChannelCode);
  }

  Future<void> stopDiscovery() => _transport.stopDiscovery();

  Future<void> connectToPeer(String endpointId) {
    return _transport.connectToPeer(endpointId);
  }

  Future<void> disconnectFromPeer(String endpointId) {
    return _transport.disconnectFromPeer(endpointId);
  }

  Future<void> sendPacket({
    required String endpointId,
    required String packetJson,
  }) async {
    if (!_transport.isConnected(endpointId)) {
      await markLost(endpointId);
      throw StateError(
        'Nearby endpoint $endpointId is not currently connected.',
      );
    }
    try {
      await _transport.sendPacket(
        endpointId: endpointId,
        packetJson: packetJson,
      );
    } catch (error) {
      await markLost(endpointId);
      throw StateError('Nearby packet send failed: $error');
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  void _persistPeer(NearbyPeerModel peer) {
    unawaited(_local.upsertPeer(peer));
  }
}
