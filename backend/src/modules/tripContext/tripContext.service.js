const crypto = require('crypto');

const ChatRoom = require('../../models/chatRoom.model');
const Group = require('../../models/group.model');
const GroupMember = require('../../models/groupMember.model');
const MemberDeviceProfile = require('../../models/memberDeviceProfile.model');
const Trip = require('../../models/trip.model');
const TripChannel = require('../../models/tripChannel.model');
const User = require('../../models/user.model');
const { generateUniqueGroupCode } = require('../../utils/generateGroupCode');

const parseDate = (value) => (value ? new Date(value) : undefined);

const tripDto = (trip) => ({
  tripId: trip.tripId,
  tripName: trip.tripName,
  status: trip.status,
  mode: trip.mode,
  activeChannelId: trip.activeChannelId || null,
  primaryChannelId: trip.primaryChannelId || trip.activeChannelId || null,
  cloudGroupId: trip.cloudGroupId || null,
  ownerUserId: trip.ownerUserId || null,
  offlineBackupReady: Boolean(trip.offlineBackupReady),
  cloudPreparedAt: trip.cloudPreparedAt || null,
  lastOpenedAt: trip.lastOpenedAt || null,
  createdAt: trip.createdAt,
  updatedAt: trip.updatedAt,
});

const channelDto = (channel) => ({
  channelId: channel.channelId,
  tripId: channel.tripId,
  channelName: channel.channelName,
  channelCode: channel.channelCode,
  channelKeyHash: channel.channelKeyHash || null,
  isPrimary: channel.isPrimary,
  isActive: channel.isActive,
  channelStatus: channel.channelStatus,
  createdAt: channel.createdAt,
  updatedAt: channel.updatedAt,
});

const chatRoomDto = (chatRoom) => ({
  chatId: chatRoom.chatId,
  tripId: chatRoom.tripId,
  channelId: chatRoom.channelId || null,
  cloudGroupId: chatRoom.cloudGroupId || null,
  chatName: chatRoom.chatName,
  chatType: chatRoom.chatType,
  isDefault: chatRoom.isDefault,
  isActive: chatRoom.isActive,
  chatStatus: chatRoom.chatStatus,
  createdAt: chatRoom.createdAt,
  updatedAt: chatRoom.updatedAt,
});

const memberDeviceDto = (profile) => ({
  userId: profile.userId?.toString?.() || profile.userId,
  publicUserId: profile.publicUserId || null,
  localUserId: profile.localUserId || null,
  appDeviceId: profile.appDeviceId,
  displayName: profile.displayName,
  phoneNumber: profile.phoneNumber || null,
  capabilities: profile.capabilities || {},
  lastSeenAt: profile.lastSeenAt || null,
  tripId: profile.tripId,
  channelId: profile.channelId,
  cloudGroupId: profile.cloudGroupId,
});

const normalizeTrip = (item = {}) => ({
  tripId: item.tripId,
  tripName: item.tripName || item.name || 'TrailLink Trip',
  status: item.status || 'inactive',
  mode: item.mode || 'offline',
  activeChannelId: item.activeChannelId || item.offlineChannelId || undefined,
  primaryChannelId: item.primaryChannelId || item.activeChannelId || item.offlineChannelId || undefined,
  cloudGroupId: item.cloudGroupId || undefined,
  ownerUserId: item.ownerUserId || undefined,
  offlineBackupReady: item.offlineBackupReady === true || item.offlineBackupReady === 1,
  cloudPreparedAt: parseDate(item.cloudPreparedAt),
  lastOpenedAt: parseDate(item.lastOpenedAt),
  clientCreatedAt: parseDate(item.createdAt),
  clientUpdatedAt: parseDate(item.updatedAt),
});

const normalizeChannel = (item = {}) => ({
  channelId: item.channelId,
  tripId: item.tripId,
  channelName: item.channelName || item.name || 'Main Team Channel',
  channelCode: item.channelCode,
  channelKeyHash: item.channelKeyHash || undefined,
  isPrimary: item.isPrimary === true || item.isPrimary === 1,
  isActive: item.isActive === true || item.isActive === 1,
  channelStatus: item.channelStatus || item.status || 'active',
  clientCreatedAt: parseDate(item.createdAt),
  clientUpdatedAt: parseDate(item.updatedAt),
});

