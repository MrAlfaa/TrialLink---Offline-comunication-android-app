import 'models/nearby_peer_model.dart';

abstract class NearbyPacketTransport {
  Future<void> startAdvertising({
    required String userId,
    required String displayName,
    required String activeChannelId,
    required String activeChannelCode,
  });

  Future<void> stopAdvertising();

  Future<void> startDiscovery({
    required String activeChannelCode,
  });

  Future<void> stopDiscovery();

  Future<void> connectToPeer(String endpointId);

  Future<void> disconnectFromPeer(String endpointId);

  Future<void> sendPacket({
    required String endpointId,
    required String packetJson,
  });

  bool isConnected(String endpointId);

  List<NearbyPeerModel> connectedPeersForChannel(String channelCode);

  Stream<NearbyPeerModel> get peerDiscoveredStream;

  Stream<String> get peerLostStream;

  Stream<NearbyPeerModel> get peerConnectionChangedStream;

  Stream<String> get packetReceivedStream;

  Future<void> dispose();
}
