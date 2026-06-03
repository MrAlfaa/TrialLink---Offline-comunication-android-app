import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/identity/current_user_actor.dart';
import 'package:traillink/core/offline/offline_relay_service.dart';
import 'package:traillink/features/nearby/data/models/nearby_connection_status.dart';
import 'package:traillink/features/nearby/data/models/nearby_peer_model.dart';
import 'package:traillink/features/nearby/data/nearby_packet_transport.dart';
import 'package:traillink/features/nearby/data/nearby_repository.dart';
import 'package:traillink/features/offline_chat/data/models/offline_packet_model.dart';

void main() {
  group('Phase 15A offline relay contracts', () {
    test('relays SOS to same-channel connected phones except sender', () async {
      final repository = _FakeNearbyRepository([
        _peer(endpointId: 'endpoint-a', userId: 'local-a', name: 'A'),
        _peer(endpointId: 'endpoint-c', userId: 'local-c', name: 'C'),
      ]);
      final service = OfflineRelayService(
        nearbyRepository: repository,
      );

      final result = await service.relayIfNeeded(
        packet: _packet(
          packetType: 'sos',
          senderId: 'local-a',
          senderLocalId: 'local-a',
          ttl: 3,
          hopCount: 0,
        ),
        activeChannelCode: 'TL-OFF-RELAY',
        currentActor: _actor('local-b', 'B'),
      );

      expect(result.action, 'relayed');
      expect(result.sentCount, 1);
      expect(repository.sentPackets, hasLength(1));
      expect(repository.sentPackets.single.endpointId, 'endpoint-c');
      final payload = jsonDecode(repository.sentPackets.single.packetJson)
          as Map<String, dynamic>;
      expect(payload['packetId'], 'packet-1');
      expect(payload['packetType'], 'sos');
      expect(payload['ttl'], 2);
      expect(payload['hopCount'], 1);
    });

    test('relays ACK packets so acknowledgements can return over a bridge',
        () async {
      final repository = _FakeNearbyRepository([
        _peer(endpointId: 'endpoint-a', userId: 'local-a', name: 'A'),
        _peer(endpointId: 'endpoint-c', userId: 'local-c', name: 'C'),
      ]);
      final service = OfflineRelayService(
        nearbyRepository: repository,
      );

      final result = await service.relayIfNeeded(
        packet: _packet(
          packetType: 'ack',
          senderId: 'local-c',
          senderLocalId: 'local-c',
          ttl: 4,
          hopCount: 1,
          payload: {
            'ackForPacketId': 'packet-from-a',
            'ackForMessageId': 'message-from-a',
          },
        ),
        activeChannelCode: 'TL-OFF-RELAY',
        currentActor: _actor('local-b', 'B'),
      );

      expect(result.sentCount, 1);
      expect(repository.sentPackets.single.endpointId, 'endpoint-a');
      final payload = jsonDecode(repository.sentPackets.single.packetJson)
          as Map<String, dynamic>;
      expect(payload['packetType'], 'ack');
      expect(payload['ttl'], 3);
      expect(payload['hopCount'], 2);
    });

    test('does not relay expired or own packets', () async {
      final repository = _FakeNearbyRepository([
        _peer(endpointId: 'endpoint-c', userId: 'local-c', name: 'C'),
      ]);
      final service = OfflineRelayService(
        nearbyRepository: repository,
      );
      final actor = _actor('local-b', 'B');

      final expired = await service.relayIfNeeded(
        packet: _packet(
          packetType: 'location',
          senderId: 'local-a',
          senderLocalId: 'local-a',
          ttl: 1,
        ),
        activeChannelCode: 'TL-OFF-RELAY',
        currentActor: actor,
      );
      final own = await service.relayIfNeeded(
        packet: _packet(
          packetType: 'heartbeat',
          senderId: 'local-b',
          senderLocalId: 'local-b',
          ttl: 3,
        ),
        activeChannelCode: 'TL-OFF-RELAY',
        currentActor: actor,
      );

      expect(expired.action, 'expired');
      expect(own.action, 'own-packet');
      expect(repository.sentPackets, isEmpty);
    });

    test('router wires relay service for SOS, location, ACK, and heartbeat',
        () {
      // Source-level contract keeps relay out of media/live-radio paths.
      const routerSourcePath = 'lib/core/offline/offline_packet_router.dart';
      // This test intentionally reads source text through the package root
      // conventions used by the existing Phase 14 contract tests.
      final source = _readSource(routerSourcePath);
      expect(source, contains('OfflineRelayService'));
      expect(source, contains("case 'location':"));
      expect(source, contains("case 'heartbeat':"));
      expect(source, contains("case 'sos':"));
      expect(source, contains("case 'ack':"));
      expect(
          source, isNot(contains("case 'voice_note':\n        await _relay")));
    });
  });
}

String _readSource(String path) {
  return File(path).readAsStringSync();
}

