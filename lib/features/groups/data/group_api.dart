import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/group_member_model.dart';
import 'models/group_model.dart';

class GroupApi {
  GroupApi({Dio? dio}) : _dio = dio ?? DioClient.instance;

  final Dio _dio;

  Future<List<GroupModel>> getMyGroups() async {
    final response = await _dio.get('/groups/my');
    final data = response.data['data'] as Map<String, dynamic>;
    final groups = data['groups'] as List<dynamic>;
    return groups
        .map((item) => GroupModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<GroupModel> createGroup({
    required String groupName,
    required String description,
  }) async {
    final response = await _dio.post(
      '/groups',
      data: {
        'groupName': groupName,
        'description': description,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return GroupModel.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<GroupModel> joinGroup({required String groupCode}) async {
    final response = await _dio.post(
      '/groups/join',
      data: {'groupCode': groupCode.toUpperCase()},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return GroupModel.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<GroupModel> getGroup(String groupId) async {
    final response = await _dio.get('/groups/$groupId');
    final data = response.data['data'] as Map<String, dynamic>;
    return GroupModel.fromJson(data['group'] as Map<String, dynamic>);
  }

  Future<List<GroupMemberModel>> getMembers(String groupId) async {
    final response = await _dio.get('/groups/$groupId/members');
    final data = response.data['data'] as Map<String, dynamic>;
    final members = data['members'] as List<dynamic>;
    return members
        .map((item) => GroupMemberModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String?> leaveGroup(String groupId) async {
    final response = await _dio.post('/groups/$groupId/leave');
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      return data['userId']?.toString();
    }
    return null;
  }

  Future<void> removeMember({
    required String groupId,
    required String memberId,
  }) async {
    await _dio.delete('/groups/$groupId/members/$memberId');
  }

  Future<void> archiveGroup(String groupId) async {
    await _dio.delete('/groups/$groupId');
  }

  Future<GroupMemberModel> updateMemberRole({
    required String groupId,
    required String memberId,
    required String role,
  }) async {
    final response = await _dio.patch(
      '/groups/$groupId/members/$memberId/role',
      data: {'memberRole': role},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return GroupMemberModel.fromJson(data['member'] as Map<String, dynamic>);
  }
}
