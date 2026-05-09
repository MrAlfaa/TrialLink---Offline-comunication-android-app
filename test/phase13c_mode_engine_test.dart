import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/connectivity/send_path_decider.dart';
import 'package:traillink/core/mode/mode_controller.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/features/auth/data/models/user_model.dart';
import 'package:traillink/features/emergency/data/emergency_packet_service.dart';
import 'package:traillink/features/emergency/data/models/emergency_event_model.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_model.dart';

void main() {
  group('Phase 13C mode calculation', () {
    test('auto mode follows backend connection state', () {
      expect(
        ModeController.decideEffectiveMode(
          userMode: UserMode.auto,
          connectionState: DetectedConnectionState.backendOnline,
        ),
        EffectiveMode.online,
      );
      expect(
        ModeController.decideEffectiveMode(
          userMode: UserMode.auto,
          connectionState: DetectedConnectionState.backendOffline,
        ),
        EffectiveMode.offline,
      );
      expect(
        ModeController.decideEffectiveMode(
          userMode: UserMode.auto,
          connectionState: DetectedConnectionState.reconnecting,
        ),
        EffectiveMode.hybridLimited,
      );
      expect(
        ModeController.decideEffectiveMode(
          userMode: UserMode.auto,
          connectionState: DetectedConnectionState.unstable,
        ),
        EffectiveMode.hybridLimited,
      );
    });

    test('manual modes override backend connection state', () {
      expect(
        ModeController.decideEffectiveMode(
          userMode: UserMode.offline,
          connectionState: DetectedConnectionState.backendOnline,
        ),
        EffectiveMode.offline,
      );
      expect(
        ModeController.decideEffectiveMode(
          userMode: UserMode.online,
          connectionState: DetectedConnectionState.backendOffline,
        ),
        EffectiveMode.online,
      );
    });

    test('manual mode warnings explain queue and sync behavior', () {
      final offlineWarning = ModeController.getModeWarningMessageFor(
        userMode: UserMode.offline,
        connectionState: DetectedConnectionState.backendOnline,
        effectiveMode: EffectiveMode.offline,
        backendReachable: true,
      );
      expect(offlineWarning, contains('Offline Mode active'));
      expect(offlineWarning, contains('switch back or choose Auto'));

      final onlineWarning = ModeController.getModeWarningMessageFor(
        userMode: UserMode.online,
        connectionState: DetectedConnectionState.backendOffline,
        effectiveMode: EffectiveMode.online,
        backendReachable: false,
      );
      expect(onlineWarning, contains('server is unreachable'));
      expect(onlineWarning, contains('queued locally'));
    });
  });

  group('Phase 13C send path decisions', () {
    test('online paths prefer socket, then REST, then local queue', () {
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.online,
          backendReachable: true,
          socketConnected: true,
          hasOfflineContext: false,
          hasConnectedPeers: false,
        ),
        SendPath.backendSocket,
      );
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.online,
          backendReachable: true,
          socketConnected: false,
          hasOfflineContext: false,
          hasConnectedPeers: false,
        ),
        SendPath.backendRest,
      );
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.online,
          backendReachable: false,
          socketConnected: false,
          hasOfflineContext: false,
          hasConnectedPeers: false,
        ),
        SendPath.localQueueOnly,
      );
    });

    test('offline paths never attempt backend sends', () {
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.offline,
          backendReachable: true,
          socketConnected: true,
          hasOfflineContext: true,
          hasConnectedPeers: true,
        ),
        SendPath.offlineNearby,
      );
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.offline,
          backendReachable: true,
          socketConnected: true,
          hasOfflineContext: true,
          hasConnectedPeers: false,
        ),
        SendPath.localQueueOnly,
      );
    });

    test('hybrid limited uses conservative queue paths', () {
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.hybridLimited,
          backendReachable: true,
          socketConnected: false,
          hasOfflineContext: true,
          hasConnectedPeers: false,
        ),
        SendPath.hybridQueue,
      );
      expect(
        SendPathDecider.decideForEffectiveMode(
          effectiveMode: EffectiveMode.hybridLimited,
          backendReachable: false,
          socketConnected: false,
          hasOfflineContext: false,
          hasConnectedPeers: false,
        ),
        SendPath.localQueueOnly,
      );
    });
  });

  group('Phase 13C SOS location consent', () {
    test('offline SOS packet omits location when no coordinates are attached',
        () {
      final packet = EmergencyPacketService().createSosPacket(
        channel: OfflineChannelModel(
          channelId: 'channel-1',
          channelCode: 'TL-OFF-8K2P',
          channelName: 'Demo Channel',
          createdByUserId: 'guest-1',
          createdAt: DateTime.utc(2026),
        ),
        user: const UserModel(
          id: 'guest-1',
          fullName: 'Guest Explorer',
          email: '',
        ),
        event: EmergencyEventModel(
          localEventId: 'event-1',
          offlineChannelId: 'channel-1',
          channelCode: 'TL-OFF-8K2P',
          alertType: 'sos',
          message: 'Need help',
          priority: 'emergency',
          status: 'pending',
          deliveryMode: 'offline',
          ackStatus: 'waiting',
          retryCount: 0,
          createdAt: DateTime.utc(2026),
          syncState: 'local_only',
        ),
      );

      expect(packet.packetType, 'sos');
      expect(packet.payload.containsKey('location'), isFalse);
      expect(packet.senderName, 'Guest Explorer');
      expect(packet.channelCode, 'TL-OFF-8K2P');
    });
  });
}
