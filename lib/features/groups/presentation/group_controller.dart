import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_repository.dart';
import '../data/models/group_member_model.dart';
import '../data/models/group_model.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

final myGroupsProvider = FutureProvider<List<GroupModel>>((ref) async {
  return ref.read(groupRepositoryProvider).getMyGroups();
});

class MyGroupsState {
  const MyGroupsState({
    this.groups = const [],
    this.isLoading = true,
    this.isRefreshing = false,
    this.isLatestKnown = false,
    this.errorMessage,
  });

  final List<GroupModel> groups;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLatestKnown;
  final String? errorMessage;

  MyGroupsState copyWith({
    List<GroupModel>? groups,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLatestKnown,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyGroupsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLatestKnown: isLatestKnown ?? this.isLatestKnown,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class MyGroupsController extends StateNotifier<MyGroupsState> {
  MyGroupsController(this._repository) : super(const MyGroupsState()) {
    unawaited(load());
  }

  final GroupRepository _repository;

  Future<void> load() async {
    final cached = await _repository.loadLocalGroups();
    state = state.copyWith(
      groups: cached,
      isLoading: cached.isEmpty,
      isRefreshing: true,
      isLatestKnown: cached.isNotEmpty,
      clearError: true,
    );
    try {
      final remote = await _repository.refreshRemoteGroupsAndCache();
      state = state.copyWith(
        groups: remote,
        isLoading: false,
        isRefreshing: false,
        isLatestKnown: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLatestKnown: state.groups.isNotEmpty,
        errorMessage: state.groups.isEmpty
            ? _repository.messageFromError(error)
            : 'Showing latest known groups.',
      );
    }
  }
}

final myGroupsControllerProvider =
    StateNotifierProvider<MyGroupsController, MyGroupsState>((ref) {
  return MyGroupsController(ref.read(groupRepositoryProvider));
});

final groupDetailsProvider =
    FutureProvider.family<GroupModel, String>((ref, groupId) async {
  return ref.read(groupRepositoryProvider).getGroup(groupId);
});

final groupMembersProvider =
    FutureProvider.family<List<GroupMemberModel>, String>((ref, groupId) async {
  return ref.read(groupRepositoryProvider).getMembers(groupId);
});

class GroupMutationState {
  const GroupMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.group,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final GroupModel? group;
}

class GroupMutationController extends StateNotifier<GroupMutationState> {
  GroupMutationController(this._repository) : super(const GroupMutationState());

  final GroupRepository _repository;

  Future<GroupModel?> createGroup({
    required String groupName,
    required String description,
  }) async {
    state = const GroupMutationState(isLoading: true);
    try {
      final group = await _repository.createGroup(
        groupName: groupName,
        description: description,
      );
      state = GroupMutationState(
        successMessage: 'Group created successfully',
        group: group,
      );
      return group;
    } catch (error) {
      state =
          GroupMutationState(errorMessage: _repository.messageFromError(error));
      return null;
    }
  }

  Future<GroupModel?> joinGroup({required String groupCode}) async {
    state = const GroupMutationState(isLoading: true);
    try {
      final group = await _repository.joinGroup(groupCode: groupCode);
      state = GroupMutationState(
        successMessage: 'Group joined successfully',
        group: group,
      );
      return group;
    } catch (error) {
      state =
          GroupMutationState(errorMessage: _repository.messageFromError(error));
      return null;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    state = const GroupMutationState(isLoading: true);
    try {
      await _repository.leaveGroup(groupId);
      state = const GroupMutationState(
        successMessage: 'You left the group.',
      );
      return true;
    } catch (error) {
      state =
          GroupMutationState(errorMessage: _repository.messageFromError(error));
      return false;
    }
  }

  Future<bool> removeMember({
    required String groupId,
    required GroupMemberModel member,
  }) async {
    state = const GroupMutationState(isLoading: true);
    try {
      await _repository.removeMember(groupId: groupId, member: member);
      state = GroupMutationState(
        successMessage: '${member.fullName} was removed from the group.',
      );
      return true;
    } catch (error) {
      state =
          GroupMutationState(errorMessage: _repository.messageFromError(error));
      return false;
    }
  }

  Future<bool> archiveGroup(String groupId) async {
    state = const GroupMutationState(isLoading: true);
    try {
      await _repository.archiveGroup(groupId);
      state = const GroupMutationState(
        successMessage: 'Group ended. Cached chat history remains read-only.',
      );
      return true;
    } catch (error) {
      state =
          GroupMutationState(errorMessage: _repository.messageFromError(error));
      return false;
    }
  }
}

final groupMutationControllerProvider =
    StateNotifierProvider<GroupMutationController, GroupMutationState>((ref) {
  return GroupMutationController(ref.read(groupRepositoryProvider));
});
