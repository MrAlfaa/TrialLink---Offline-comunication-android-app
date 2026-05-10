const express = require('express');
const { authenticate } = require('../../middleware/auth.middleware');
const tripContextController = require('./tripContext.controller');
const {
  getTripContextValidation,
  syncTripContextValidation,
  validate,
} = require('./tripContext.validation');

const router = express.Router();

router.use(authenticate);

router.get('/sync', getTripContextValidation, validate, tripContextController.getTripContextChanges);
router.post('/sync', syncTripContextValidation, validate, tripContextController.syncTripContext);

module.exports = router;
