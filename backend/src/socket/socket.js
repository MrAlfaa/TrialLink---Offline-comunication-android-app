const { Server } = require('socket.io');
const { authenticateSocket } = require('./socket.auth');
const { groupRoom, registerChatSocket } = require('./chat.socket');
const { registerEmergencySocket } = require('./emergency.socket');
const { registerPttSocket } = require('./ptt.socket');

let ioInstance;

const initializeSocket = (httpServer) => {
  const io = new Server(httpServer, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  io.use(authenticateSocket);

  io.on('connection', (socket) => {
    registerChatSocket(io, socket);
    registerEmergencySocket(io, socket);
    registerPttSocket(io, socket);
  });

  ioInstance = io;
  return io;
};

const getIo = () => ioInstance;

const emitGroupMessage = (groupId, message) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('new_group_message', message);
};

const emitEmergencyAlert = (groupId, event) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('emergency_alert', event);
};

const emitEmergencyAck = (groupId, payload) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('emergency_ack', payload);
};

const emitEmergencyResolved = (groupId, payload) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('emergency_resolved', payload);
};

const emitLocationUpdate = (groupId, location) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('location_update', location);
};

const emitVoiceNoteReceived = (groupId, voiceNote) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('voice_note_received', voiceNote);
};

const emitGroupMemberRemoved = (groupId, payload) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('group_member_removed', payload);
};

const emitGroupMemberLeft = (groupId, payload) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('group_member_left', payload);
};

const emitGroupMemberRoleChanged = (groupId, payload) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('group_member_role_changed', payload);
};

const emitGroupArchived = (groupId, payload) => {
  const io = getIo();
  if (!io) return;
  io.to(groupRoom(groupId)).emit('group_archived', payload);
};

module.exports = {
  initializeSocket,
  emitEmergencyAck,
  emitEmergencyAlert,
  emitEmergencyResolved,
  emitGroupMessage,
  emitLocationUpdate,
  emitVoiceNoteReceived,
  emitGroupMemberLeft,
  emitGroupMemberRemoved,
  emitGroupMemberRoleChanged,
  emitGroupArchived,
  getIo,
};
