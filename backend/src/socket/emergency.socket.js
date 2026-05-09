const emergencyService = require('../modules/emergency/emergency.service');
const { groupRoom } = require('./chat.socket');

const emitSocketError = (socket, code, message) => {
  socket.emit('socket_error', { code, message });
};

const registerEmergencySocket = (io, socket) => {
  socket.on('ack_emergency', async (payload = {}) => {
    try {
      const { groupId, eventId, note } = payload;
      if (!groupId || !eventId) {
        return emitSocketError(socket, 'VALIDATION_ERROR', 'Group id and emergency event id are required');
      }

      const event = await emergencyService.acknowledgeEmergency({
        groupId,
        eventId,
        userId: socket.user._id,
        note,
      });

      io.to(groupRoom(groupId)).emit('emergency_ack', {
        eventId: event.id,
        groupId,
        acknowledgedBy: {
          id: socket.user._id.toString(),
          fullName: socket.user.fullName,
        },
        acknowledgedAt: new Date().toISOString(),
      });
    } catch (error) {
      if (error.statusCode === 404) {
        return emitSocketError(socket, 'NOT_GROUP_MEMBER', 'Emergency event not found or access denied');
      }
      return emitSocketError(socket, 'SERVER_ERROR', 'Could not acknowledge emergency alert');
    }
  });
};

module.exports = {
  registerEmergencySocket,
};
