const locationService = require('./location.service');
const { sendSuccess } = require('../../utils/response');
const { emitLocationUpdate } = require('../../socket/socket');

const createLocation = async (req, res, next) => {
  try {
    const result = await locationService.createOrFindLocation({
      groupId: req.params.groupId,
      userId: req.user._id,
      location: req.body,
      bridgeMetadata: locationService.bridgeFieldsFrom(req.body, req.user._id),
    });
    const location = locationService.toLocationDto(result.location);
    if (result.created) emitLocationUpdate(req.params.groupId, location);
    return sendSuccess(
      res,
      result.created ? 'Location shared successfully' : 'Location already synced',
      { data: { location } },
      result.created ? 201 : 200,
    );
  } catch (error) {
    next(error);
  }
};

const syncLocations = async (req, res, next) => {
  try {
    const result = await locationService.syncLocations({
      groupId: req.params.groupId,
      userId: req.user._id,
      locations: req.body.locations,
    });
    for (const location of result.createdLocations) {
      emitLocationUpdate(req.params.groupId, location);
    }
    return sendSuccess(res, 'Locations synced successfully', {
      data: { locations: result.syncedLocations },
    });
  } catch (error) {
    next(error);
  }
};

const latestLocations = async (req, res, next) => {
  try {
    const locations = await locationService.latestLocations({
      groupId: req.params.groupId,
      userId: req.user._id,
    });
    return sendSuccess(res, 'Latest locations fetched successfully', {
      data: { locations },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createLocation,
  latestLocations,
  syncLocations,
};
