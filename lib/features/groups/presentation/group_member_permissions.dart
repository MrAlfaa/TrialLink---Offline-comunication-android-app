import '../data/models/group_member_model.dart';

class GroupMemberPermissions {
  const GroupMemberPermissions._();

  static bool canManageMembers(String? requesterRole) {
    return requesterRole == 'owner' || requesterRole == 'admin';
  }

  static bool canRemoveMember({
    required String? requesterRole,
    required String? requesterUserId,
    required GroupMemberModel member,
  }) {
    if (!canManageMembers(requesterRole)) return false;
    if (member.membershipStatus != 'active') return false;
    if (member.userId.isNotEmpty && member.userId == requesterUserId) {
      return false;
    }
    if (member.memberRole == 'owner') return false;
    return true;
  }
}
