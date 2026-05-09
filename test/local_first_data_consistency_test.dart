import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/app/router.dart';
import 'package:traillink/features/chat/data/models/chat_message_model.dart';
import 'package:traillink/features/emergency/data/models/emergency_event_model.dart';
import 'package:traillink/features/groups/data/models/group_member_model.dart';
import 'package:traillink/features/groups/data/models/group_model.dart';

void main() {
  group('Local-first data consistency contracts', () {
    test('group model maps local_groups rows with latest known metadata', () {
      final group = GroupModel.fromDb({
        'group_id': 'group_1',
        'group_name': 'Ridgeline Crew',
        'group_code': 'RIDGE1',
        'description': 'Weekend hike',
        'member_role': 'owner',
        'member_count': 4,
        'status': 'active',
        'source': 'backend',
        'sync_state': 'synced',
        'last_synced_at': '2026-05-08T10:00:00.000Z',
        'created_at': '2026-05-08T09:00:00.000Z',
        'updated_at': '2026-05-08T10:00:00.000Z',
      });

      expect(group.id, 'group_1');
      expect(group.groupName, 'Ridgeline Crew');
      expect(group.memberRole, 'owner');
      expect(group.syncState, 'synced');
      expect(group.isLatestKnown, isTrue);
      expect(group.toLocalDbMap()['group_id'], 'group_1');
    });

    test('group member model maps local_group_members rows', () {
      final member = GroupMemberModel.fromDb({
        'group_id': 'group_1',
        'user_id': 'cloud_1',
        'local_user_id': 'local_1',
        'display_name': 'Dhananjaya',
        'email': 'user@example.com',
        'phone_number': '0771234567',
        'role': 'member',
        'membership_status': 'active',
        'presence_status': 'offline',
        'last_seen_at': '2026-05-08T10:00:00.000Z',
        'source': 'backend',
        'created_at': '2026-05-08T09:00:00.000Z',
      });

      expect(member.groupId, 'group_1');
      expect(member.userId, 'cloud_1');
      expect(member.localUserId, 'local_1');
      expect(member.fullName, 'Dhananjaya');
      expect(member.presenceStatus, 'offline');
      expect(member.toLocalDbMap()['display_name'], 'Dhananjaya');
    });

    test('route guard allows cached groups but keeps cloud mutations guarded',
        () {
      expect(isOnlineOnlyRoute('/groups'), isFalse);
      expect(isOnlineOnlyRoute('/groups/group_1'), isFalse);
      expect(isOnlineOnlyRoute('/groups/group_1/chat'), isTrue);
      expect(isOnlineOnlyRoute('/groups/create'), isTrue);
      expect(isOnlineOnlyRoute('/groups/join'), isTrue);
      expect(isOnlineOnlyRoute('/chat'), isFalse);
    });

    test('remote chat merge preserves pending local message status', () {
      final local = ChatMessageModel(
        localId: 'local_1',
        clientMessageId: 'client_1',
        groupId: 'group_1',
        senderId: 'cloud_1',
        senderName: 'Dhananjaya',
        messageType: 'text',
        content: 'Need water',
        deliveryStatus: 'pending',
        isMine: true,
        createdAt: DateTime.parse('2026-05-08T10:00:00.000Z'),
        syncState: 'needs_sync',
      );
      final remote = local.copyWith(
        serverId: 'server_1',
        deliveryStatus: 'synced',
        syncState: 'synced',
      );

      final merged = ChatMessageModel.mergeLocalWithRemote(
        local: local,
        remote: remote,
      );

      expect(merged.serverId, 'server_1');
      expect(merged.deliveryStatus, 'pending');
      expect(merged.syncState, 'needs_sync');
    });

    test('API models normalize server synced state to synced', () {
      final message = ChatMessageModel.fromApiJson(
        {
          'id': 'server_1',
          'clientMessageId': 'client_1',
          'groupId': 'group_1',
          'sender': {'id': 'cloud_2', 'fullName': 'Teammate'},
          'content': 'Copy',
          'createdAt': '2026-05-08T10:00:00.000Z',
        },
        currentUserId: 'cloud_1',
      );
      final event = EmergencyEventModel.fromApiJson({
        'id': 'event_1',
        'clientEventId': 'sos_1',
        'groupId': 'group_1',
        'alertType': 'sos',
        'createdAt': '2026-05-08T10:00:00.000Z',
      });

      expect(message.syncState, 'synced');
      expect(message.deliveryStatus, 'synced');
      expect(event.syncState, 'synced');
    });
  });
}
