import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14M live PTT, SOS, and location contracts', () {
    test('PTT screen refreshes for voice-note and floor router notices', () {
      final screen = File('lib/features/ptt/presentation/ptt_screen.dart')
          .readAsStringSync();
      final controller = File(
        'lib/features/ptt/presentation/ptt_controller.dart',
      ).readAsStringSync();

      expect(screen, contains('shouldRefreshPttForOfflineNotice(notice)'));
      expect(controller, contains('bool shouldRefreshPttForOfflineNotice'));
      expect(controller, contains('voice note received'));
      expect(controller, contains('voice note delivered'));
      expect(controller, contains('is speaking'));
      expect(controller, contains('ptt channel is free'));
    });

    test('PTT repository lifecycle is provider-owned, not screen-owned', () {
      final controller = File(
        'lib/features/ptt/presentation/ptt_controller.dart',
      ).readAsStringSync();

      expect(controller, contains('Provider.autoDispose<PttRepository>'));
      expect(controller, contains('ref.onDispose(repository.dispose)'));
      expect(controller, contains('String _friendlyPttError'));
      expect(controller, contains('Bad state'));

      final disposeBlock = RegExp(
        r'void dispose\(\) \{(?<body>[\s\S]*?)\n  \}',
      ).firstMatch(controller)!.namedGroup('body')!;
      expect(disposeBlock, isNot(contains('_repository.dispose()')));
    });

    test('Nearby packet send rejects stale persisted endpoint state', () {
      final repository = File('lib/features/nearby/data/nearby_repository.dart')
          .readAsStringSync();
      final transport =
          File('lib/features/nearby/data/nearby_packet_transport.dart')
              .readAsStringSync();
      final nearbyConnections =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();

      expect(transport, contains('bool isConnected(String endpointId)'));
      expect(repository, contains('_transport.isConnected(endpointId)'));
      expect(
        repository,
        contains('is not currently connected'),
      );
      expect(
        nearbyConnections,
        contains(
            "_peers[endpointId]?.status == PeerConnectionStatus.connected"),
      );
    });

    test('Live Radio selection stays on Live Radio when blocked or failed', () {
      final controller = File(
        'lib/features/ptt/presentation/ptt_controller.dart',
      ).readAsStringSync();
      final selectStart = controller.indexOf('Future<void> selectVoiceMode');
      final pressStart = controller.indexOf('Future<void> _pressLiveRadio');
      final selectBlock = controller.substring(selectStart, pressStart);
      final livePressBlock = controller.substring(
        pressStart,
        controller.indexOf('Future<void> _releaseLiveRadio', pressStart),
      );
      final failureBlock = controller.substring(
        controller.indexOf('Future<void> _onLiveRadioFailure'),
        controller.indexOf('@override',
            controller.indexOf('Future<void> _onLiveRadioFailure')),
      );

      expect(selectBlock, contains('voiceMode: PttVoiceMode.liveRadio'));
      expect(
        selectBlock,
        isNot(contains('voiceMode: result.fallbackToVoiceNote')),
      );
      expect(livePressBlock, contains('voiceMode: PttVoiceMode.liveRadio'));
      expect(failureBlock, contains('voiceMode: PttVoiceMode.liveRadio'));
      expect(
          failureBlock, isNot(contains('voiceMode: PttVoiceMode.voiceNote')));
    });

    test('incoming Live Radio uses receiver active channel context', () {
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();
      final start = repository.indexOf('Future<void> _handleLiveStart');
      final end = repository.indexOf('Future<void> _handleLiveEnd');
      final liveBlock = repository.substring(start, end);

      expect(liveBlock, contains('OfflineChannelModel activeChannel'));
      expect(liveBlock, contains('contextId: activeChannel.channelId'));
      expect(liveBlock, contains('offlineChannelId: activeChannel.channelId'));
      expect(liveBlock, isNot(contains('contextId: packet.channelId')));
      expect(liveBlock, isNot(contains('offlineChannelId: packet.channelId')));
    });

    test('offline chat ACK timeout re-reads persisted message state', () {
      final controller = File(
        'lib/features/offline_chat/presentation/offline_chat_controller.dart',
      ).readAsStringSync();
      final repository =
          File('lib/features/offline_chat/data/offline_chat_repository.dart')
              .readAsStringSync();
      final local = File(
        'lib/features/offline_chat/data/offline_message_local_data_source.dart',
      ).readAsStringSync();

      expect(local, contains('Future<OfflineTextMessageModel?> getMessage'));
      expect(repository, contains('markAckTimeoutIfStillWaiting'));
      expect(controller, contains('markAckTimeoutIfStillWaiting(messageId)'));
      expect(controller, isNot(contains('current.first.ackStatus')));
    });

    test('root offline Map share resolves the active channel', () {
      final controller = File(
        'lib/features/location/presentation/location_controller.dart',
      ).readAsStringSync();

      expect(controller, contains('_resolveOfflineChannelForShare'));
      expect(
          controller, contains('await _channelRepository.getActiveChannel()'));
      expect(controller, contains('resolvedChannel?.channelId'));
      expect(controller, contains('Location saved and shared'));
    });

    test('SOS and location router contracts remain wired', () {
      final router = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();
      final emergency =
          File('lib/features/emergency/data/emergency_repository.dart')
              .readAsStringSync();
      final location =
          File('lib/features/location/data/location_repository.dart')
              .readAsStringSync();

      expect(router, contains("case 'sos':"));
      expect(router, contains("case 'sos_ack':"));
      expect(router, contains("case 'location':"));
      expect(router, contains('lastEmergencyAlert'));
      expect(emergency, contains('sendOfflineSosAck'));
      expect(location, contains('TeammateLocationModel'));
      expect(location, contains('offlineChannelId: activeChannel.channelId'));
    });
  });
}
