import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14Q nearby, navigation, membership, and wording cleanup', () {
    test('bottom nav removes Connect and keeps Home Messages Map SOS', () {
      final source =
          File('lib/shared/widgets/trail_bottom_nav.dart').readAsStringSync();
      final scaffold =
          File('lib/shared/widgets/trail_scaffold.dart').readAsStringSync();

      expect(source, contains("label: 'Home'"));
      expect(source, contains("label: 'Messages'"));
      expect(source, contains("label: 'Map'"));
      expect(source, contains("label: 'SOS'"));
      expect(source, isNot(contains("label: 'Connect'")));
      expect(source, isNot(contains("context.go('/nearby-peers')")));
      expect(source, contains('const SizedBox(width: 64)'));
      expect(scaffold, contains('_bottomNavMode(modeState, activeTrip)'));
      expect(
        scaffold,
        contains("if (activeTrip?.mode == 'offline') return UserMode.offline"),
      );
    });

    test('nearby peers collapse duplicate endpoints by phone identity', () {
      final model =
          File('lib/features/nearby/data/models/nearby_peer_model.dart')
              .readAsStringSync();
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();

      expect(model, contains('String get identityKey'));
      expect(model, contains('bool hasSamePhoneIdentity'));
      expect(
          model, contains('static List<NearbyPeerModel> collapseDuplicates'));
      expect(controller, contains('NearbyPeerModel.collapseDuplicates'));
      expect(controller, contains('hasSamePhoneIdentity'));
    });

    test('lost or old phone rows are reconnectable with plain wording', () {
      final status =
          File('lib/features/nearby/data/models/nearby_connection_status.dart')
              .readAsStringSync();
      final card =
          File('lib/features/nearby/presentation/widgets/peer_card.dart')
              .readAsStringSync();

      expect(status, contains("return 'Available'"));
      expect(status, contains("return 'Recently seen'"));
      expect(card, contains('Reconnect phone'));
      expect(card, contains('PeerConnectionStatus.lost'));
      expect(card, isNot(contains('Find phone again')));
      expect(card, isNot(contains("'Connect'")));
    });

    test('trip setup uses plain trip type wording and no join trip name', () {
      final wizard =
          File('lib/features/trip/presentation/trip_setup_wizard_screen.dart')
              .readAsStringSync();
      final setup =
          File('lib/features/trip/presentation/trip_setup_screen.dart')
              .readAsStringSync();

      expect(wizard, contains("title: 'Online trip'"));
      expect(wizard, contains('Use internet chat now'));
      expect(wizard, contains('nearby-phone support ready'));
      expect(wizard, contains('Offline trip'));
      expect(
          wizard,
          contains(
              'Trip name from the owner will appear after phones connect'));
      expect(wizard, isNot(contains('Cloud + Offline Backup')));
      expect(wizard, isNot(contains('Offline Only')));
      expect(wizard, isNot(contains('Offline backup')));
      expect(
          setup,
          contains(
              'Trip name from the owner will appear after phones connect'));
      expect(setup, isNot(contains('Offline backup prepared')));
    });

    test('dashboard chooses tools from active trip mode before network mode',
        () {
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();

      expect(dashboard, contains('_dashboardKind(modeState, trip)'));
      expect(dashboard, contains("if (trip.mode == 'offline')"));
      expect(dashboard, contains("'Online Tools'"));
      expect(dashboard, isNot(contains("'Cloud Tools'")));
      expect(dashboard, contains("label: const Text('Join Trip')"));
      expect(
        dashboard,
        contains(
          "AuthAccessState.authenticatedOnline => 'Internet account ready'",
        ),
      );
      expect(dashboard, contains("'Online Chat'"));
    });

    test('dashboard status labels follow active trip mode before network mode',
        () {
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();

      expect(dashboard, contains('_dashboardModeChipLabel(modeState, trip)'));
      expect(dashboard, contains('_dashboardModeColor(modeState, trip)'));
      expect(dashboard, contains('_dashboardModeIcon(modeState, trip)'));
      expect(dashboard, contains('_updatesStatusLabel(modeState, trip)'));
      expect(dashboard, contains("_tripModeOverride(TripSessionModel? trip)"));
      expect(
        dashboard,
        contains("if (trip?.mode == 'offline') return UserMode.offline"),
      );
      expect(
        dashboard,
        contains("if (trip?.mode == 'offline') return 'Saved on this phone'"),
      );
    });

    test('single-channel trip flow hides extra channel creation', () {
      final management = File(
              'lib/features/trip_context/presentation/trip_management_screen.dart')
          .readAsStringSync();
      final service =
          File('lib/features/trip_context/data/trip_context_service.dart')
              .readAsStringSync();

      expect(management, isNot(contains('Add channel')));
      expect(management, isNot(contains('_showCreateChannelDialog')));
      expect(service, contains('Trips use one primary channel in this build.'));
      expect(service, contains('createChannelUnderTrip'));
    });

    test('member list marks you, owner, and owner-only remove action', () {
      final details = File(
              'lib/features/offline_channel/presentation/offline_channel_details_screen.dart')
          .readAsStringSync();
      final tile = File(
              'lib/features/offline_channel/presentation/widgets/local_member_tile.dart')
          .readAsStringSync();
      final repository = File(
              'lib/features/offline_channel/data/offline_channel_repository.dart')
          .readAsStringSync();

      expect(details, contains('currentUserId'));
      expect(details, contains('onRemoveMember'));
      expect(tile, contains("'You'"));
      expect(tile, contains("'Owner'"));
      expect(tile, contains('Remove member'));
      expect(repository, contains('removeMember'));
      expect(repository, contains("packetType: 'member_removed'"));
    });

    test('offline peer hello can update temporary joined trip name', () {
      final transport =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();
      final payload = File(
              'lib/features/nearby/data/models/nearby_advertisement_payload.dart')
          .readAsStringSync();
      final router = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();
      final repository = File(
              'lib/features/offline_channel/data/offline_channel_repository.dart')
          .readAsStringSync();

      expect(transport, contains("'tripName': payload.tripName"));
      expect(payload, contains("'ownerLocalId': ownerLocalId"));
      expect(payload, contains("'memberRole': memberRole"));
      expect(router, contains("case 'peer_hello':"));
      expect(repository, contains('handlePeerHelloPacket'));
      expect(repository, contains('syncTripNameFromPeerHello'));
    });

    test('advertiser receive path promotes packet sender to connected peer',
        () {
      final transport =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();

      expect(transport, contains('_rememberConnectedPeerFromPacket'));
      expect(transport, contains('rx_peer_promoted'));
      expect(transport, contains('PeerConnectionStatus.connected'));
      expect(transport, contains("fallback: data['senderLocalId']"));
      expect(transport, contains("fallback: data['senderName']"));
      expect(transport, contains("packetChannelCode != channelCode"));
    });

    test('connect phones reconciles stale rows before showing connection state',
        () {
      final repository = File('lib/features/nearby/data/nearby_repository.dart')
          .readAsStringSync();
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();

      expect(repository, contains('Future<List<NearbyPeerModel>> getPeers'));
      expect(repository, contains('_transport.connectedPeersForChannel'));
      expect(repository, contains('liveEndpointIds'));
      expect(repository, contains('PeerConnectionStatus.connected'));
      expect(repository, contains('PeerConnectionStatus.lost'));
      expect(
          controller, contains('await _p2pSessionService.cleanupStalePeers'));
    });

    test('connect phones restores active visible and finding state on refresh',
        () {
      final transport =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();
      final interface =
          File('lib/features/nearby/data/nearby_packet_transport.dart')
              .readAsStringSync();
      final repository = File('lib/features/nearby/data/nearby_repository.dart')
          .readAsStringSync();
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();

      expect(interface, contains('bool get isAdvertising'));
      expect(interface, contains('bool get isDiscovering'));
      expect(transport, contains('bool _isAdvertising = false'));
      expect(transport, contains('bool _isDiscovering = false'));
      expect(repository, contains('bool get isAdvertising'));
      expect(repository, contains('bool get isDiscovering'));
      expect(controller, contains('isAdvertising: _repository.isAdvertising'));
      expect(controller, contains('isDiscovering: _repository.isDiscovering'));
    });

    test('reconnect on an old phone row sends a connection request', () {
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();

      expect(
          controller, contains('final target = _peerByEndpoint(endpointId)'));
      expect(
        controller,
        contains('target?.status == PeerConnectionStatus.connected'),
      );
      expect(
        controller,
        contains('target?.status == PeerConnectionStatus.connecting'),
      );
      final connectStart =
          controller.indexOf('Future<void> connectToPeer(String endpointId)');
      final disconnectStart =
          controller.indexOf('Future<void> disconnectFromPeer');
      final connectBlock = controller.substring(connectStart, disconnectStart);
      expect(
          connectBlock,
          contains(
              '_setPeerStatus(endpointId, PeerConnectionStatus.connecting)'));
      expect(connectBlock,
          contains('() => _repository.connectToPeer(endpointId)'));
      expect(connectBlock,
          isNot(contains('target.status != PeerConnectionStatus.discovered')));
    });

    test('rediscovered stale endpoint is revived as available', () {
      final transport =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();

      expect(transport, contains('final status = switch (existing?.status)'));
      expect(transport, contains('PeerConnectionStatus.connected'));
      expect(transport, contains('PeerConnectionStatus.connecting'));
      expect(transport, contains('fallbackStatus'));
      expect(
        transport,
        isNot(contains('status: existing?.status ?? fallbackStatus')),
      );
    });

    test('connect phones status chip trusts live current-channel peer count',
        () {
      final screen =
          File('lib/features/nearby/presentation/nearby_peers_screen.dart')
              .readAsStringSync();

      expect(screen, contains('final label = connectedCount > 0'));
      expect(screen, contains("'Connected to current trip'"));
      expect(
        screen,
        contains(
            'connectedCount > 0 || session?.state == P2PSessionState.connected'),
      );
    });
  });
}
