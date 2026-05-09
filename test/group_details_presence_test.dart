import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/chat/presentation/chat_mode_label.dart';
import 'package:traillink/features/groups/data/models/group_member_model.dart';
import 'package:traillink/features/groups/presentation/group_member_permissions.dart';
import 'package:traillink/features/offline_channel/data/offline_presence_service.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_member_model.dart';

void main() {
  group('group member management contracts', () {
    test('owner and admin can remove another active non-owner member', () {
      const member = GroupMemberModel(
        id: 'membership_2',
        userId: 'cloud_2',
        fullName: 'Kasun',
        email: 'kasun@example.com',
        memberRole: 'member',
        joinedAt: '2026-05-08T10:00:00.000Z',
      );

      expect(
        GroupMemberPermissions.canRemoveMember(
          requesterRole: 'owner',
          requesterUserId: 'cloud_1',
          member: member,
        ),
        isTrue,
      );
      expect(
        GroupMemberPermissions.canRemoveMember(
          requesterRole: 'admin',
          requesterUserId: 'cloud_1',
          member: member,
        ),
        isTrue,
      );
    });

    test('regular member, self-removal, and owner target removal are denied',
        () {
      const owner = GroupMemberModel(
        id: 'membership_owner',
        userId: 'cloud_owner',
        fullName: 'Owner',
        email: 'owner@example.com',
        memberRole: 'owner',
        joinedAt: '2026-05-08T10:00:00.000Z',
      );
      const member = GroupMemberModel(
        id: 'membership_member',
        userId: 'cloud_member',
        fullName: 'Member',
        email: 'member@example.com',
        memberRole: 'member',
        joinedAt: '2026-05-08T10:00:00.000Z',
      );

      expect(
        GroupMemberPermissions.canRemoveMember(
          requesterRole: 'member',
          requesterUserId: 'cloud_owner',
          member: member,
        ),
        isFalse,
      );
      expect(
        GroupMemberPermissions.canRemoveMember(
          requesterRole: 'owner',
          requesterUserId: 'cloud_member',
          member: member,
        ),
        isFalse,
      );
      expect(
        GroupMemberPermissions.canRemoveMember(
          requesterRole: 'admin',
          requesterUserId: 'cloud_admin',
          member: owner,
        ),
        isFalse,
      );
    });
  });

  group('offline channel presence contracts', () {
    test('member maps membership, presence, connection, identity, and endpoint',
        () {
      final member = OfflineChannelMemberModel.fromDb({
        'channel_id': 'channel_1',
        'user_id': 'local_2',
        'display_name': 'Kasun',
        'member_role': 'member',
        'source': 'peer',
        'status': 'active',
        'membership_status': 'active',
        'presence_status': 'disconnected',
        'connection_status': 'lost',
        'endpoint_id': 'endpoint_2',
        'identity_type': 'guest',
        'joined_at': '2026-05-08T10:00:00.000Z',
        'last_seen_at': '2026-05-08T10:02:00.000Z',
      });

      expect(member.membershipStatus, 'active');
      expect(member.presenceStatus, 'disconnected');
      expect(member.connectionStatus, 'lost');
      expect(member.endpointId, 'endpoint_2');
      expect(member.identityType, 'guest');
      expect(member.toDbMap()['membership_status'], 'active');
    });

    test('presence sweep moves connected to recently seen then disconnected',
        () {
      final now = DateTime.parse('2026-05-08T10:03:00.000Z');

      expect(
        OfflinePresenceService.presenceStatusForLastSeen(
          lastSeenAt: now.subtract(const Duration(seconds: 20)),
          now: now,
          currentPresence: 'connected',
        ),
        'connected',
      );
      expect(
        OfflinePresenceService.presenceStatusForLastSeen(
          lastSeenAt: now.subtract(const Duration(seconds: 45)),
          now: now,
          currentPresence: 'connected',
        ),
        'recently_seen',
      );
      expect(
        OfflinePresenceService.presenceStatusForLastSeen(
          lastSeenAt: now.subtract(const Duration(minutes: 3)),
          now: now,
          currentPresence: 'recently_seen',
        ),
        'disconnected',
      );
    });
  });

  group('chat labels', () {
    test('cloud chat uses Online Chat or Offline Chat labels', () {
      expect(
        ChatModeLabel.cloudChatSubtitle(
          isOnline: true,
          socketState: 'connected',
        ),
        'Online Chat',
      );
      expect(
        ChatModeLabel.cloudChatSubtitle(
          isOnline: false,
          socketState: 'disconnected',
        ),
        'Offline Chat',
      );
      expect(
        ChatModeLabel.cloudChatSubtitle(
          isOnline: true,
          socketState: 'reconnecting',
        ),
        'Offline Chat - Saved locally',
      );
    });
  });
}
