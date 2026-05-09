const express = require('express');
const emergencyController = require('./emergency.controller');
const {
  acknowledgeEmergencyValidation,
  createEmergencyValidation,
  eventIdValidation,
  listEmergencyValidation,
  validate,
} = require('./emergency.validation');

const router = express.Router({ mergeParams: true });

router.post(
  '/',
  createEmergencyValidation,
  validate,
  emergencyController.createEmergency,
);
router.get(
  '/',
  listEmergencyValidation,
  validate,
  emergencyController.listEmergencies,
);
router.post(
  '/:eventId/ack',
  acknowledgeEmergencyValidation,
  validate,
  emergencyController.acknowledgeEmergency,
);
router.post(
  '/:eventId/resolve',
  eventIdValidation,
  validate,
  emergencyController.resolveEmergency,
);

module.exports = router;