const normalizeChatRoom = (item = {}) => ({
  chatId: item.chatId,
  tripId: item.tripId,
  channelId: item.channelId || undefined,
  cloudGroupId: item.cloudGroupId || undefined,
  chatName: item.chatName || item.name || 'General',
  chatType: item.chatType || 'offline_channel',
  isDefault: item.isDefault === true || item.isDefault === 1,
  isActive: item.isActive === true || item.isActive === 1,
  chatStatus: item.chatStatus || item.status || 'active',
  clientCreatedAt: parseDate(item.createdAt),
  clientUpdatedAt: parseDate(item.updatedAt),
});

const normalizeCapabilities = (capabilities = {}) => ({
  supportsNearby: capabilities.supportsNearby !== false,
  supportsPtt: capabilities.supportsPtt === true,
  supportsLiveRadio: capabilities.supportsLiveRadio === true,
});

const buildChannelKeyHash = ({ groupId, channelCode }) => crypto
  .createHash('sha256')
  .update(`${groupId}:${channelCode}:${process.env.JWT_SECRET || 'traillink'}`)
  .digest('hex');

const preparedPayload = ({ trip, channel, chatRoom, group, roster }) => ({
  trip: tripDto(trip),
  channel: channelDto(channel),
  chatRoom: chatRoomDto(chatRoom),
  group: {
    id: group._id.toString(),
    groupName: group.groupName,
    groupCode: group.groupCode,
    status: group.status,
    createdBy: group.createdBy?.toString?.() || group.createdBy,
  },
  roster: roster.map(memberDeviceDto),
  offlineBackupReady: true,
});

