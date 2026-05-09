const { isUserActiveGroupMember } = require('../modules/groups/membership.service');
const { groupRoom } = require('./chat.socket');

const floorByGroup = new Map();
const maxFloorMs = 35000;

const emitSocketError = (socket, code, message) => {
  socket.emit('socket_error', { code, message });
};

const clearFloorTimer = (floor) => {
  if (floor?.timer) clearTimeout(floor.timer);
};

const releaseFloor = (io, groupId, reason = 'release') => {
  const floor = floorByGroup.get(groupId);
  if (!floor) return;
  clearFloorTimer(floor);
  floorByGroup.delete(groupId);
  io.to(groupRoom(groupId)).emit('ptt_speaker_released', {
    groupId,
    speakerId: floor.speakerId,
    releasedAt: new Date().toISOString(),
    reason,
  });
};

const registerPttSocket = (io, socket) => {
  socket.on('ptt_request', async (payload = {}) => {
    try {
      const { groupId, clientRequestId, requestedAt } = payload;
      if (!groupId) {
        return emitSocketError(socket, 'VALIDATION_ERROR', 'Group id is required');
      }
      const isMember = await isUserActiveGroupMember(socket.user._id, groupId);
      if (!isMember) {
        return emitSocketError(socket, 'NOT_GROUP_MEMBER', 'You are not a member of this group');
      }

      const existing = floorByGroup.get(groupId);
      if (existing && existing.speakerId !== socket.user._id.toString()) {
        return socket.emit('ptt_denied', {
          groupId,
          clientRequestId,
          currentSpeakerId: existing.speakerId,
          currentSpeakerName: existing.speakerName,
          message: 'Another user is speaking',
        });
      }

      const speakerId = socket.user._id.toString();
      const speakerName = socket.user.fullName || 'TrailLink User';
      const floor = {
        speakerId,
        speakerName,
        lockedAt: new Date(),
        timer: setTimeout(() => releaseFloor(io, groupId, 'timeout'), maxFloorMs),
      };
      clearFloorTimer(existing);
      floorByGroup.set(groupId, floor);

      socket.emit('ptt_granted', {
        groupId,
        clientRequestId,
        speakerId,
        speakerName,
        grantedAt: new Date().toISOString(),
        requestedAt,
      });
      io.to(groupRoom(groupId)).emit('ptt_speaker_changed', {
        groupId,
        speakerId,
        speakerName,
        state: 'speaking',
        grantedAt: new Date().toISOString(),
      });
    } catch (_error) {
      return emitSocketError(socket, 'SERVER_ERROR', 'Could not request PTT floor');
    }
  });

  socket.on('ptt_release', (payload = {}) => {
    const { groupId } = payload;
    if (!groupId) return;
    const floor = floorByGroup.get(groupId);
    if (floor?.speakerId === socket.user._id.toString()) {
      releaseFloor(io, groupId, 'release');
    }
  });

  socket.on('disconnect', () => {
    for (const [groupId, floor] of floorByGroup.entries()) {
      if (floor.speakerId === socket.user._id.toString()) {
        releaseFloor(io, groupId, 'disconnect');
      }
    }
  });
};

module.exports = {
  registerPttSocket,
};
