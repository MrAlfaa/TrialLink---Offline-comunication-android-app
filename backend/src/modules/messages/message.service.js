const Message = require('../../models/message.model');
const { ensureUserActiveGroupMember } = require('../groups/membership.service');

const toMessageDto = (message) => {
  const sender = message.senderId;

  return {
    id: message._id.toString(),
    clientMessageId: message.clientMessageId,
    groupId: message.groupId?.toString?.() || message.groupId,
    tripId: message.tripId || null,
    channelId: message.channelId || null,
    chatId: message.chatId || null,
    sender: {
      id: sender?._id?.toString?.() || sender?.toString?.() || message.senderId.toString(),
      fullName: sender?.fullName || 'TrailLink User',
      email: sender?.email || '',
    },
    messageType: message.messageType,
    content: message.content,
    mediaUrl: message.mediaUrl || null,
    fileName: message.fileName || null,
    fileSizeBytes: message.fileSizeBytes || null,
    mimeType: message.mimeType || null,
    durationMs: message.durationMs || null,
    thumbnailUrl: message.thumbnailUrl || null,
    status: message.status,
    sourcePath: message.sourcePath || 'online',
    originLocalId: message.originLocalId || null,
    originDisplayName: message.originDisplayName || null,
    originBackendId: message.originBackendId?.toString?.() || null,
    originIdentityType: message.originIdentityType || null,
    bridgedBy: message.bridgedBy?.toString?.() || null,
    bridgedByLocalId: message.bridgedByLocalId || null,
    bridgedByName: message.bridgedByName || null,
    bridgedAt: message.bridgedAt || null,
    originalPacketId: message.originalPacketId || null,
    channelCode: message.channelCode || null,
    createdAt: message.createdAt,
    updatedAt: message.updatedAt,
  };
};

const bridgeFieldsFrom = (item = {}, userId) => {
  if (item.sourcePath !== 'bridge') return { sourcePath: item.sourcePath || 'online' };
  return {
    sourcePath: 'bridge',
    originLocalId: item.originLocalId,
    originDisplayName: item.originDisplayName,
    originBackendId: item.originBackendId || undefined,
    originIdentityType: item.originIdentityType,
    bridgedBy: item.bridgedBy || userId,
    bridgedByLocalId: item.bridgedByLocalId,
    bridgedByName: item.bridgedByName,
    bridgedAt: item.bridgedAt ? new Date(item.bridgedAt) : new Date(),
    originalPacketId: item.originalPacketId,
    channelCode: item.channelCode,
  };
};

const contextFieldsFrom = (item = {}) => ({
  tripId: item.tripId || undefined,
  channelId: item.channelId || undefined,
  chatId: item.chatId || undefined,
});

const getMessages = async ({ groupId, userId, page = 1, limit = 30, before }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const numericPage = Math.max(Number.parseInt(page, 10) || 1, 1);
  const numericLimit = Math.min(Math.max(Number.parseInt(limit, 10) || 30, 1), 100);
  const query = { groupId };

  if (before) {
    query.createdAt = { $lt: new Date(before) };
  }

  const newest = await Message.find(query)
    .populate('senderId', 'fullName email')
    .sort({ createdAt: -1 })
    .skip((numericPage - 1) * numericLimit)
    .limit(numericLimit + 1);

  const hasMore = newest.length > numericLimit;
  const pageItems = hasMore ? newest.slice(0, numericLimit) : newest;
  const messages = pageItems.reverse().map(toMessageDto);

  return {
    messages,
    pagination: {
      page: numericPage,
      limit: numericLimit,
      hasMore,
    },
  };
};

const createOrFindMessage = async ({
  groupId,
  userId,
  clientMessageId,
  content,
  messageType = 'text',
  createdAt,
  contextMetadata = {},
  bridgeMetadata = {},
  media = {},
}) => {
  const bridgeQuery =
    bridgeMetadata.sourcePath === 'bridge' && bridgeMetadata.originLocalId
      ? { clientMessageId, originLocalId: bridgeMetadata.originLocalId, sourcePath: 'bridge' }
      : null;
  const existing = await Message.findOne(
    bridgeQuery || { clientMessageId, senderId: userId },
  ).populate('senderId', 'fullName email');

  if (existing) {
    return { message: existing, created: false };
  }

  const message = await Message.create({
    clientMessageId,
    groupId,
    senderId: userId,
    messageType,
    content: (content || '').trim(),
    status: 'sent',
    ...contextMetadata,
    ...media,
    ...bridgeMetadata,
    ...(createdAt ? { createdAt: new Date(createdAt) } : {}),
  });

  await message.populate('senderId', 'fullName email');
  return { message, created: true };
};