const ensureCloudPreparedGroup = async ({ tripName, description, userId, session }) => {
  const groupCode = await generateUniqueGroupCode(Group);
  const [group] = await Group.create(
    [
      {
        groupName: tripName,
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
  return group;
};

const findPreparedSource = ({ cloudGroupId }) => {
  return Trip.findOne({
    cloudGroupId,
    offlineBackupReady: true,
  }).sort({ cloudPreparedAt: 1, createdAt: 1 });
};

const ensurePreparedContextForUser = async ({
  userId,
  ownerUserId,
  group,
  tripId,
  tripName,
  channelId,
  channelCode,
  channelKeyHash,
  chatId,
  active = true,
  session,
}) => {
  const now = new Date();
  if (active) {
    await Trip.updateMany(
      { ownerId: userId, tripId: { $ne: tripId }, status: 'active' },
      { $set: { status: 'inactive' } },
      { session },
    );
  }
  const trip = await Trip.findOneAndUpdate(
    { ownerId: userId, tripId },
    {
      $set: {
        ownerId: userId,
        tripId,
        tripName,
        status: active ? 'active' : 'inactive',
        mode: 'hybrid',
        activeChannelId: channelId,
        primaryChannelId: channelId,
        cloudGroupId: group._id.toString(),
        ownerUserId: ownerUserId.toString(),
        offlineBackupReady: true,
        cloudPreparedAt: now,
        lastOpenedAt: now,
        clientUpdatedAt: now,
      },
      $setOnInsert: {
        clientCreatedAt: now,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );
  const channel = await TripChannel.findOneAndUpdate(
    { ownerId: userId, channelId },
    {
      $set: {
        ownerId: userId,
        channelId,
        tripId,
        channelName: 'Main Team Channel',
        channelCode,
        channelKeyHash,
        isPrimary: true,
        isActive: active,
        channelStatus: active ? 'active' : 'inactive',
        clientUpdatedAt: now,
      },
      $setOnInsert: {
        clientCreatedAt: now,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );
  const chatRoom = await ChatRoom.findOneAndUpdate(
    { ownerId: userId, chatId },
    {
      $set: {
        ownerId: userId,
        chatId,
        tripId,
        channelId,
        cloudGroupId: group._id.toString(),
        chatName: 'General',
        chatType: 'offline_channel',
        isDefault: true,
        isActive: active,
        chatStatus: 'active',
        clientUpdatedAt: now,
      },
      $setOnInsert: {
        clientCreatedAt: now,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );
  return { trip, channel, chatRoom };
};

const upsertMemberDeviceProfile = async ({
  userId,
  tripId,
  channelId,
  cloudGroupId,
  localUserId,
  appDeviceId,
  capabilities,
  session,
}) => {
  const user = await User.findById(userId).session(session);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }
  const safeAppDeviceId = (appDeviceId || '').trim();
  if (!safeAppDeviceId) {
    const error = new Error('App device id is required');
    error.statusCode = 422;
    throw error;
  }
  return MemberDeviceProfile.findOneAndUpdate(
    { tripId, userId, appDeviceId: safeAppDeviceId },
    {
      $set: {
        tripId,
        channelId,
        cloudGroupId,
        userId,
        publicUserId: user.publicUserId || null,
        localUserId: localUserId || user.localUserId || user.bootstrapLocalUserId || null,
        appDeviceId: safeAppDeviceId,
        displayName: user.displayName || user.fullName || 'TrailLink User',
        phoneNumber: user.phoneNumber || null,
        capabilities: normalizeCapabilities(capabilities),
        lastSeenAt: new Date(),
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true, session },
  );
};

const rosterForTrip = (tripId) => MemberDeviceProfile.find({ tripId }).sort({ displayName: 1, lastSeenAt: -1 });

const createCloudPreparedTrip = async ({
  userId,
  tripName,
  description,
  localUserId,
  appDeviceId,
  capabilities,
}) => {
  const session = await Trip.startSession();
  try {
    let result;
    await session.withTransaction(async () => {
      const group = await ensureCloudPreparedGroup({
        tripName,
        description,
        userId,
        session,
      });
      const tripId = `trip_${crypto.randomUUID()}`;
      const channelId = `channel_${crypto.randomUUID()}`;
      const chatId = `chat_${tripId}_${channelId}`;
      const channelCode = group.groupCode;
      const channelKeyHash = buildChannelKeyHash({
        groupId: group._id.toString(),
        channelCode,
      });
      const context = await ensurePreparedContextForUser({
        userId,
        ownerUserId: userId,
        group,
        tripId,
        tripName,
        channelId,
        channelCode,
        channelKeyHash,
        chatId,
        session,
      });
      await upsertMemberDeviceProfile({
        userId,
        tripId,
        channelId,
        cloudGroupId: group._id.toString(),
        localUserId,
        appDeviceId,
        capabilities,
        session,
      });
      const roster = await rosterForTrip(tripId).session(session);
      result = preparedPayload({ ...context, group, roster });
    });
    return result;
  } finally {
    await session.endSession();
  }
};

const joinCloudPreparedTrip = async ({
  userId,
  tripCode,
  localUserId,
  appDeviceId,
  capabilities,
}) => {
  const group = await Group.findOne({
    groupCode: tripCode.toUpperCase(),
    status: 'active',
  });
  if (!group) {
    const error = new Error('Cloud-prepared trip not found');
    error.statusCode = 404;
    throw error;
  }

  const session = await Trip.startSession();
  try {
    let result;
    await session.withTransaction(async () => {
      const existingMember = await GroupMember.findOne({
        groupId: group._id,
        userId,
      }).session(session);
      if (existingMember) {
        existingMember.status = 'active';
        existingMember.memberRole = existingMember.memberRole || 'member';
        existingMember.joinedAt = new Date();
        await existingMember.save({ session });
      } else {
        await GroupMember.create(
          [
            {
              groupId: group._id,
              userId,
              memberRole: 'member',
              status: 'active',
            },
          ],
          { session },
        );
      }

      let source = await findPreparedSource({
        cloudGroupId: group._id.toString(),
      }).session(session);
      let tripId;
      let channelId;
      let chatId;
      let channelKeyHash;
      if (source) {
        tripId = source.tripId;
        channelId = source.primaryChannelId || source.activeChannelId;
        const sourceChannel = await TripChannel.findOne({
          tripId,
          channelId,
        }).session(session);
        channelKeyHash = sourceChannel?.channelKeyHash ||
          buildChannelKeyHash({
            groupId: group._id.toString(),
            channelCode: group.groupCode,
          });
      } else {
        tripId = `trip_${crypto.randomUUID()}`;
        channelId = `channel_${crypto.randomUUID()}`;
        channelKeyHash = buildChannelKeyHash({
          groupId: group._id.toString(),
          channelCode: group.groupCode,
        });
      }
      chatId = `chat_${tripId}_${channelId}`;
      const context = await ensurePreparedContextForUser({
        userId,
        ownerUserId: group.createdBy,
        group,
        tripId,
        tripName: group.groupName,
        channelId,
        channelCode: group.groupCode,
        channelKeyHash,
        chatId,
        session,
      });
      await upsertMemberDeviceProfile({
        userId,
        tripId,
        channelId,
        cloudGroupId: group._id.toString(),
        localUserId,
        appDeviceId,
        capabilities,
        session,
      });
      const roster = await rosterForTrip(tripId).session(session);
      result = preparedPayload({ ...context, group, roster });
    });
    return result;
  } finally {
    await session.endSession();
  }
};

const getCloudPreparedTripMetadata = async ({ userId, tripId }) => {
  const trip = await Trip.findOne({ ownerId: userId, tripId });
  if (!trip || !trip.cloudGroupId) {
    const error = new Error('Cloud-prepared trip metadata not found');
    error.statusCode = 404;
    throw error;
  }
  await ensureUserCanReadGroup(userId, trip.cloudGroupId);
  const [group, channel, chatRoom, roster] = await Promise.all([
    Group.findById(trip.cloudGroupId),
    TripChannel.findOne({ ownerId: userId, tripId, channelId: trip.primaryChannelId || trip.activeChannelId }),
    ChatRoom.findOne({ ownerId: userId, tripId, isDefault: true }),
    rosterForTrip(tripId),
  ]);
  if (!group || !channel || !chatRoom) {
    const error = new Error('Cloud-prepared trip metadata is incomplete');
    error.statusCode = 404;
    throw error;
  }
  return preparedPayload({ trip, channel, chatRoom, group, roster });
};

const ensureUserCanReadGroup = async (userId, groupId) => {
  const membership = await GroupMember.findOne({
    groupId,
    userId,
    status: 'active',
  });
  if (!membership) {
    const error = new Error('You are not a member of this trip');
    error.statusCode = 403;
    throw error;
  }
  return membership;
};

const syncTripContext = async ({ userId, trips = [], channels = [], chatRooms = [] }) => {
  const synced = { trips: [], channels: [], chatRooms: [] };

  for (const item of trips) {
    const trip = normalizeTrip(item);
    if (!trip.tripId) continue;
    if (trip.status === 'active') {
      await Trip.updateMany(
        { ownerId: userId, tripId: { $ne: trip.tripId }, status: 'active' },
        { $set: { status: 'inactive' } },
      );
    }
    const saved = await Trip.findOneAndUpdate(
      { ownerId: userId, tripId: trip.tripId },
      { $set: { ownerId: userId, ...trip } },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    synced.trips.push(tripDto(saved));
  }

  for (const item of channels) {
    const channel = normalizeChannel(item);
    if (!channel.channelId || !channel.tripId) continue;
    if (channel.isActive) {
      await TripChannel.updateMany(
        {
          ownerId: userId,
          tripId: channel.tripId,
          channelId: { $ne: channel.channelId },
          isActive: true,
        },
        { $set: { isActive: false, channelStatus: 'inactive' } },
      );
      await Trip.updateOne(
        { ownerId: userId, tripId: channel.tripId },
        { $set: { activeChannelId: channel.channelId } },
      );
    }
    const saved = await TripChannel.findOneAndUpdate(
      { ownerId: userId, channelId: channel.channelId },
      { $set: { ownerId: userId, ...channel } },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    synced.channels.push(channelDto(saved));
  }

  for (const item of chatRooms) {
    const chatRoom = normalizeChatRoom(item);
    if (!chatRoom.chatId || !chatRoom.tripId) continue;
    if (chatRoom.isActive) {
      await ChatRoom.updateMany(
        {
          ownerId: userId,
          tripId: chatRoom.tripId,
          chatId: { $ne: chatRoom.chatId },
          isActive: true,
        },
        { $set: { isActive: false, chatStatus: 'inactive' } },
      );
    }
    const saved = await ChatRoom.findOneAndUpdate(
      { ownerId: userId, chatId: chatRoom.chatId },
      { $set: { ownerId: userId, ...chatRoom } },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    synced.chatRooms.push(chatRoomDto(saved));
  }

  return synced;
};

const getTripContextChanges = async ({ userId, updatedSince }) => {
  const updatedFilter = updatedSince
    ? { updatedAt: { $gt: new Date(updatedSince) } }
    : {};
  const [trips, channels, chatRooms] = await Promise.all([
    Trip.find({ ownerId: userId, ...updatedFilter }).sort({ updatedAt: 1 }),
    TripChannel.find({ ownerId: userId, ...updatedFilter }).sort({ updatedAt: 1 }),
    ChatRoom.find({ ownerId: userId, ...updatedFilter }).sort({ updatedAt: 1 }),
  ]);
  return {
    trips: trips.map(tripDto),
    channels: channels.map(channelDto),
    chatRooms: chatRooms.map(chatRoomDto),
  };
};

module.exports = {
  createCloudPreparedTrip,
  getTripContextChanges,
  getCloudPreparedTripMetadata,
  joinCloudPreparedTrip,
  syncTripContext,
};
