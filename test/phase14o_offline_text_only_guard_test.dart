import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 14O/14P offline safety tool contracts', () {
    test('offline text-only flag is disabled for restored safety tools', () {
      final source = File('lib/core/config/offline_text_only_flags.dart')
          .readAsStringSync();

      expect(source, contains('static const bool enabled = false'));
      expect(source, contains('Offline chat'));
      expect(source, contains('map, SOS, voice notes'));
      expect(source, contains('Live Radio'));
    });

    test('offline dashboard exposes chat, connection, map, SOS, and talk', () {
      final source = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();

      expect(source, isNot(contains('OfflineTextOnlyFlags.enabled')));
      expect(source, contains("'Channels'"));
      expect(source, contains("'Offline Chat'"));
      expect(source, contains("'Connect phones'"));
      expect(source, contains("'Send SOS'"));
      expect(source, contains("'Share location'"));
      expect(source, contains("'Talk'"));
      expect(source, contains('voice_note_ptt'));
      expect(source, contains('offline_sos'));
      expect(source, contains('offline_location_share'));
    });

    test('bottom nav stays stable for all modes', () {
      final source =
          File('lib/shared/widgets/trail_bottom_nav.dart').readAsStringSync();

      expect(source, isNot(contains('OfflineTextOnlyFlags.enabled')));
      expect(source, contains("label: 'Home'"));
      expect(source, contains("label: 'Messages'"));
      expect(source, contains("label: 'Connect'"));
      expect(source, contains("context.go('/nearby-peers')"));
      expect(source, contains("label: 'Map'"));
      expect(source, contains("label: 'SOS'"));
      expect(source, isNot(contains("label: 'Channels'")));
    });

    test('offline map, SOS, and PTT routes open real screens', () {
      final source = File('lib/app/router.dart').readAsStringSync();

      expect(source, isNot(contains('_offlineTextOnlyActive(ref)')));
      expect(source, isNot(contains('OfflineFeatureDisabledScreen')));
      expect(source, contains('SosScreen('));
      expect(source, contains('MapScreen('));
      expect(source, contains('PttScreen('));
      expect(source, contains('offlineChannelId:'));
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
      final connectStart = source.indexOf('Future<void> connectToPeer');
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
