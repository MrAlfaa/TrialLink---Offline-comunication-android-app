const express = require('express');
const locationController = require('./location.controller');
const {
  createLocationValidation,
  latestLocationsValidation,
  syncLocationsValidation,
  validate,
} = require('./location.validation');

const router = express.Router({ mergeParams: true });

router.post('/', createLocationValidation, validate, locationController.createLocation);
router.post('/sync', syncLocationsValidation, validate, locationController.syncLocations);
router.get('/latest', latestLocationsValidation, validate, locationController.latestLocations);

module.exports = router;
