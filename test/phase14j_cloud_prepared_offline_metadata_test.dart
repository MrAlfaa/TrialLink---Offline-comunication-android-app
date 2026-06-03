import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14J cloud-prepared offline metadata', () {
    test('backend exposes cloud-prepared trip metadata endpoints', () {
      final routes = File(
        'backend/src/modules/tripContext/tripContext.routes.js',
      ).readAsStringSync();
      final service = File(
        'backend/src/modules/tripContext/tripContext.service.js',
      ).readAsStringSync();
      final model = File('backend/src/models/memberDeviceProfile.model.js')
          .readAsStringSync();
      final package = File('backend/package.json').readAsStringSync();

      expect(routes, contains("router.post('/cloud-prepared-trips'"));
      expect(routes, contains("router.post('/cloud-prepared-trips/join'"));
      expect(routes,
          contains("router.get('/cloud-prepared-trips/:tripId/metadata'"));
      expect(service, contains('createCloudPreparedTrip'));
      expect(service, contains('joinCloudPreparedTrip'));
      expect(service, contains('getCloudPreparedTripMetadata'));
      expect(model, contains('appDeviceId'));
      expect(model, contains('publicUserId'));
      expect(model, contains('capabilities'));
      expect(model, isNot(contains('bluetoothMac')));
      expect(package, contains('test:phase14j'));
    });

    test('backend channel key hash uses central secret without weak fallback',
        () {
      final service = File(
        'backend/src/modules/tripContext/tripContext.service.js',
      ).readAsStringSync();
      final env = File('backend/src/config/env.js').readAsStringSync();
      final backendReadme = File('backend/README.md').readAsStringSync();

      expect(service, contains("require('../../config/env')"));
      expect(
          service, contains("crypto\n  .createHmac('sha256', env.jwtSecret)"));
      expect(service, isNot(contains("process.env.JWT_SECRET || 'traillink'")));
      expect(service, isNot(contains("createHash('sha256')")));
      expect(
        env,
        contains(
          "JWT_SECRET must be set to a long, non-placeholder secret in production.",
        ),
      );
      expect(env, contains('placeholderSecrets'));
      expect(env, contains('traillink-development-only-secret-change-me'));
      expect(env, contains("path.resolve(__dirname, '../../.env')"));
      expect(backendReadme, contains('refuses to start'));
    });

    test('SQLite v22 stores offline backup and cached device roster metadata',
        () {
      final source =
          File('lib/core/database/local_database.dart').readAsStringSync();

      expect(source, contains('version: 24'));
      expect(source, contains('_createPhaseTwentyTwoTables'));
      expect(source, contains('offline_backup_ready'));
      expect(source, contains('cloud_prepared_at'));
      expect(source, contains('primary_channel_id'));
      expect(source, contains('cloud_trip_member_devices'));
      expect(source, contains('app_device_id TEXT'));
      expect(source, contains('capabilities_json TEXT'));
      expect(source, contains('verification_status'));
    });

    test('Flutter repository caches cloud-prepared metadata locally', () {
      final repository = File(
        'lib/features/trip_context/data/cloud_prepared_trip_repository.dart',
      ).readAsStringSync();
      final api = File(
        'lib/features/trip_context/data/cloud_prepared_trip_api.dart',
      ).readAsStringSync();
      final roster = File(
        'lib/features/trip_context/data/trip_member_device_roster_repository.dart',
      ).readAsStringSync();

      expect(repository, contains('createCloudPreparedTrip'));
      expect(repository, contains('joinCloudPreparedTrip'));
      expect(repository, contains('refreshCloudPreparedMetadata'));
      expect(repository, contains('_cacheMetadata'));
      expect(api, contains('/trip-context/cloud-prepared-trips'));
      expect(api, contains('/trip-context/cloud-prepared-trips/join'));
      expect(roster, contains('findMatchingDevice'));
      expect(roster, contains('cloud_trip_member_devices'));
    });

    test('Nearby TL3 advertisement and peer validation avoid raw MAC identity',
        () {
      final advertisement = File(
        'lib/features/nearby/data/models/nearby_advertisement_payload.dart',
      ).readAsStringSync();
      final peer = File(
        'lib/features/nearby/data/models/nearby_peer_model.dart',
      ).readAsStringSync();
      final validation = File(
        'lib/features/nearby/data/peer_validation_service.dart',
      ).readAsStringSync();
      final transport = File(
        'lib/features/nearby/data/nearby_connections_transport.dart',
      ).readAsStringSync();

      expect(advertisement, contains("value.startsWith('TL3|'"));
      expect(advertisement, contains('tripId'));
      expect(advertisement, contains('publicUserId'));
      expect(advertisement, contains('appDeviceId'));
      expect(advertisement, contains('capabilities'));
      expect(advertisement, isNot(contains('bluetoothMac')));
      expect(peer, contains('verificationStatus'));
      expect(validation, contains('PeerValidationResult.verifiedMember'));
      expect(validation, contains('PeerValidationResult.unknownSameChannel'));
      expect(validation, contains('PeerValidationResult.mismatch'));
      expect(transport, contains("'packetType': 'peer_hello'"));
    });

    test('online trip flows use cloud-prepared metadata service', () {
      final wizard = File(
        'lib/features/trip/presentation/trip_setup_wizard_screen.dart',
      ).readAsStringSync();
      final setup =
          File('lib/features/trip/presentation/trip_setup_screen.dart')
              .readAsStringSync();
      final createGroup =
          File('lib/features/groups/presentation/create_group_screen.dart')
              .readAsStringSync();
      final details = File(
        'lib/features/trip_context/presentation/trip_management_screen.dart',
      ).readAsStringSync();

      expect(wizard, contains('cloudPreparedTripRepositoryProvider'));
      expect(setup, contains('cloudPreparedTripRepositoryProvider'));
      expect(createGroup, contains('createCloudPreparedTrip'));
      expect(details, contains('Nearby support ready'));
      expect(details, contains('Members saved'));
      expect(details, contains('Phones saved'));
    });
  });
}