CurrentUserActor _actor(String localId, String name) {
  return CurrentUserActor(
    id: localId,
    localUserId: localId,
    displayName: name,
    identityType: 'offline',
  );
}

OfflinePacketModel _packet({
  required String packetType,
  required String senderId,
  required String senderLocalId,
  int ttl = 5,
  int hopCount = 0,
  Map<String, dynamic>? payload,
}) {
  return OfflinePacketModel(
    packetId: 'packet-1',
    packetType: packetType,
    channelId: 'channel-1',
    channelCode: 'TL-OFF-RELAY',
    senderId: senderId,
    senderLocalId: senderLocalId,
    senderName: senderId,
    targetType: 'channel',
    targetId: 'channel-1',
    payload: payload ?? {'message': 'QA TEST SOS - NO REAL EMERGENCY'},
    priority: packetType == 'sos' ? 'emergency' : 'normal',
    ttl: ttl,
    hopCount: hopCount,
    requiresAck: packetType != 'heartbeat',
    createdAt: DateTime.utc(2026, 6, 3),
  );
}

NearbyPeerModel _peer({
  required String endpointId,
  required String userId,
  required String name,
}) {
  return NearbyPeerModel(
    endpointId: endpointId,
    userId: userId,
    displayName: name,
    deviceName: '$name phone',
    activeChannelId: 'channel-1',
    activeChannelCode: 'TL-OFF-RELAY',
    status: PeerConnectionStatus.connected,
    discoveredAt: DateTime.utc(2026, 6, 3),
    lastSeenAt: DateTime.utc(2026, 6, 3),
  );
}

class _SentPacket {
  const _SentPacket(this.endpointId, this.packetJson);

  final String endpointId;
  final String packetJson;
}

class _FakeNearbyRepository extends NearbyRepository {
  _FakeNearbyRepository(this._peers)
      : super(transport: _FakeNearbyPacketTransport(const []));

  final List<NearbyPeerModel> _peers;
  final List<_SentPacket> sentPackets = [];

  @override
  Future<List<NearbyPeerModel>> connectedPeers(String channelCode) async {
    return _peers
        .where((peer) =>
            peer.activeChannelCode == channelCode &&
            peer.status == PeerConnectionStatus.connected)
        .toList();
  }

  @override
  Future<void> sendPacket({
    required String endpointId,
    required String packetJson,
  }) async {
    sentPackets.add(_SentPacket(endpointId, packetJson));
  }
}

class _FakeNearbyPacketTransport implements NearbyPacketTransport {
  _FakeNearbyPacketTransport(this._peers);

  final List<NearbyPeerModel> _peers;
  final List<_SentPacket> sentPackets = [];
  final _peerDiscovered = StreamController<NearbyPeerModel>.broadcast();
  final _peerChanged = StreamController<NearbyPeerModel>.broadcast();
  final _peerLost = StreamController<String>.broadcast();
  final _packets = StreamController<String>.broadcast();

  @override
  List<NearbyPeerModel> connectedPeersForChannel(String channelCode) {
    return _peers
        .where((peer) =>
            peer.activeChannelCode == channelCode &&
            peer.status == PeerConnectionStatus.connected)
        .toList();
  }

  @override
  Future<void> sendPacket({
    required String endpointId,
    required String packetJson,
  }) async {
    sentPackets.add(_SentPacket(endpointId, packetJson));
  }

  @override
  bool isConnected(String endpointId) {
    return _peers.any((peer) =>
        peer.endpointId == endpointId &&
        peer.status == PeerConnectionStatus.connected);
  }

  @override
  bool get isAdvertising => false;

  @override
  bool get isDiscovering => false;

  @override
  Stream<NearbyPeerModel> get peerDiscoveredStream => _peerDiscovered.stream;

  @override
  Stream<NearbyPeerModel> get peerConnectionChangedStream =>
      _peerChanged.stream;

  @override
  Stream<String> get peerLostStream => _peerLost.stream;

  @override
  Stream<String> get packetReceivedStream => _packets.stream;

  @override
  Future<void> connectToPeer(String endpointId) async {}

  @override
  Future<void> disconnectAllPeers() async {}

  @override
  Future<void> disconnectFromPeer(String endpointId) async {}

  @override
  Future<void> dispose() async {
    await _peerDiscovered.close();
    await _peerChanged.close();
    await _peerLost.close();
    await _packets.close();
  }

  @override
  Future<void> startAdvertising({
    required String userId,
    required String displayName,
    required String activeChannelId,
    required String activeChannelCode,
    String? tripId,
    String? tripName,
    String? ownerLocalId,
    String? ownerName,
    String memberRole = 'member',
    String? publicUserId,
    String? appDeviceId,
    List<String> capabilities = const ['text'],
  }) async {}

  @override
  Future<void> startDiscovery({required String activeChannelCode}) async {}

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> stopDiscovery() async {}
}
