import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14O final offline text-only guard', () {
    test('offline text-only flag is enabled with clear user wording', () {
      final source = File('lib/core/config/offline_text_only_flags.dart')
          .readAsStringSync();

      expect(source, contains('static const bool enabled = true'));
      expect(source, contains('nearby text chat'));
      expect(source, contains('Offline PTT, SOS, location sharing'));
      expect(source, contains('Live Radio'));
    });

    test('offline dashboard exposes chat, channels, and nearby only', () {
      final source = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();
      final actionsStart = source.indexOf('final textOnlyActions = [');
      final flagStart = source.indexOf('if (OfflineTextOnlyFlags.enabled)');
      final flagEnd =
          source.indexOf('return [\n    ...textOnlyActions', flagStart);
      final textOnlyActions = source.substring(actionsStart, flagStart);
      final textOnlyBlock = source.substring(flagStart, flagEnd);

      expect(source, contains('OfflineTextOnlyFlags.enabled'));
      expect(textOnlyActions, contains("'Channels'"));
      expect(textOnlyActions, contains("'Offline Chat'"));
      expect(textOnlyActions, contains("'Nearby Peers'"));
      expect(textOnlyActions, isNot(contains("'SOS'")));
      expect(textOnlyActions, isNot(contains("'Location'")));
      expect(textOnlyActions, isNot(contains("'PTT'")));
      expect(textOnlyBlock, isNot(contains("'SOS'")));
      expect(textOnlyBlock, isNot(contains("'Location'")));
      expect(textOnlyBlock, isNot(contains("'PTT'")));
      expect(textOnlyBlock, isNot(contains('voice_note_ptt')));
      expect(textOnlyBlock, isNot(contains('offline_sos')));
      expect(textOnlyBlock, isNot(contains('offline_location_share')));
    });

    test('offline bottom nav swaps map and sos for nearby and channels', () {
      final source =
          File('lib/shared/widgets/trail_bottom_nav.dart').readAsStringSync();

      expect(source, contains('OfflineTextOnlyFlags.enabled'));
      expect(source, contains('effectiveMode == EffectiveMode.offline'));
      expect(source, contains("label: 'Nearby'"));
      expect(source, contains("context.go('/nearby-peers')"));
      expect(source, contains("label: 'Channels'"));
      expect(source, contains("context.go('/offline-channel')"));
    });

    test('offline routes are guarded while online map and sos remain available',
        () {
      final source = File('lib/app/router.dart').readAsStringSync();

      expect(source, contains('_offlineTextOnlyActive(ref)'));
      expect(source, contains("featureName: 'Offline SOS'"));
      expect(source, contains("featureName: 'Offline Location'"));
      expect(source, contains("featureName: 'Offline PTT'"));
      expect(source, contains('const SosScreen()'));
      expect(source, contains('MapScreen(focus: MapFocus.fromExtra'));
    });

    test('offline text ACK updates message before best-effort metrics', () {
      final source =
          File('lib/features/offline_chat/data/offline_chat_repository.dart')
              .readAsStringSync();
      final ackStart = source.indexOf('Future<void> _handleAck');
      final metricStart = source.indexOf('Future<void> _recordAckMetric');
      final ackBlock = source.substring(ackStart, metricStart);

      expect(ackBlock, contains('await _local.saveAck'));
      expect(ackBlock, contains('await _markMessageAcknowledged(packet)'));
      expect(ackBlock, contains('await _recordAckMetric(packet)'));
      expect(
        ackBlock.indexOf('await _markMessageAcknowledged(packet)'),
        lessThan(ackBlock.indexOf('await _recordAckMetric(packet)')),
      );
      expect(ackBlock, contains('ack_metric_failed'));
    });

    test('ACK timeout reconciles a saved ACK before marking timeout', () {
      final source =
          File('lib/features/offline_chat/data/offline_chat_repository.dart')
              .readAsStringSync();
      final timeoutStart =
          source.indexOf('Future<void> markAckTimeoutIfStillWaiting');
      final sendStart = source.indexOf('Future<void> _sendPacketToPeers');
      final timeoutBlock = source.substring(timeoutStart, sendStart);

      expect(timeoutBlock, contains('ackExistsForMessage'));
      expect(timeoutBlock, contains("ackStatus: 'acknowledged'"));
      expect(timeoutBlock, contains("reason: 'ack-already-saved'"));
      expect(
        timeoutBlock.indexOf('ackExistsForMessage'),
        lessThan(timeoutBlock.indexOf('await markAckTimeout(messageId)')),
      );
    });

    test('message loading and send status reconcile saved ACK rows', () {
      final dataSource = File(
              'lib/features/offline_chat/data/offline_message_local_data_source.dart')
          .readAsStringSync();
      final repository =
          File('lib/features/offline_chat/data/offline_chat_repository.dart')
              .readAsStringSync();

      expect(dataSource, contains('Future<int> reconcileAcknowledgedMessages'));
      expect(dataSource,
          contains('await reconcileAcknowledgedMessages(channelId)'));
      expect(dataSource, contains('EXISTS ('));
      expect(dataSource, contains('offline_acks.ack_for_message_id'));
      expect(dataSource, contains('offline_acks.ack_for_packet_id'));
      expect(dataSource, contains('Future<int> markMessageSentAfterTransfer'));

      final sendStart = repository.indexOf('Future<void> _sendPacketToPeers');
      final receiveStart =
          repository.indexOf('Future<OfflinePacketHandleResult>');
      final sendBlock = repository.substring(sendStart, receiveStart);

      expect(sendBlock, contains('markMessageSentAfterTransfer'));
      expect(sendBlock,
          isNot(contains("ackStatus: packet.requiresAck ? 'waiting'")));
    });

    test('connected peers are not lost when only discovery signal is lost', () {
      final source =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();
      final lostStart = source.indexOf('onEndpointLost: (endpointId)');
      final connectStart =
          source.indexOf('@override\n  Future<void> connectToPeer');
      final lostBlock = source.substring(lostStart, connectStart);

      expect(
        lostBlock,
        contains('existing.status == PeerConnectionStatus.connected'),
      );
      expect(lostBlock, contains('discovery_lost_connected_ignored'));
      expect(
        lostBlock.indexOf('PeerConnectionStatus.connected'),
        lessThan(lostBlock.indexOf('PeerConnectionStatus.lost')),
      );
    });
  });
}
