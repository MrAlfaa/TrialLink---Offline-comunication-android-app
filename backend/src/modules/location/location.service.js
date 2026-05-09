const mongoose = require('mongoose');
const LocationUpdate = require('../../models/locationUpdate.model');
const { ensureUserActiveGroupMember } = require('../groups/membership.service');

const freshnessFor = (capturedAt) => {
  const ageMs = Date.now() - new Date(capturedAt).getTime();
  if (ageMs <= 5 * 60 * 1000) return 'fresh';
  if (ageMs <= 30 * 60 * 1000) return 'old';
  return 'stale';
};

const toLocationDto = (location) => {
  const user = location.userId;
  return {
    id: location._id.toString(),
    clientLocationId: location.clientLocationId,
    groupId: location.groupId?.toString?.() || location.groupId,
    user: {
      id: user?._id?.toString?.() || user?.toString?.() || location.userId.toString(),
      fullName: user?.fullName || 'TrailLink User',
    },
    latitude: location.latitude,
    longitude: location.longitude,
    accuracy: location.accuracy,
    altitude: location.altitude,
    speed: location.speed,
    heading: location.heading,
    capturedAt: location.capturedAt,
    freshness: freshnessFor(location.capturedAt),
    sourcePath: location.sourcePath || 'online',
    originLocalId: location.originLocalId || null,
    originDisplayName: location.originDisplayName || null,
    originBackendId: location.originBackendId?.toString?.() || null,
    originIdentityType: location.originIdentityType || null,
    bridgedBy: location.bridgedBy?.toString?.() || null,
    bridgedByLocalId: location.bridgedByLocalId || null,
    bridgedByName: location.bridgedByName || null,
    bridgedAt: location.bridgedAt || null,
    originalPacketId: location.originalPacketId || null,
    channelCode: location.channelCode || null,
    createdAt: location.createdAt,
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

const createOrFindLocation = async ({ groupId, userId, location, bridgeMetadata = {} }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const bridgeQuery =
    bridgeMetadata.sourcePath === 'bridge' && bridgeMetadata.originLocalId
      ? {
          clientLocationId: location.clientLocationId,
          originLocalId: bridgeMetadata.originLocalId,
          sourcePath: 'bridge',
        }
      : null;
  const existing = await LocationUpdate.findOne(
    bridgeQuery || {
      clientLocationId: location.clientLocationId,
      userId,
    },
  ).populate('userId', 'fullName email');
  if (existing) {
    return { location: existing, created: false };
  }

  const saved = await LocationUpdate.create({
    clientLocationId: location.clientLocationId,
    groupId,
    userId,
    latitude: Number(location.latitude),
    longitude: Number(location.longitude),
    accuracy: location.accuracy == null ? undefined : Number(location.accuracy),
    altitude: location.altitude == null ? undefined : Number(location.altitude),
    speed: location.speed == null ? undefined : Number(location.speed),
    heading: location.heading == null ? undefined : Number(location.heading),
    capturedAt: new Date(location.capturedAt),
    ...bridgeMetadata,
  });
  await saved.populate('userId', 'fullName email');
  return { location: saved, created: true };
};

const syncLocations = async ({ groupId, userId, locations }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const syncedLocations = [];
  const createdLocations = [];
  for (const item of locations) {
    const result = await createOrFindLocation({
      groupId,
      userId,
      location: item,
      bridgeMetadata: bridgeFieldsFrom(item, userId),
    });
    const dto = toLocationDto(result.location);
    syncedLocations.push(dto);
    if (result.created) createdLocations.push(dto);
  }
  return { syncedLocations, createdLocations };
};

const latestLocations = async ({ groupId, userId }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  const rows = await LocationUpdate.aggregate([
    { $match: { groupId: new mongoose.Types.ObjectId(groupId) } },
    { $sort: { capturedAt: -1 } },
    {
      $group: {
        _id: '$userId',
        locationId: { $first: '$_id' },
      },
    },
  ]);

  const ids = rows.map((row) => row.locationId);
  const locations = await LocationUpdate.find({ _id: { $in: ids } })
    .populate('userId', 'fullName email')
    .sort({ capturedAt: -1 });

  return locations.map(toLocationDto);
};

module.exports = {
  bridgeFieldsFrom,
  createOrFindLocation,
  latestLocations,
  syncLocations,
  toLocationDto,
};
