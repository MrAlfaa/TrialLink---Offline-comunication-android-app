import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/identity/auth_access_state.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/features/bridge/data/bridge_engine.dart';
import 'package:traillink/features/bridge/data/bridge_policy.dart';
import 'package:traillink/features/bridge/data/models/bridge_settings_model.dart';
import 'package:traillink/features/offline_chat/data/models/offline_packet_model.dart';
import 'package:traillink/features/trip/data/trip_session_model.dart';

void main() {
  group('Phase 13E packet identity', () {
    test('new offline packets serialize local identity metadata', () {
      final packet = _textPacket();
      final json = packet.toJson();

      expect(json['senderLocalId'], 'guest_1');
      expect(json['senderName'], 'Guest Explorer');
      expect(json['identityType'], 'guest');
      expect(json['sourcePath'], 'offline');
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('jwt'), isFalse);
    });

    test('legacy senderId is still accepted as senderLocalId fallback', () {
      final packet = OfflinePacketModel.fromJson({
        'packetId': 'packet-legacy',
        'packetType': 'text',
        'channelId': 'channel-1',
        'channelCode': 'TL-OFF-8K2P',
        'senderId': 'legacy_sender',
        'senderName': 'Legacy Sender',
        'targetType': 'channel',
        'targetId': 'channel-1',
        'payload': {'content': 'hello'},
        'priority': 'normal',
        'ttl': 5,
        'hopCount': 0,
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });

      expect(packet.senderLocalId, 'legacy_sender');
      expect(packet.sourcePath, 'offline');
    });
  });

  group('Phase 13E bridge policy', () {
    test('allows authenticated online bridge actor on same channel', () {
      final result = BridgePolicy().canBridgeOfflineToOnline(
        featureEnabled: true,
        settings: BridgeSettingsModel.defaults(),
        activeTrip: _trip(),
        packet: _textPacket(),
        authAccessState: AuthAccessState.authenticatedOnline,
        modeState: _mode(backendReachable: true),
        duplicate: false,
      );

      expect(result.allowed, isTrue);
    });

    test('denies wrong channel, backend unavailable, and duplicates', () {
      final policy = BridgePolicy();
      expect(
        policy
            .canBridgeOfflineToOnline(
              featureEnabled: true,
              settings: BridgeSettingsModel.defaults(),
              activeTrip: _trip(channelCode: 'TL-OFF-DIFF'),
              packet: _textPacket(),
              authAccessState: AuthAccessState.authenticatedOnline,
              modeState: _mode(backendReachable: true),
              duplicate: false,
            )
            .allowed,
        isFalse,
      );
      expect(
        policy
            .canBridgeOfflineToOnline(
              featureEnabled: true,
              settings: BridgeSettingsModel.defaults(),
              activeTrip: _trip(),
              packet: _textPacket(),
              authAccessState: AuthAccessState.authenticatedOnline,
              modeState: _mode(backendReachable: false),
              duplicate: false,
            )
            .reason,
        contains('Backend unavailable'),
      );
      expect(
        policy
            .canBridgeOfflineToOnline(
              featureEnabled: true,
              settings: BridgeSettingsModel.defaults(),
              activeTrip: _trip(),
              packet: _textPacket(),
              authAccessState: AuthAccessState.authenticatedOnline,
              modeState: _mode(backendReachable: true),
              duplicate: true,
            )
            .reason,
        contains('Duplicate'),
      );
    });

    test('builds duplicate IDs from origin metadata', () {
      final packet = _textPacket();
      expect(
        BridgeEngine.uniqueItemIdForPacket(packet),
        'message:guest_1:client-1',
      );
    });
  });
}

OfflinePacketModel _textPacket() {
  return OfflinePacketModel(
    packetId: 'packet-1',
    packetType: 'text',
    tripId: 'trip-1',
    channelId: 'channel-1',
    channelCode: 'TL-OFF-8K2P',
    senderId: 'guest_1',
    senderLocalId: 'guest_1',
    senderName: 'Guest Explorer',
    identityType: 'guest',
    sourcePath: 'offline',
    targetType: 'channel',
    targetId: 'channel-1',
    payload: {
      'clientMessageId': 'client-1',
      'content': 'hello',
      'originLocalId': 'guest_1',
    },
    priority: 'normal',
    ttl: 5,
    hopCount: 0,
    createdAt: DateTime.utc(2026),
    requiresAck: true,
  );
}

TripSessionModel _trip({String channelCode = 'TL-OFF-8K2P'}) {
  return TripSessionModel(
    tripId: 'trip-1',
    tripName: 'Demo Trip',
    mode: 'hybrid',
    cloudGroupId: '507f1f77bcf86cd799439011',
    offlineChannelId: 'channel-1',
    channelCode: channelCode,
    localIdentityId: 'guest_1',
    status: 'active',
    startedAt: DateTime.utc(2026),
    syncState: 'local_only',
    createdAt: DateTime.utc(2026),
  );
}

ModeState _mode({required bool backendReachable}) {
  return ModeState.initial().copyWith(
    backendReachable: backendReachable,
    effectiveMode:
        backendReachable ? EffectiveMode.online : EffectiveMode.offline,
  );
}
