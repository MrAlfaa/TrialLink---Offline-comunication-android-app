import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/p2p_session/data/models/p2p_peer_connection_model.dart';
import 'package:traillink/features/p2p_session/data/models/p2p_session_model.dart';
import 'package:traillink/features/p2p_session/data/models/p2p_session_state.dart';

void main() {
  group('Phase 14I P2P session lifecycle', () {
    test('SQLite declares active P2P session and peer tables', () {
      final source =
          File('lib/core/database/local_database.dart').readAsStringSync();

      expect(source, contains('version: 24'));
      expect(source, contains('_createPhaseTwentyOneTables'));
      expect(source,
          contains('CREATE TABLE IF NOT EXISTS p2p_connection_sessions'));
      expect(source, contains('session_id TEXT NOT NULL UNIQUE'));
      expect(source, contains('trip_id TEXT NOT NULL'));
      expect(source, contains('channel_id TEXT NOT NULL'));
      expect(source, contains('channel_code TEXT NOT NULL'));
      expect(source, contains('is_active INTEGER NOT NULL DEFAULT 0'));
      expect(
          source, contains('CREATE TABLE IF NOT EXISTS p2p_connected_peers'));
      expect(source, contains('connection_state TEXT NOT NULL'));
      expect(source, contains('idx_p2p_sessions_active'));
    });

    test('P2P session models preserve switch-blocking and stale state', () {
      final session = P2PSessionModel.fromDb({
        'session_id': 'session-1',
        'trip_id': 'trip-a',
        'channel_id': 'channel-a',
        'channel_code': 'TL-OFF-A',
        'local_user_id': 'local-a',
        'state': 'connected',
        'started_at': '2026-05-18T10:00:00.000',
        'last_activity_at': '2026-05-18T10:01:00.000',
        'is_active': 1,
      });
      expect(session.blocksTripSwitch, isTrue);
      expect(session.toDbMap()['state'], 'connected');

      final peer = P2PPeerConnectionModel.fromDb({
        'session_id': 'session-1',
        'trip_id': 'trip-a',
        'channel_id': 'channel-a',
        'channel_code': 'TL-OFF-A',
        'endpoint_id': 'endpoint-a',
        'peer_local_id': 'local-b',
        'peer_display_name': 'Device B',
        'connection_state': 'stale',
        'created_at': '2026-05-18T10:00:00.000',
      });
      expect(peer.connectionState, P2PPeerConnectionState.stale);
      expect(peer.toDbMap()['connection_state'], 'stale');
    });

    test('service and guard expose canonical lifecycle operations', () {
      final service = File(
        'lib/features/p2p_session/data/p2p_session_service.dart',
      ).readAsStringSync();
      final guard = File(
        'lib/features/p2p_session/data/p2p_session_guard.dart',
      ).readAsStringSync();
      final disconnect = File(
        'lib/features/p2p_session/data/p2p_disconnect_service.dart',
      ).readAsStringSync();

      expect(service, contains('Future<P2PSessionModel?> getActiveSession()'));
      expect(service, contains('Future<bool> hasActiveConnectedSession()'));
      expect(service, contains('Future<P2PSessionModel> startSessionForTrip'));
      expect(service, contains('Future<void> stopActiveSession'));
      expect(service, contains('Future<void> disconnectAllPeers'));
      expect(service, contains('Future<void> markPeerConnected'));
      expect(service, contains('Future<void> updateHeartbeat'));
      expect(service, contains('Future<void> cleanupStalePeers'));
      expect(service, contains('stale_peer_cleanup'));
      expect(service, contains('P2PPeerConnectionState.connected'));
      expect(guard, contains('Future<TripSwitchDecision> canSwitchToTrip'));
      expect(guard, contains('Future<bool> requireDisconnectBeforeSwitch'));
      expect(guard, contains('Future<void> disconnectAndSwitchTrip'));
      expect(guard, contains('onSessionChanged'));
      expect(guard, contains('activeP2PSessionProvider'));
      expect(guard, contains('activeP2PPeersProvider'));
      expect(disconnect, contains("packetType: 'trip_session_leave'"));
      expect(disconnect, contains('nearbyRepository.disconnectAllPeers'));
      expect(disconnect, contains('finally'));
      expect(disconnect, contains('disconnectAllPeers(reason: reason)'));
    });

    test('Nearby lifecycle starts sessions and records peer state', () {
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();
      final screen =
          File('lib/features/nearby/presentation/nearby_peers_screen.dart')
              .readAsStringSync();
      final transport =
          File('lib/features/nearby/data/nearby_packet_transport.dart')
              .readAsStringSync();

      expect(controller, contains('required this.tripId'));
      expect(controller, contains('p2pSessionService'));
      expect(controller, contains('startSessionForTrip'));
      expect(controller, contains('markPeerFromNearby'));
      expect(controller, contains('markPeerLost'));
      expect(screen, contains('Connected to another trip'));
      expect(screen, contains('Disconnect & Switch'));
      expect(screen, contains('activeP2PSessionProvider'));
      expect(transport, contains('Future<void> disconnectAllPeers()'));
    });

    test('trip and channel switch flows show validation dialog', () {
      final dialog = File(
        'lib/features/p2p_session/presentation/p2p_session_switch_dialog.dart',
      ).readAsStringSync();
      final tripSetup =
          File('lib/features/trip/presentation/trip_setup_screen.dart')
              .readAsStringSync();
      final wizard =
          File('lib/features/trip/presentation/trip_setup_wizard_screen.dart')
              .readAsStringSync();
      final join = File(
        'lib/features/offline_channel/presentation/join_offline_channel_screen.dart',
      ).readAsStringSync();
      final details = File(
        'lib/features/offline_channel/presentation/offline_channel_details_screen.dart',
      ).readAsStringSync();
      final trips = File(
        'lib/features/trip_context/presentation/trip_management_screen.dart',
      ).readAsStringSync();

      expect(dialog, contains('Disconnect current trip?'));
      expect(dialog, contains('Disconnect & Switch'));
      expect(dialog, contains('Create as Inactive'));
      expect(tripSetup, contains('showP2PSessionSwitchDialog'));
      expect(wizard, contains('showP2PSessionSwitchDialog'));
      expect(join, contains('joinChannelAsInactive'));
      expect(details, contains('allowCreateInactive: false'));
      expect(trips, contains('disconnectActiveSession'));
    });

    test('trip_session_leave and heartbeat update app-level session state', () {
      final router = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();

      expect(router, contains("packet.packetType == 'trip_session_leave'"));
      expect(router, contains('_handleTripSessionLeave'));
      expect(router, contains('markPeerDisconnectedByLocalId'));
      expect(router, contains('updateHeartbeat'));
      expect(router, contains('p2pSessionServiceProvider'));
    });
  });
}
