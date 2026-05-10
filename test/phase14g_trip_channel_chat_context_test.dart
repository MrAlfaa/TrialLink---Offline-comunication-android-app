import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/chat/data/models/chat_message_model.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_model.dart';
import 'package:traillink/features/offline_chat/data/models/offline_text_message_model.dart';
import 'package:traillink/features/trip/data/trip_session_model.dart';
import 'package:traillink/features/trip_context/data/models/chat_room_model.dart';

void main() {
  group('Phase 14G Trip -> Channel -> Chat architecture', () {
    test('SQLite v20 migration declares trip context schema and chat ids', () {
      final source =
          File('lib/core/database/local_database.dart').readAsStringSync();

      expect(source, contains('version: 20'));
      expect(source, contains('active_channel_id'));
      expect(source, contains('last_opened_at'));
      expect(source, contains('trip_id'));
      expect(source, contains('is_primary'));
      expect(source, contains('CREATE TABLE IF NOT EXISTS chat_rooms'));
      expect(source, contains('chat_id TEXT'));
      expect(source, contains('processed_offline_packets'));
      expect(source, contains('offline_packet_queue'));
      expect(source, contains('message_queue'));
    });

    test('TripContextService exposes active-state operations', () {
      final source =
          File('lib/features/trip_context/data/trip_context_service.dart')
              .readAsStringSync();

      expect(source,
          contains('Future<ActiveTripContext?> getActiveTripContext()'));
      expect(source, contains('Future<void> activateTrip(String tripId)'));
      expect(source, contains('Future<void> deactivateTrip(String tripId)'));
      expect(source,
          contains('Future<ActiveTripContext> createTripWithPrimaryChannel'));
      expect(source,
          contains('Future<void> ensureDefaultChannelAndChat(String tripId)'));
      expect(
          source, contains('Future<OfflineChannelModel?> getActiveChannel()'));
      expect(source, contains('Future<ChatRoomModel?> getActiveChat()'));
      expect(source,
          contains('Future<void> switchActiveChannel(String channelId)'));
      expect(source, contains('Future<void> switchActiveChat(String chatId)'));
      expect(source, contains('joinOfflineChannelAsActiveTrip'));
      expect(source, contains('activateOfflineChannelAsTrip'));
      expect(source, contains('_reconcileGloballyActiveChannel'));
      expect(source, contains("'status': 'inactive'"));
      expect(source, contains("'is_active': 0"));
    });

    test('legacy active providers derive from active trip context provider',
        () {
      final tripSource =
          File('lib/features/trip/data/trip_session_service.dart')
              .readAsStringSync();
      final channelSource = File(
              'lib/features/offline_channel/presentation/offline_channel_controller.dart')
          .readAsStringSync();

      expect(tripSource, contains('activeTripContextProvider.future'));
      expect(channelSource, contains('activeTripContextProvider.future'));
      expect(channelSource, contains('switchActiveChannel(channelId)'));
    });

    test('join paths use canonical trip context activation', () {
      final channelController = File(
              'lib/features/offline_channel/presentation/offline_channel_controller.dart')
          .readAsStringSync();
      final joinScreen = File(
        'lib/features/offline_channel/presentation/join_offline_channel_screen.dart',
      ).readAsStringSync();
      final tripSetup =
          File('lib/features/trip/presentation/trip_setup_screen.dart')
              .readAsStringSync();
      final tripWizard = File(
        'lib/features/trip/presentation/trip_setup_wizard_screen.dart',
      ).readAsStringSync();

      expect(channelController, contains('joinOfflineChannelAsActiveTrip'));
      expect(joinScreen, contains('activeTripContextProvider'));
      expect(tripSetup, contains('joinOfflineChannelAsActiveTrip'));
      expect(tripWizard, contains('joinOfflineChannelAsActiveTrip'));
      expect(
        channelController,
        isNot(contains('_tripSessionRepository.activateOfflineChannelTrip')),
      );
    });

    test('trip, channel, chat, and message models preserve context IDs', () {
      final trip = TripSessionModel.fromDb({
        'trip_id': 'trip-1',
        'trip_name': 'Knuckles Weekend Hike',
        'mode': 'offline',
        'cloud_group_id': null,
        'cloud_group_name': null,
        'offline_channel_id': 'channel-1',
        'active_channel_id': 'channel-1',
        'channel_code': 'TL-OFF-A123',
        'channel_name': 'Main Team Channel',
        'local_identity_id': 'local-1',
        'status': 'active',
        'started_at': '2026-05-09T10:00:00.000',
        'ended_at': null,
        'sync_state': 'local_only',
        'created_at': '2026-05-09T10:00:00.000',
        'updated_at': '2026-05-09T10:00:00.000',
        'last_opened_at': '2026-05-09T10:01:00.000',
      });
      expect(trip.activeChannelId, 'channel-1');
      expect(trip.toDbMap()['active_channel_id'], 'channel-1');

      final channel = OfflineChannelModel.fromDb({
        'channel_id': 'channel-1',
        'owner_local_id': 'local-1',
        'owner_display_name': 'Owner',
        'channel_name': 'Main Team Channel',
        'channel_code': 'TL-OFF-A123',
        'description': '',
        'is_active': 1,
        'is_host': 1,
        'created_at': '2026-05-09T10:00:00.000',
        'updated_at': '2026-05-09T10:00:00.000',
        'channel_status': 'active',
        'trip_id': 'trip-1',
        'is_primary': 1,
      });
      expect(channel.tripId, 'trip-1');
      expect(channel.isPrimary, true);
      expect(channel.toDbMap()['trip_id'], 'trip-1');

      final chat = ChatRoomModel.fromDb({
        'chat_id': 'chat-1',
        'trip_id': 'trip-1',
        'channel_id': 'channel-1',
        'cloud_group_id': null,
        'chat_name': 'General',
        'chat_type': 'offline_channel',
        'is_default': 1,
        'is_active': 1,
        'chat_status': 'active',
        'created_at': '2026-05-09T10:00:00.000',
        'updated_at': '2026-05-09T10:00:00.000',
      });
      expect(chat.chatName, 'General');
      expect(chat.isDefault, true);
      expect(chat.toDbMap()['chat_id'], 'chat-1');
    });

    test('offline and cloud message payloads preserve nullable chat_id', () {
      final offline = OfflineTextMessageModel.fromDb({
        'message_id': 'offline-message-1',
        'packet_id': 'packet-1',
        'channel_id': 'channel-1',
        'channel_code': 'TL-OFF-A123',
        'chat_id': 'chat-1',
        'sender_id': 'local-1',
        'sender_name': 'Owner',
        'content': 'Hello',
        'is_mine': 1,
        'delivery_status': 'pending',
        'ack_status': 'waiting',
        'ttl': 5,
        'hop_count': 0,
        'created_at': '2026-05-09T10:00:00.000',
      });
      expect(offline.chatId, 'chat-1');
      expect(offline.toDbMap()['chat_id'], 'chat-1');

      final cloud = ChatMessageModel.fromDb({
        'local_id': 'local-message-1',
        'server_id': null,
        'client_message_id': 'client-message-1',
        'group_id': 'group-1',
        'trip_id': 'trip-1',
        'channel_id': 'channel-1',
        'chat_id': 'chat-1',
        'sender_id': 'user-1',
        'sender_name': 'Owner',
        'message_type': 'text',
        'content': 'Hello cloud',
        'delivery_status': 'pending',
        'is_mine': 1,
        'created_at': '2026-05-09T10:00:00.000',
        'sync_state': 'needs_sync',
      });
      expect(cloud.tripId, 'trip-1');
      expect(cloud.channelId, 'channel-1');
      expect(cloud.chatId, 'chat-1');
      expect(cloud.toSyncJson()['chatId'], 'chat-1');
    });

    test('backend trip context sync and message metadata endpoints are wired',
        () {
      final app = File('backend/src/app.js').readAsStringSync();
      final messageModel =
          File('backend/src/models/message.model.js').readAsStringSync();
      final service =
          File('backend/src/modules/tripContext/tripContext.service.js')
              .readAsStringSync();
      final package = File('backend/package.json').readAsStringSync();

      expect(app, contains("app.use('/api/trip-context', tripContextRoutes)"));
      expect(service, contains('findOneAndUpdate'));
      expect(service, contains("status: 'inactive'"));
      expect(service, contains('activeChannelId'));
      expect(messageModel, contains('tripId'));
      expect(messageModel, contains('channelId'));
      expect(messageModel, contains('chatId'));
      expect(package, contains('test:phase14g'));
    });
  });
}
