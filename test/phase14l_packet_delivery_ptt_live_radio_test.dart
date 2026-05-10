import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/nearby/data/models/nearby_advertisement_payload.dart';

void main() {
  group('Phase 14L packet delivery, PTT, and Live Radio reliability', () {
    test('offline packet router hydrates actor from local identity', () {
      final source = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();

      expect(source, contains('localIdentityRepositoryProvider'));
      expect(source, contains('_refreshRouterActorFromStorage'));
      expect(source, contains('CurrentUserActor.fromLocalIdentity'));
      expect(source, contains("reason: 'no-current-actor'"));
      expect(source, contains('Offline packet ignored. No local identity.'));
      expect(source, isNot(contains('if (actor == null) return;')));
    });

    test('setup and trip wizard refresh auth access after local identity saves',
        () {
      final tripSetup =
          File('lib/features/trip/presentation/trip_setup_screen.dart')
              .readAsStringSync();
      final wizard =
          File('lib/features/trip/presentation/trip_setup_wizard_screen.dart')
              .readAsStringSync();

      expect(tripSetup, contains('refreshFromIdentity()'));
      expect(wizard, contains('refreshFromIdentity()'));
      expect(tripSetup, contains('activeTripContextProvider'));
      expect(wizard, contains('activeTripContextProvider'));
    });

    test('Nearby transport exposes packet and payload-transfer diagnostics',
        () {
      final source = File(
        'lib/features/nearby/data/nearby_connections_transport.dart',
      ).readAsStringSync();

      expect(source, contains('onPayloadTransferUpdate'));
      expect(source, contains('_debugNearbyPacket'));
      expect(source, contains('_debugPayloadTransfer'));
      expect(source, contains('[TrailLink][NearbyPacket]'));
      expect(source, contains('[TrailLink][NearbyPayload]'));
      expect(source, contains('rx_invalid_utf8'));
    });

    test('Nearby advertisement endpoint stays below BLE endpoint limit', () {
      final endpointName = NearbyAdvertisementPayload(
        userId: '4545b665-da8a-4e1e-850f-91f4e7cc41a6',
        displayName: 'Samsung14L',
        activeChannelId: '0f1a78ee-9798-44b2-b592-b11f965ce8a2',
        activeChannelCode: 'TL-OFF-14L',
        deviceName: 'samsung SM-A127F',
        timestamp: DateTime(2026, 5, 10),
      ).toEndpointName();

      expect(endpointName, startsWith('TL2|'));
      expect(endpointName.length, lessThanOrEqualTo(131));

      final decoded = NearbyAdvertisementPayload.fromEndpointName(endpointName);
      expect(decoded.activeChannelCode, 'TL-OFF-14L');
      expect(decoded.displayName, 'Samsung14L');
      expect(decoded.deviceName, 'samsung SM');
      expect(decoded.isCompatibleWith('TL-OFF-14L'), isTrue);
    });

    test('offline voice-note PTT distinguishes queued from failed delivery',
        () {
      final source =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();

      expect(source, contains('offlineMaxFileBytes = 250 * 1024'));
      expect(source, contains('hadConnectedPeers'));
      expect(source, contains("deliveryStatus: sent"));
      expect(source, contains("'failed'"));
      expect(
        source,
        contains('Voice note could not reach connected peers.'),
      );
      expect(source, contains('voice_ack'));
    });

    test('incoming offline text is stored under receiver local channel', () {
      final source = File(
        'lib/features/offline_chat/data/offline_chat_repository.dart',
      ).readAsStringSync();
      final start =
          source.indexOf('if (!await _local.messageExists(packet.messageId!))');
      final incomingInsertBlock = source.substring(
        start,
        source.indexOf('await _local.markProcessed(packet: packet', start),
      );

      expect(
          incomingInsertBlock, contains('channelId: activeChannel.channelId'));
      expect(
        incomingInsertBlock,
        contains('channelCode: activeChannel.channelCode'),
      );
      expect(
          incomingInsertBlock, isNot(contains('channelId: packet.channelId')));
    });

    test('Live Radio remains experimental and falls back safely', () {
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();
      final audio = File(
        'lib/features/ptt/data/live_radio_audio_service.dart',
      ).readAsStringSync();
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();

      expect(repository, contains('liveAudioMaxPacketBytes'));
      expect(repository, contains('Use voice-note PTT'));
      expect(repository, contains('_failActiveLiveRadio'));
      expect(repository, contains('liveRadioFailureStream'));
      expect(audio, contains('LiveAudioChunkErrorHandler'));
      expect(audio, contains('onChunkError'));
      expect(controller, contains('_onLiveRadioFailure'));
      expect(controller, contains('PttVoiceMode.voiceNote'));
    });
  });
}
