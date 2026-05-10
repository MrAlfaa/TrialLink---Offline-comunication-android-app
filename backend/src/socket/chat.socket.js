const { isUserActiveGroupMember } = require('../modules/groups/membership.service');
const messageService = require('../modules/messages/message.service');

const groupRoom = (groupId) => `group:${groupId}`;

const emitSocketError = (socket, code, message) => {
  socket.emit('socket_error', { code, message });
};

const registerChatSocket = (io, socket) => {
  socket.on('join_group', async (payload = {}) => {
    try {
      const { groupId } = payload;
      if (!groupId) {
        return emitSocketError(socket, 'VALIDATION_ERROR', 'Group id is required');
      }

      const isMember = await isUserActiveGroupMember(socket.user._id, groupId);
      if (!isMember) {
        return emitSocketError(socket, 'NOT_GROUP_MEMBER', 'You are not a member of this group');
      }

      socket.join(groupRoom(groupId));
      return socket.emit('group_joined', {
        groupId,
        message: 'Joined group chat',
      });
    } catch (_error) {
      return emitSocketError(socket, 'SERVER_ERROR', 'Could not join group chat');
    }
  });

  socket.on('send_group_message', async (payload = {}) => {
    try {
      const {
        clientMessageId,
        groupId,
        tripId,
        channelId,
        chatId,
        content,
        messageType = 'text',
        createdAt,
      } = payload;

      if (!clientMessageId || !groupId || !content || !content.trim()) {
        return emitSocketError(socket, 'VALIDATION_ERROR', 'Message content is required');
      }

      const result = await messageService.saveSocketMessage({
        groupId,
        userId: socket.user._id,
        clientMessageId,
        tripId,
        channelId,
        chatId,
        content,
        messageType,
        createdAt,
      });

      socket.emit('message_sent_ack', {
        clientMessageId,
        serverMessageId: result.dto.id,
        groupId,
        status: result.dto.status,
        createdAt: result.dto.createdAt,
      });

      io.to(groupRoom(groupId)).emit('new_group_message', result.dto);
    } catch (error) {
      if (error.statusCode === 404) {
        return emitSocketError(socket, 'NOT_GROUP_MEMBER', 'You are not a member of this group');
      }
      if (error.statusCode === 422) {
        return emitSocketError(socket, 'VALIDATION_ERROR', error.message);
      }
      return emitSocketError(socket, 'SERVER_ERROR', 'Could not send message');
    }
  });

  socket.on('leave_group', (payload = {}) => {
    if (payload.groupId) {
      socket.leave(groupRoom(payload.groupId));
    }
  });
};

module.exports = {
  groupRoom,
  registerChatSocket,
};
