import 'package:dio/dio.dart';

import 'group_api.dart';
import 'group_local_data_source.dart';
import 'models/group_member_model.dart';
import 'models/group_model.dart';

class GroupRepository {
  GroupRepository({
    GroupApi? api,
    GroupLocalDataSource? local,
  })  : _api = api ?? GroupApi(),
        _local = local ?? GroupLocalDataSource();

  final GroupApi _api;
  final GroupLocalDataSource _local;

  Future<List<GroupModel>> getMyGroups() async {
    final cached = await _local.loadGroups();
    try {
      return await refreshRemoteGroupsAndCache();
    } catch (_) {
      return cached;
    }
  }

  Future<List<GroupModel>> loadLocalGroups() {
    return _local.loadGroups();
  }

  Future<List<GroupModel>> refreshRemoteGroupsAndCache() async {
    final groups = await _api.getMyGroups();
    await _local.upsertGroups(groups);
    return groups;
  }

  Future<GroupModel> createGroup({
    required String groupName,
    required String description,
  }) async {
    final group = await _api.createGroup(
      groupName: groupName,
      description: description,
    );
    await _local.upsertGroups([group]);
    return group;
  }

  Future<GroupModel> joinGroup({required String groupCode}) async {
    final group = await _api.joinGroup(groupCode: groupCode);
    await _local.upsertGroups([group]);
    return group;
  }

  Future<GroupModel> getGroup(String groupId) async {
    final cached = await _local.loadGroup(groupId);
    try {
      final group = await _api.getGroup(groupId);
      await _local.upsertGroups([group]);
      return group;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<GroupMemberModel>> getMembers(String groupId) async {
    final cached = await _local.loadMembers(groupId);
    try {
      final members = await _api.getMembers(groupId);
      await _local.upsertMembers(groupId, members);
      return members;
    } catch (_) {
      return cached;
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = await _api.leaveGroup(groupId);
    await _local.markCurrentGroupLeft(groupId);
    if (userId != null && userId.isNotEmpty) {
      await _local.markMemberStatus(
        groupId: groupId,
        memberId: userId,
        membershipStatus: 'left',
      );
    }
  }

  Future<void> removeMember({
    required String groupId,
    required GroupMemberModel member,
  }) async {
    await _api.removeMember(groupId: groupId, memberId: member.id);
    final identity = member.userId.isNotEmpty
        ? member.userId
        : member.localUserId ?? member.id;
    await _local.markMemberStatus(
      groupId: groupId,
      memberId: identity,
      membershipStatus: 'removed',
    );
  }

  Future<void> archiveGroup(String groupId) async {
    await _api.archiveGroup(groupId);
    await _local.markGroupArchived(groupId);
  }

  Future<void> markGroupArchivedFromSocket(String groupId) {
    return _local.markGroupArchived(groupId);
  }

  Future<GroupMemberModel> updateMemberRole({
    required String groupId,
    required String memberId,
    required String role,
  }) async {
    final member = await _api.updateMemberRole(
      groupId: groupId,
      memberId: memberId,
      role: role,
    );
    await _local.upsertMembers(groupId, [member]);
    return member;
  }

  String messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Backend not reachable.';
    }
    return 'Something went wrong. Please try again.';
  }
}
