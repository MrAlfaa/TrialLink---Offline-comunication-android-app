import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14P nearby refresh, safety tools, and navigation', () {
    test('Nearby live events allow offline same-channel phones immediately',
        () {
      final source =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();
      final validation =
          File('lib/features/nearby/data/peer_validation_service.dart')
              .readAsStringSync();
      final screen =
          File('lib/features/nearby/presentation/nearby_peers_screen.dart')
              .readAsStringSync();

      expect(source, contains('Future<bool> _allowUnknownSameChannel'));
      expect(source, contains("peer_validation_policy_"));
      expect(source, contains('allowUnknownSameChannel: allowUnknown'));
      expect(source, contains('await refreshPeers()'));
      expect(validation, contains('final hasTripMismatch'));
      expect(
        validation,
        contains('if (hasTripMismatch && !allowUnknownSameChannel)'),
      );
      expect(screen, contains("'Make my phone visible'"));
      expect(screen, contains("'Find nearby phones'"));
      expect(screen, isNot(contains('Start Advertising')));
      expect(screen, isNot(contains('Start Discovery')));
    });

    test('bottom nav is stable across online and offline modes', () {
      final source =
          File('lib/shared/widgets/trail_bottom_nav.dart').readAsStringSync();

      expect(source, contains("label: 'Home'"));
      expect(source, contains("label: 'Messages'"));
      expect(source, contains("label: 'Map'"));
      expect(source, contains("label: 'SOS'"));
      expect(source, isNot(contains("label: 'Connect'")));
      expect(source, isNot(contains("context.go('/nearby-peers')")));
      expect(source, isNot(contains('offlineTextOnly')));
      expect(source, isNot(contains("label: 'Channels'")));
    });

    test('offline safety routes open real screens instead of disabled pages',
        () {
      final router = File('lib/app/router.dart').readAsStringSync();
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();

      expect(router, contains('SosScreen('));
      expect(router, contains('MapScreen('));
      expect(router, contains('PttScreen('));
      expect(router, contains('offlineChannelId:'));
      expect(router, isNot(contains('_offlineTextOnlyActive(ref)')));
      expect(router, isNot(contains('OfflineFeatureDisabledScreen')));
      expect(dashboard, contains("'Send SOS'"));
      expect(dashboard, contains("'Share location'"));
      expect(dashboard, contains("'Talk'"));
      expect(dashboard, isNot(contains('OfflineTextOnlyFlags.enabled')));
    });

    test('map and SOS screens refresh from offline router notices', () {
      final map = File('lib/features/location/presentation/map_screen.dart')
          .readAsStringSync();
      final sos = File('lib/features/emergency/presentation/sos_screen.dart')
          .readAsStringSync();

      expect(map, contains('offlinePacketRouterProvider'));
      expect(map, contains('Location update received.'));
      expect(map, contains('controller.refresh()'));
      expect(sos, contains('offlinePacketRouterProvider'));
      expect(sos, contains('Emergency alert received.'));
      expect(sos, contains('Emergency alert acknowledged.'));
      expect(sos, contains('controller.refresh()'));
    });

    test('user-facing wording avoids technical connection terms', () {
      final nearby =
          File('lib/features/nearby/presentation/nearby_peers_screen.dart')
              .readAsStringSync();
      final controller =
          File('lib/features/nearby/presentation/nearby_controller.dart')
              .readAsStringSync();
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();

      expect(nearby, contains('Connect Phones'));
      expect(nearby, contains('Make my phone visible'));
      expect(nearby, contains('Find nearby phones'));
      expect(nearby, isNot(contains('Nearby Peers')));
      expect(nearby, isNot(contains('P2P session')));
      expect(controller, isNot(contains('Advertising started.')));
      expect(controller, isNot(contains('Discovery started.')));
      expect(dashboard, isNot(contains('fallback')));
    });
  });
}