const validateMediaInput = ({ messageType, body, file }) => {
  if (!['image', 'voice', 'file'].includes(messageType)) {
    const error = new Error('Unsupported media message type');
    error.statusCode = 422;
    throw error;
  }
  if (messageType === 'file') {
    const error = new Error('File attachments are not enabled yet');
    error.statusCode = 422;
    throw error;
  }
  if (!file) {
    const error = new Error('Media file is required');
    error.statusCode = 422;
    throw error;
  }
  if (messageType === 'image' && !file.mimetype.startsWith('image/')) {
    const error = new Error('Only image files are allowed');
    error.statusCode = 422;
    throw error;
  }
  if (messageType === 'voice' && !file.mimetype.startsWith('audio/')) {
    const error = new Error('Only audio files are allowed');
    error.statusCode = 422;
    throw error;
  }
  if (messageType === 'voice' && file.size > 2 * 1024 * 1024) {
    const error = new Error('Voice file is too large');
    error.statusCode = 422;
    throw error;
  }
  if (messageType === 'image' && file.size > 8 * 1024 * 1024) {
    const error = new Error('Image file is too large');
    error.statusCode = 422;
    throw error;
  }
  const durationMs = body.durationMs == null ? undefined : Number(body.durationMs);
  if (messageType === 'voice' && (!Number.isFinite(durationMs) || durationMs > 30000)) {
    const error = new Error('Voice notes must include durationMs up to 30000');
    error.statusCode = 422;
    throw error;
  }
  return { durationMs };
};

const saveSocketMessage = async ({
  groupId,
  userId,
  clientMessageId,
  content,
  messageType,
  createdAt,
  tripId,
  channelId,
  chatId,
}) => {
  await ensureUserActiveGroupMember(userId, groupId);

  if (messageType && messageType !== 'text') {
    const error = new Error('Media messages must use the media upload endpoint');
    error.statusCode = 422;
    throw error;
  }

  if (!content || !content.trim()) {
    const error = new Error('Message content is required');
    error.statusCode = 422;
    throw error;
  }

  if (content.trim().length > 2000) {
    const error = new Error('Message content is too long');
    error.statusCode = 422;
    throw error;
  }

  const result = await createOrFindMessage({
    groupId,
    userId,
    clientMessageId,
    content,
    messageType,
    createdAt,
    contextMetadata: contextFieldsFrom({ tripId, channelId, chatId }),
  });

  return {
    ...result,
    dto: toMessageDto(result.message),
  };
};

const saveMediaMessage = async ({ groupId, userId, body, file }) => {
  await ensureUserActiveGroupMember(userId, groupId);
  const messageType = body.messageType;
  const { durationMs } = validateMediaInput({ messageType, body, file });
  const result = await createOrFindMessage({
    groupId,
    userId,
    clientMessageId: body.clientMessageId,
    content: body.content || (messageType === 'image' ? 'Image' : 'Voice note'),
    messageType,
    createdAt: body.createdAt,
    contextMetadata: contextFieldsFrom(body),
    media: {
      mediaUrl: `/uploads/chat-media/${file.filename}`,
      fileName: file.originalname || file.filename,
      fileSizeBytes: file.size,
      mimeType: file.mimetype,
      durationMs,
    },
  });

  return {
    ...result,
    dto: toMessageDto(result.message),
  };
};

const syncMessages = async ({ groupId, userId, messages }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const syncedMessages = [];
  const createdMessages = [];

  for (const item of messages) {
    const result = await createOrFindMessage({
      groupId,
      userId,
      clientMessageId: item.clientMessageId,
      content: item.content,
      messageType: item.messageType || 'text',
      createdAt: item.createdAt,
      contextMetadata: contextFieldsFrom(item),
      bridgeMetadata: bridgeFieldsFrom(item, userId),
    });

    syncedMessages.push({
      clientMessageId: result.message.clientMessageId,
      serverMessageId: result.message._id.toString(),
      status: result.message.status,
      createdAt: result.message.createdAt,
    });

    if (result.created) {
      createdMessages.push(toMessageDto(result.message));
    }
  }

  return { syncedMessages, createdMessages };
};

module.exports = {
  bridgeFieldsFrom,
  contextFieldsFrom,
  getMessages,
  saveSocketMessage,
  saveMediaMessage,
  syncMessages,
  toMessageDto,
};
