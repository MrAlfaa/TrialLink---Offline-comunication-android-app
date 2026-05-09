const mongoose = require('mongoose');
const Group = require('../../models/group.model');
const GroupMember = require('../../models/groupMember.model');
const { generateUniqueGroupCode } = require('../../utils/generateGroupCode');
const {
  ensureUserActiveGroupMember,
  ensureUserActiveGroupMembership,
  ensureUserCanManageMembers,
} = require('./membership.service');
const {
  emitGroupMemberLeft,
  emitGroupMemberRemoved,
  emitGroupMemberRoleChanged,
  emitGroupArchived,
} = require('../../socket/socket');

const toGroupDto = (group, extra = {}) => ({
  id: group._id.toString(),
  groupName: group.groupName,
  description: group.description,
  groupCode: group.groupCode,
  createdBy: group.createdBy?.toString?.() || group.createdBy,
  status: group.status,
  createdAt: group.createdAt,
  updatedAt: group.updatedAt,
  ...extra,
});

const ensureMember = async (groupId, userId) => {
  return ensureUserActiveGroupMember(userId, groupId);
};

const createGroup = async ({ groupName, description }, userId) => {
  const session = await mongoose.startSession();

  try {
    let createdGroup;
    await session.withTransaction(async () => {
      const groupCode = await generateUniqueGroupCode(Group);
      const [group] = await Group.create(
        [
          {
            groupName,
            description: description || '',
            groupCode,
            createdBy: userId,
          },
        ],
        { session },
      );

      await GroupMember.create(
        [
          {
            groupId: group._id,
            userId,
            memberRole: 'owner',
            status: 'active',
          },
        ],
        { session },
      );

      createdGroup = group;
    });

    return toGroupDto(createdGroup);
  } finally {
    await session.endSession();
  }
};

const joinGroup = async ({ groupCode }, userId) => {
  const group = await Group.findOne({
    groupCode: groupCode.toUpperCase(),
    status: 'active',
  });

  if (!group) {
    const error = new Error('Group not found');
    error.statusCode = 404;
    throw error;
  }

  const existing = await GroupMember.findOne({
    groupId: group._id,
    userId,
  });

  if (existing?.status === 'active') {
    const error = new Error('You are already a member of this group');
    error.statusCode = 409;
    throw error;
  }

  if (existing) {
    existing.status = 'active';
    existing.memberRole = 'member';
    existing.joinedAt = new Date();
    await existing.save();
  } else {
    await GroupMember.create({
      groupId: group._id,
      userId,
      memberRole: 'member',
      status: 'active',
    });
  }

  return toGroupDto(group);
};

const getMyGroups = async (userId) => {
  const memberships = await GroupMember.find({
    userId,
    status: 'active',
  })
    .populate('groupId')
    .sort({ joinedAt: -1 });

  const groups = await Promise.all(
    memberships
      .filter((membership) => membership.groupId)
      .map(async (membership) => {
        const memberCount = await GroupMember.countDocuments({
          groupId: membership.groupId._id,
          status: 'active',
        });

        return toGroupDto(membership.groupId, {
          memberRole: membership.memberRole,
          joinedAt: membership.joinedAt,
          memberCount,
        });
      }),
  );

  return groups;
};

const getGroupDetails = async (groupId, userId) => {
  await ensureMember(groupId, userId);
  const group = await Group.findOne({ _id: groupId, status: 'active' });

  if (!group) {
    const error = new Error('Group not found');
    error.statusCode = 404;
    throw error;
  }

  const memberCount = await GroupMember.countDocuments({
    groupId,
    status: 'active',
  });

  return toGroupDto(group, { memberCount });
};

const getGroupMembers = async (groupId, userId) => {
  await ensureMember(groupId, userId);

  const members = await GroupMember.find({
    groupId,
  })
    .populate('userId', 'fullName email avatarUrl')
    .sort({ joinedAt: 1 });

  return members.map((member) => ({
    id: member._id.toString(),
    groupId: member.groupId.toString(),
    userId: member.userId?._id?.toString?.() || member.userId?.toString?.(),
    fullName: member.userId?.fullName || 'TrailLink User',
    email: member.userId?.email || '',
    avatarUrl: member.userId?.avatarUrl || null,
    memberRole: member.memberRole,
    membershipStatus: member.status,
    presenceStatus: 'offline',
    source: 'backend',
    joinedAt: member.joinedAt,
    createdAt: member.createdAt,
    updatedAt: member.updatedAt,
  }));
};

