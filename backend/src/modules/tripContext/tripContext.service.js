const ChatRoom = require('../../models/chatRoom.model');
const Trip = require('../../models/trip.model');
const TripChannel = require('../../models/tripChannel.model');

const parseDate = (value) => (value ? new Date(value) : undefined);

const tripDto = (trip) => ({
  tripId: trip.tripId,
  tripName: trip.tripName,
  status: trip.status,
  mode: trip.mode,
  activeChannelId: trip.activeChannelId || null,
  cloudGroupId: trip.cloudGroupId || null,
  lastOpenedAt: trip.lastOpenedAt || null,
  createdAt: trip.createdAt,
  updatedAt: trip.updatedAt,
});

const channelDto = (channel) => ({
  channelId: channel.channelId,
  tripId: channel.tripId,
  channelName: channel.channelName,
  channelCode: channel.channelCode,
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

const normalizeTrip = (item = {}) => ({
  tripId: item.tripId,
  tripName: item.tripName || item.name || 'TrailLink Trip',
  status: item.status || 'inactive',
  mode: item.mode || 'offline',
  activeChannelId: item.activeChannelId || item.offlineChannelId || undefined,
  cloudGroupId: item.cloudGroupId || undefined,
  lastOpenedAt: parseDate(item.lastOpenedAt),
  clientCreatedAt: parseDate(item.createdAt),
  clientUpdatedAt: parseDate(item.updatedAt),
});

const normalizeChannel = (item = {}) => ({
  channelId: item.channelId,
  tripId: item.tripId,
  channelName: item.channelName || item.name || 'Main Team Channel',
  channelCode: item.channelCode,
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
  getTripContextChanges,
  syncTripContext,
};
