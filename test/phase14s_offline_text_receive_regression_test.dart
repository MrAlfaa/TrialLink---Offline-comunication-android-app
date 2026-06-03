import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/nearby/data/models/nearby_connection_status.dart';
import 'package:traillink/features/nearby/data/models/nearby_peer_model.dart';
import 'package:traillink/features/offline_chat/data/offline_chat_repository.dart';

void main() {
  group('Phase 14S offline text receive regressions', () {
    test('same phone with stale endpoint and live endpoint renders once', () {
      final now = DateTime(2026, 5, 26, 15, 30);
      final stale = NearbyPeerModel(
        endpointId: 'old-endpoint',
        userId: 'old-endpoint',
        displayName: 'Samsung',
        deviceName: 'samsung SM',
        activeChannelId: 'channel-1',
        activeChannelCode: 'TL-OFF-14Q',
        status: PeerConnectionStatus.lost,
        discoveredAt: now.subtract(const Duration(minutes: 10)),
        lastSeenAt: now.subtract(const Duration(minutes: 8)),
      );
      final live = NearbyPeerModel(
        endpointId: 'new-endpoint',
        userId: 'member-local-1',
        displayName: 'Samsung',
        deviceName: 'samsung SM',
        activeChannelId: 'channel-1',
        activeChannelCode: 'TL-OFF-14Q',
        status: PeerConnectionStatus.connected,
        discoveredAt: now,
        lastSeenAt: now,
        appDeviceId: 'device-1',
      );

      final collapsed = NearbyPeerModel.collapseDuplicates([stale, live]);

      expect(collapsed, hasLength(1));
      expect(collapsed.single.endpointId, 'new-endpoint');
      expect(collapsed.single.status, PeerConnectionStatus.connected);
    });

    test('weak historical peer row collapses into live row by display name',
        () {
      final now = DateTime(2026, 5, 26, 15, 45);
      final oldRow = NearbyPeerModel(
        endpointId: 'old-endpoint',
        userId: 'old-endpoint',
        displayName: 'XiomiQa',
        deviceName: 'Nearby phone',
        activeChannelId: 'channel-1',
        activeChannelCode: 'TL-OFF-14Q',
        status: PeerConnectionStatus.lost,
        discoveredAt: now.subtract(const Duration(minutes: 6)),
        lastSeenAt: now.subtract(const Duration(minutes: 4)),
      );
      final liveRow = NearbyPeerModel(
        endpointId: 'new-endpoint',
        userId: 'new-endpoint',
        displayName: 'XiomiQa',
        deviceName: 'Xiaomi M21',
        activeChannelId: 'channel-1',
        activeChannelCode: 'TL-OFF-14Q',
        status: PeerConnectionStatus.discovered,
        discoveredAt: now,
        lastSeenAt: now,
      );

      final collapsed = NearbyPeerModel.collapseDuplicates([oldRow, liveRow]);

      expect(collapsed, hasLength(1));
      expect(collapsed.single.endpointId, 'new-endpoint');
      expect(collapsed.single.status, PeerConnectionStatus.discovered);
    });

    test('local self peer is filtered by strong and weak identity', () {
      final now = DateTime(2026, 5, 26, 16);
      final strongSelf = NearbyPeerModel(
        endpointId: 'endpoint-1',
        userId: 'local-me',
        displayName: 'SamsungQA',
        deviceName: 'samsung SM',
        activeChannelId: 'channel-1',
        activeChannelCode: 'TL-OFF-14Q',
        status: PeerConnectionStatus.discovered,
        discoveredAt: now,
        lastSeenAt: now,
      );
      final weakSelf = NearbyPeerModel(
        endpointId: 'endpoint-2',
        userId: 'endpoint-2',
        displayName: 'SamsungQA',
        deviceName: 'Nearby phone',
        activeChannelId: 'channel-1',
        activeChannelCode: 'TL-OFF-14Q',
        status: PeerConnectionStatus.lost,
        discoveredAt: now,
        lastSeenAt: now,
      );

      expect(
        strongSelf.matchesLocalIdentity(
          localUserId: 'local-me',
          displayName: 'SamsungQA',
        ),
        isTrue,
      );
      expect(
        weakSelf.matchesLocalIdentity(
          localUserId: 'local-me',
          displayName: 'SamsungQA',
        ),
        isTrue,
      );
    });

    test('incoming sender chat id maps to receiver default chat when unknown',
        () {
      expect(
        OfflineChatRepository.normalizeIncomingChatId(
          packetChatId: 'sender-local-chat',
          receiverDefaultChatId: 'receiver-general-chat',
          packetChatExistsForReceiverChannel: false,
        ),
        'receiver-general-chat',
      );

      expect(
        OfflineChatRepository.normalizeIncomingChatId(
          packetChatId: 'receiver-extra-chat',
          receiverDefaultChatId: 'receiver-general-chat',
          packetChatExistsForReceiverChannel: true,
        ),
        'receiver-extra-chat',
      );
    });

    test('p2p peer repository merges endpoint and identity collisions', () {
      final repository =
          File('lib/features/p2p_session/data/p2p_session_repository.dart')
              .readAsStringSync();

      expect(repository, contains('_matchingPeerRows'));
      expect(repository, contains('_selectPeerKeeper'));
      expect(repository, contains('_mergePeerRows'));
      expect(repository, contains('txn.delete('));
    });

    test('nearby transport restarts stale visibility and finding sessions', () {
      final transport =
          File('lib/features/nearby/data/nearby_connections_transport.dart')
              .readAsStringSync();

      expect(transport, contains('_bestEffortStop'));
      expect(transport, contains('restart_advertising'));
      expect(transport, contains('restart_discovery'));
      expect(transport, contains('_isCurrentDevicePayload'));
      expect(transport, contains('_isCurrentPeer'));
    });

    test('cloud profile gate restores backend auth before returning online',
        () {
      final authAccess = File('lib/core/identity/auth_access_controller.dart')
          .readAsStringSync();
      final linkScreen =
          File('lib/features/account_link/link_offline_data_screen.dart')
              .readAsStringSync();
      final cloudRepo = File(
              'lib/features/cloud_identity/data/cloud_identity_repository.dart')
          .readAsStringSync();
      final cloudService = File(
              'lib/features/cloud_identity/data/cloud_identity_bootstrap_service.dart')
          .readAsStringSync();
      final router = File('lib/app/router.dart').readAsStringSync();

      expect(authAccess, contains('refreshFromBackendSession'));
      expect(authAccess, contains('restoreSession('));
      expect(linkScreen, contains('refreshFromBackendSession'));
      expect(linkScreen, contains('retryCloudBootstrap'));
      expect(linkScreen, contains('_safeReturnPath'));
      expect(router, contains("from=\$from"));
      expect(
        cloudRepo,
        contains('await _identityRepository.markCloudCreating();'),
      );
      expect(cloudService, isNot(contains('CloudBootstrapResult.ready')));
    });
  });
}
