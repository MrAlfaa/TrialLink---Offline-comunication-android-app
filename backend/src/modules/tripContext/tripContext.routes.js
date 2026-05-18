const express = require('express');
const { authenticate } = require('../../middleware/auth.middleware');
const tripContextController = require('./tripContext.controller');
const {
  cloudPreparedCreateValidation,
  cloudPreparedJoinValidation,
  cloudPreparedMetadataValidation,
  getTripContextValidation,
  syncTripContextValidation,
  validate,
} = require('./tripContext.validation');

const router = express.Router();

router.use(authenticate);

router.post('/cloud-prepared-trips', cloudPreparedCreateValidation, validate, tripContextController.createCloudPreparedTrip);
router.post('/cloud-prepared-trips/join', cloudPreparedJoinValidation, validate, tripContextController.joinCloudPreparedTrip);
router.get('/cloud-prepared-trips/:tripId/metadata', cloudPreparedMetadataValidation, validate, tripContextController.getCloudPreparedTripMetadata);
router.get('/sync', getTripContextValidation, validate, tripContextController.getTripContextChanges);
router.post('/sync', syncTripContextValidation, validate, tripContextController.syncTripContext);

module.exports = router;
