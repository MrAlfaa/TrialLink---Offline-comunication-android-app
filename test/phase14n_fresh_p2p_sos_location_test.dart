import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14N fresh P2P, SOS, and location reliability contracts', () {
    test('NearbyRepository persists transport peer state outside Nearby screen',
        () {
      final repository = File('lib/features/nearby/data/nearby_repository.dart')
          .readAsStringSync();

      expect(repository, contains('StreamSubscription<dynamic>'));
      expect(repository, contains('peerDiscoveredStream.listen(_persistPeer)'));
      expect(
        repository,
        contains('peerConnectionChangedStream.listen(_persistPeer)'),
      );
      expect(repository, contains('peerLostStream.listen'));
      expect(repository, contains('_local.upsertPeer(peer)'));
    });

    test('packet send failure marks stale endpoint lost before throwing', () {
      final repository = File('lib/features/nearby/data/nearby_repository.dart')
          .readAsStringSync();

      final sendStart = repository.indexOf('Future<void> sendPacket');
      final sendBlock = repository.substring(
        sendStart,
        repository.indexOf('Future<void> dispose', sendStart),
      );

      expect(sendBlock, contains('!_transport.isConnected(endpointId)'));
      expect(sendBlock, contains('await markLost(endpointId)'));
      expect(sendBlock, contains('_transport.sendPacket'));
      expect(sendBlock, contains('catch (error)'));
      expect(sendBlock, contains('Nearby packet send failed'));
    });

    test('Nearby provider disposes repository subscriptions safely', () {
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();

      expect(controller, contains('ref.onDispose(()'));
      expect(controller, contains('unawaited(repository.dispose())'));
      expect(controller, contains('NearbyRepository(transport:'));
    });

    test('heartbeat send failures clear stale peer UI state', () {
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();
      final start = controller.indexOf('Future<void> _sendHeartbeat');
      final block = controller.substring(
        start,
        controller.indexOf('Future<void> _onPeerLost', start),
      );

      expect(block, contains('await _repository.sendPacket'));
      expect(block, contains('await _onPeerLost(peer.endpointId)'));
    });

    test('offline feature senders use the shared NearbyRepository boundary',
        () {
      final nearby = File('lib/features/nearby/data/nearby_repository.dart')
          .readAsStringSync();
      final chat =
          File('lib/features/offline_chat/data/offline_chat_repository.dart')
              .readAsStringSync();
      final ptt =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();
      final sos = File('lib/features/emergency/data/emergency_repository.dart')
          .readAsStringSync();
      final location =
          File('lib/features/location/data/location_repository.dart')
              .readAsStringSync();

      expect(nearby, contains('connectedPeers(String channelCode)'));
      expect(nearby, contains('_transport.connectedPeersForChannel'));
      expect(chat, contains('_nearby.sendPacket'));
      expect(chat, contains('_nearby.connectedPeers(channelCode)'));
      expect(ptt, contains('nearby.sendPacket'));
      expect(ptt, contains('nearby.connectedPeers(channelCode)'));
      expect(sos, contains('_nearby.sendPacket'));
      expect(sos, contains('_nearby.connectedPeers(channel.channelCode)'));
      expect(
          sos, contains('_nearby.connectedPeers(activeChannel.channelCode)'));
      expect(location, contains('_nearby.sendPacket'));
      expect(location, contains('_nearby.connectedPeers(channel.channelCode)'));
    });

    test('Live Radio eligibility uses live Nearby peers before SQLite fallback',
        () {
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();
      final eligibility =
          File('lib/features/ptt/data/live_radio_eligibility_service.dart')
              .readAsStringSync();

      expect(repository, contains('nearby: _nearby'));
      expect(eligibility, contains('NearbyRepository? nearby'));
      expect(eligibility, contains('_nearby.connectedPeers'));
      expect(eligibility, contains('_local.connectedPeers'));
    });
  });
}
