const express = require('express');
const groupController = require('./group.controller');
const messageRoutes = require('../messages/message.routes');
const emergencyRoutes = require('../emergency/emergency.routes');
const locationRoutes = require('../location/location.routes');
const voiceRoutes = require('../voice/voice.routes');
const {
  createGroupValidation,
  groupIdValidation,
  joinGroupValidation,
  memberIdValidation,
  updateMemberRoleValidation,
  validate,
} = require('./group.validation');
const { authenticate } = require('../../middleware/auth.middleware');

const router = express.Router();

router.use(authenticate);

router.post('/', createGroupValidation, validate, groupController.createGroup);
router.get('/my', groupController.getMyGroups);
router.post('/join', joinGroupValidation, validate, groupController.joinGroup);
router.delete('/:groupId', groupIdValidation, validate, groupController.archiveGroup);
router.use('/:groupId/messages', messageRoutes);
router.use('/:groupId/emergency', emergencyRoutes);
router.use('/:groupId/locations', locationRoutes);
router.use('/:groupId/voice-notes', voiceRoutes);
router.get('/:groupId', groupIdValidation, validate, groupController.getGroupDetails);
router.get('/:groupId/members', groupIdValidation, validate, groupController.getGroupMembers);
router.post('/:groupId/leave', groupIdValidation, validate, groupController.leaveGroup);
router.delete(
  '/:groupId/members/:memberId',
  memberIdValidation,
  validate,
  groupController.removeMember,
);
router.patch(
  '/:groupId/members/:memberId/role',
  updateMemberRoleValidation,
  validate,
  groupController.updateMemberRole,
);

module.exports = router;
