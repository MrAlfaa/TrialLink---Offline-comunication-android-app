import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_model.dart';

void main() {
  group('offline channel lifecycle model', () {
    test('maps active inactive and ended fields from SQLite rows', () {
      final endedAt = DateTime.utc(2026, 5, 9, 10, 30);
      final channel = OfflineChannelModel.fromDb({
        'channel_id': 'channel-1',
        'channel_code': 'TL-OFF-8K2P',
        'channel_name': 'Knuckles Hike',
        'description': 'Trip channel',
        'created_by_user_id': 'local_owner',
        'created_by_name': 'Dhananjaya',
        'is_active': 1,
        'channel_status': 'ended',
        'ended_at': endedAt.toIso8601String(),
        'ended_by_user_id': 'local_owner',
        'ended_reason': 'Trip finished',
        'created_at': DateTime.utc(2026, 5, 9).toIso8601String(),
      });

      expect(channel.channelStatus, 'ended');
      expect(channel.isEnded, isTrue);
      expect(channel.isUsable, isFalse);
      expect(channel.endedAt, endedAt);
      expect(channel.endedByUserId, 'local_owner');
      expect(channel.endedReason, 'Trip finished');
      expect(channel.toDbMap()['channel_status'], 'ended');
    });
  });

  group('lifecycle implementation source contracts', () {
    test(
        'offline channels preserve history by marking ended instead of hard delete',
        () {
      final source = File(
              'lib/features/offline_channel/data/offline_channel_repository.dart')
          .readAsStringSync();

      expect(source, contains('endChannel'));
      expect(source, contains('channel_status'));
      expect(source, contains('channel_status_update'));
      expect(
        source,
        isNot(contains(
            "successMessage: 'Offline channel removed from this device.'")),
      );
    });

    test('offline packet router handles channel status update packets', () {
      final source = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();

      expect(source, contains("case 'channel_status_update':"));
      expect(source, contains('This channel was ended by the owner'));
    });

    test('cloud groups expose owner archive API and socket event', () {
      final backendService = File('backend/src/modules/groups/group.service.js')
          .readAsStringSync();
      final backendRoutes =
          File('backend/src/modules/groups/group.routes.js').readAsStringSync();
      final flutterRepository =
          File('lib/features/groups/data/group_repository.dart')
              .readAsStringSync();

      expect(backendService, contains('archiveGroup'));
      expect(backendService, contains("status = 'archived'"));
      expect(backendService, contains('emitGroupArchived'));
      expect(backendRoutes, contains("router.delete('/:groupId'"));
      expect(flutterRepository, contains('archiveGroup'));
    });
  });
}
