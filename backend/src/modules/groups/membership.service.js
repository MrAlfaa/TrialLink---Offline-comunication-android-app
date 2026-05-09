const GroupMember = require('../../models/groupMember.model');

const isUserActiveGroupMember = async (userId, groupId) => {
  const membership = await GroupMember.findOne({
    groupId,
    userId,
    status: 'active',
  });

  return Boolean(membership);
};

const ensureUserActiveGroupMember = async (userId, groupId) => {
  const isMember = await isUserActiveGroupMember(userId, groupId);

  if (!isMember) {
    const error = new Error('Group not found or access denied');
    error.statusCode = 404;
    throw error;
  }
};

const getUserGroupMembership = async (userId, groupId) => {
  return GroupMember.findOne({
    groupId,
    userId,
  });
};

const ensureUserActiveGroupMembership = async (userId, groupId) => {
  const membership = await GroupMember.findOne({
    groupId,
    userId,
    status: 'active',
  });

  if (!membership) {
    const error = new Error('Group not found or access denied');
    error.statusCode = 404;
    throw error;
  }

  return membership;
};

const ensureUserCanManageMembers = async (userId, groupId) => {
  const membership = await ensureUserActiveGroupMembership(userId, groupId);
  if (!['owner', 'admin'].includes(membership.memberRole)) {
    const error = new Error('Only group owners and admins can manage members');
    error.statusCode = 403;
    throw error;
  }
  return membership;
};

module.exports = {
  isUserActiveGroupMember,
  ensureUserActiveGroupMember,
  ensureUserActiveGroupMembership,
  ensureUserCanManageMembers,
  getUserGroupMembership,
};
