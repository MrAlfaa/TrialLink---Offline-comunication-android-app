const tripContextService = require('./tripContext.service');
const { sendSuccess } = require('../../utils/response');

const createCloudPreparedTrip = async (req, res, next) => {
  try {
    const data = await tripContextService.createCloudPreparedTrip({
      userId: req.user._id,
      tripName: req.body.tripName || req.body.groupName,
      description: req.body.description,
      localUserId: req.body.localUserId,
      appDeviceId: req.body.appDeviceId,
      capabilities: req.body.capabilities,
    });
    return sendSuccess(res, 'Cloud-prepared trip created', { data }, 201);
  } catch (error) {
    return next(error);
  }
};

const joinCloudPreparedTrip = async (req, res, next) => {
  try {
    const data = await tripContextService.joinCloudPreparedTrip({
      userId: req.user._id,
      tripCode: req.body.tripCode || req.body.groupCode,
      localUserId: req.body.localUserId,
      appDeviceId: req.body.appDeviceId,
      capabilities: req.body.capabilities,
    });
    return sendSuccess(res, 'Cloud-prepared trip joined', { data });
  } catch (error) {
    return next(error);
  }
};

const getCloudPreparedTripMetadata = async (req, res, next) => {
  try {
    const data = await tripContextService.getCloudPreparedTripMetadata({
      userId: req.user._id,
      tripId: req.params.tripId,
    });
    return sendSuccess(res, 'Cloud-prepared trip metadata loaded', { data });
  } catch (error) {
    return next(error);
  }
};

const syncTripContext = async (req, res, next) => {
  try {
    const synced = await tripContextService.syncTripContext({
      userId: req.user._id,
      trips: req.body.trips || [],
      channels: req.body.channels || [],
      chatRooms: req.body.chatRooms || [],
    });
    return sendSuccess(res, 'Trip context synced', { data: synced });
  } catch (error) {
    return next(error);
  }
};

const getTripContextChanges = async (req, res, next) => {
  try {
    const data = await tripContextService.getTripContextChanges({
      userId: req.user._id,
      updatedSince: req.query.updatedSince,
    });
    return sendSuccess(res, 'Trip context loaded', { data });
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  createCloudPreparedTrip,
  getTripContextChanges,
  getCloudPreparedTripMetadata,
  joinCloudPreparedTrip,
  syncTripContext,
};
