const tripContextService = require('./tripContext.service');
const { sendSuccess } = require('../../utils/response');

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
  getTripContextChanges,
  syncTripContext,
};
