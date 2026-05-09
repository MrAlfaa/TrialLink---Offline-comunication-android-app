const EmergencyEvent = require('../../models/emergencyEvent.model');
const Group = require('../../models/group.model');
const GroupMember = require('../../models/groupMember.model');
const { ensureUserActiveGroupMember } = require('../groups/membership.service');

const toEmergencyDto = (event) => {
  const sender = event.senderId;

  return {
    id: event._id.toString(),
    clientEventId: event.clientEventId,
    groupId: event.groupId?.toString?.() || event.groupId,
    sender: {
      id: sender?._id?.toString?.() || sender?.toString?.() || event.senderId.toString(),
      fullName: sender?.fullName || 'TrailLink User',
    },
    alertType: event.alertType,
    message: event.message || '',
    priority: event.priority,
    location: event.location || null,
    status: event.status,
    acknowledgements: (event.acknowledgements || []).map((ack) => ({
      userId: ack.userId?.toString?.() || ack.userId,
      acknowledgedAt: ack.acknowledgedAt,
      note: ack.note || '',
    })),
    sourcePath: event.sourcePath || 'online',
    originLocalId: event.originLocalId || null,
    originDisplayName: event.originDisplayName || null,
    originBackendId: event.originBackendId?.toString?.() || null,
    originIdentityType: event.originIdentityType || null,
    bridgedBy: event.bridgedBy?.toString?.() || null,
    bridgedByLocalId: event.bridgedByLocalId || null,
    bridgedByName: event.bridgedByName || null,
    bridgedAt: event.bridgedAt || null,
    originalPacketId: event.originalPacketId || null,
    channelCode: event.channelCode || null,
    createdAt: event.createdAt,
    updatedAt: event.updatedAt,
  };
};

const bridgeFieldsFrom = (body = {}, userId) => {
  if (body.sourcePath !== 'bridge') return { sourcePath: body.sourcePath || 'online' };
  return {
    sourcePath: 'bridge',
    originLocalId: body.originLocalId,
    originDisplayName: body.originDisplayName,
    originBackendId: body.originBackendId || undefined,
    originIdentityType: body.originIdentityType,
    bridgedBy: body.bridgedBy || userId,
    bridgedByLocalId: body.bridgedByLocalId,
    bridgedByName: body.bridgedByName,
    bridgedAt: body.bridgedAt ? new Date(body.bridgedAt) : new Date(),
    originalPacketId: body.originalPacketId,
    channelCode: body.channelCode,
  };
};

const normalizeLocation = (location) => {
  if (!location || location.latitude == null || location.longitude == null) return undefined;
  return {
    latitude: Number(location.latitude),
    longitude: Number(location.longitude),
    accuracy: location.accuracy == null ? undefined : Number(location.accuracy),
    capturedAt: location.capturedAt ? new Date(location.capturedAt) : new Date(),
  };
};

const createOrFindEmergency = async ({
  groupId,
  userId,
  clientEventId,
  alertType = 'sos',
  message = '',
  location,
  createdAt,
  bridgeMetadata = {},
}) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const bridgeQuery =
    bridgeMetadata.sourcePath === 'bridge' && bridgeMetadata.originLocalId
      ? { clientEventId, originLocalId: bridgeMetadata.originLocalId, sourcePath: 'bridge' }
      : null;
  const existing = await EmergencyEvent.findOne(
    bridgeQuery || { clientEventId, senderId: userId },
  ).populate('senderId', 'fullName email');
  if (existing) {
    return { event: existing, created: false };
  }

  const trimmedMessage = (message || '').trim();
  if (trimmedMessage.length > 500) {
    const error = new Error('Emergency message is too long');
    error.statusCode = 422;
    throw error;
  }

  const event = await EmergencyEvent.create({
    clientEventId,
    groupId,
    senderId: userId,
    alertType,
    message: trimmedMessage,
    priority: 'emergency',
    location: normalizeLocation(location),
    ...bridgeMetadata,
    ...(createdAt ? { createdAt: new Date(createdAt) } : {}),
  });
  await event.populate('senderId', 'fullName email');
  return { event, created: true };
};

const listEmergencies = async ({ groupId, userId, status, limit = 20 }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const query = { groupId };
  if (status) query.status = status;
  const numericLimit = Math.min(Math.max(Number.parseInt(limit, 10) || 20, 1), 100);

  const events = await EmergencyEvent.find(query)
    .populate('senderId', 'fullName email')
    .sort({ createdAt: -1 })
    .limit(numericLimit);

  return events.map(toEmergencyDto);
};

const acknowledgeEmergency = async ({ groupId, eventId, userId, note = '' }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const event = await EmergencyEvent.findOne({ _id: eventId, groupId });
  if (!event) {
    const error = new Error('Emergency event not found');
    error.statusCode = 404;
    throw error;
  }

  const alreadyAcknowledged = event.acknowledgements.some(
    (ack) => ack.userId.toString() === userId.toString(),
  );
  if (!alreadyAcknowledged) {
    event.acknowledgements.push({
      userId,
      acknowledgedAt: new Date(),
      note: (note || '').trim(),
    });
  }
  if (event.status === 'active') event.status = 'acknowledged';
  event.updatedAt = new Date();
  await event.save();
  await event.populate('senderId', 'fullName email');
  return toEmergencyDto(event);
};

const resolveEmergency = async ({ groupId, eventId, userId }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const event = await EmergencyEvent.findOne({ _id: eventId, groupId });
  if (!event) {
    const error = new Error('Emergency event not found');
    error.statusCode = 404;
    throw error;
  }

  const group = await Group.findById(groupId);
  const membership = await GroupMember.findOne({ groupId, userId, status: 'active' });
  const canResolve =
    event.senderId.toString() === userId.toString() ||
    group?.createdBy?.toString?.() === userId.toString() ||
    ['owner', 'admin'].includes(membership?.memberRole);

  if (!canResolve) {
    const error = new Error('Only the sender or group owner can resolve this emergency');
    error.statusCode = 403;
    throw error;
  }

  event.status = 'resolved';
  event.updatedAt = new Date();
  await event.save();
  await event.populate('senderId', 'fullName email');
  return toEmergencyDto(event);
};

module.exports = {
  acknowledgeEmergency,
  bridgeFieldsFrom,
  createOrFindEmergency,
  listEmergencies,
  resolveEmergency,
  toEmergencyDto,
};
