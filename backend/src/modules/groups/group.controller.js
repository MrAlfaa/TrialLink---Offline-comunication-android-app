const groupService = require('./group.service');
const { sendSuccess } = require('../../utils/response');

const createGroup = async (req, res, next) => {
  try {
    const group = await groupService.createGroup(req.body, req.user._id);
    return sendSuccess(res, 'Group created successfully', { data: { group } }, 201);
  } catch (error) {
    next(error);
  }
};

const joinGroup = async (req, res, next) => {
  try {
    const group = await groupService.joinGroup(req.body, req.user._id);
    return sendSuccess(res, 'Group joined successfully', { data: { group } });
  } catch (error) {
    next(error);
  }
};

const getMyGroups = async (req, res, next) => {
  try {
    const groups = await groupService.getMyGroups(req.user._id);
    return sendSuccess(res, 'Groups loaded successfully', { data: { groups } });
  } catch (error) {
    next(error);
  }
};

const getGroupDetails = async (req, res, next) => {
  try {
    const group = await groupService.getGroupDetails(req.params.groupId, req.user._id);
    return sendSuccess(res, 'Group loaded successfully', { data: { group } });
  } catch (error) {
    next(error);
  }
};

const getGroupMembers = async (req, res, next) => {
  try {
    const members = await groupService.getGroupMembers(req.params.groupId, req.user._id);
    return sendSuccess(res, 'Group members loaded successfully', { data: { members } });
  } catch (error) {
    next(error);
  }
};

const removeMember = async (req, res, next) => {
  try {
    const result = await groupService.removeMember({
      groupId: req.params.groupId,
      memberId: req.params.memberId,
      requesterId: req.user._id,
    });
    return sendSuccess(res, 'Group member removed', { data: result });
  } catch (error) {
    next(error);
  }
};

const leaveGroup = async (req, res, next) => {
  try {
    const result = await groupService.leaveGroup({
      groupId: req.params.groupId,
      userId: req.user._id,
    });
    return sendSuccess(res, 'Left group successfully', { data: result });
  } catch (error) {
    next(error);
  }
};

const updateMemberRole = async (req, res, next) => {
  try {
    const member = await groupService.updateMemberRole({
      groupId: req.params.groupId,
      memberId: req.params.memberId,
      requesterId: req.user._id,
      memberRole: req.body.memberRole,
    });
    return sendSuccess(res, 'Group member role updated', {
      data: { member },
    });
  } catch (error) {
    next(error);
  }
};

const archiveGroup = async (req, res, next) => {
  try {
    const result = await groupService.archiveGroup({
      groupId: req.params.groupId,
      requesterId: req.user._id,
    });
    return sendSuccess(res, 'Group archived', { data: result });
  } catch (error) {
    return next(error);
  }
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