const removeMember = async ({ groupId, memberId, requesterId }) => {
  const requester = await ensureUserCanManageMembers(requesterId, groupId);
  const target = await GroupMember.findOne({ _id: memberId, groupId }).populate(
    'userId',
    'fullName email avatarUrl',
  );

  if (!target || target.status !== 'active') {
    const error = new Error('Group member not found');
    error.statusCode = 404;
    throw error;
  }

  if (target.userId._id.toString() === requesterId.toString()) {
    const error = new Error('Use Leave Group to leave your own membership');
    error.statusCode = 400;
    throw error;
  }

  if (target.memberRole === 'owner') {
    const error = new Error('Group owners cannot be removed by this action');
    error.statusCode = 403;
    throw error;
  }

  if (requester.memberRole === 'admin' && target.memberRole === 'admin') {
    const error = new Error('Admins cannot remove other admins');
    error.statusCode = 403;
    throw error;
  }

  target.status = 'removed';
  await target.save();

  const payload = {
    groupId,
    memberId: target._id.toString(),
    userId: target.userId._id.toString(),
    membershipStatus: target.status,
    removedBy: requesterId.toString(),
    removedAt: new Date().toISOString(),
  };
  emitGroupMemberRemoved(groupId, payload);
  return payload;
};

const leaveGroup = async ({ groupId, userId }) => {
  const membership = await ensureUserActiveGroupMembership(userId, groupId);

  if (membership.memberRole === 'owner') {
    const ownerCount = await GroupMember.countDocuments({
      groupId,
      memberRole: 'owner',
      status: 'active',
    });
    if (ownerCount <= 1) {
      const error = new Error(
        'The only owner cannot leave the group. Transfer ownership first.',
      );
      error.statusCode = 400;
      throw error;
    }
  }

  membership.status = 'left';
  await membership.save();

  const payload = {
    groupId,
    memberId: membership._id.toString(),
    userId: userId.toString(),
    membershipStatus: membership.status,
    leftAt: new Date().toISOString(),
  };
  emitGroupMemberLeft(groupId, payload);
  return payload;
};

const updateMemberRole = async ({ groupId, memberId, requesterId, memberRole }) => {
  const requester = await ensureUserActiveGroupMembership(requesterId, groupId);
  if (requester.memberRole !== 'owner') {
    const error = new Error('Only group owners can change member roles');
    error.statusCode = 403;
    throw error;
  }

  const target = await GroupMember.findOne({ _id: memberId, groupId }).populate(
    'userId',
    'fullName email avatarUrl',
  );
  if (!target || target.status !== 'active') {
    const error = new Error('Group member not found');
    error.statusCode = 404;
    throw error;
  }
  if (target.userId._id.toString() === requesterId.toString()) {
    const error = new Error('Owners cannot change their own role here');
    error.statusCode = 400;
    throw error;
  }
  if (target.memberRole === 'owner') {
    const error = new Error('Owner role cannot be changed here');
    error.statusCode = 400;
    throw error;
  }

  target.memberRole = memberRole;
  await target.save();
  const dto = {
    id: target._id.toString(),
    groupId: target.groupId.toString(),
    userId: target.userId._id.toString(),
    fullName: target.userId.fullName,
    email: target.userId.email,
    avatarUrl: target.userId.avatarUrl,
    memberRole: target.memberRole,
    membershipStatus: target.status,
    presenceStatus: 'offline',
    source: 'backend',
    joinedAt: target.joinedAt,
    createdAt: target.createdAt,
    updatedAt: target.updatedAt,
  };
  emitGroupMemberRoleChanged(groupId, dto);
  return dto;
};

const archiveGroup = async ({ groupId, requesterId }) => {
  const requester = await ensureUserActiveGroupMembership(requesterId, groupId);
  if (requester.memberRole !== 'owner') {
    const error = new Error('Only group owners can archive this group');
    error.statusCode = 403;
    throw error;
  }

  const group = await Group.findOne({ _id: groupId, status: 'active' });
  if (!group) {
    const error = new Error('Group not found');
    error.statusCode = 404;
    throw error;
  }

  group.status = 'archived';
  await group.save();
  await GroupMember.updateMany(
    { groupId, status: 'active' },
    { $set: { status: 'removed' } },
  );

  const payload = {
    groupId: group._id.toString(),
    status: 'archived',
    archivedBy: requesterId.toString(),
    archivedAt: new Date().toISOString(),
  };
  emitGroupArchived(groupId, payload);
  return payload;
};

module.exports = {
  createGroup,
  joinGroup,
  getMyGroups,
  getGroupDetails,
  getGroupMembers,
  leaveGroup,
  removeMember,
  updateMemberRole,
  archiveGroup,
};
