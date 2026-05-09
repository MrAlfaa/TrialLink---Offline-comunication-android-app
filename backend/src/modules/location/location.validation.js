const { body, param, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const groupIdValidation = [
  param('groupId').isMongoId().withMessage('Valid group id is required'),
];

const locationFields = [
  body('clientLocationId').trim().notEmpty().withMessage('Client location id is required'),
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Latitude must be between -90 and 90'),
  body('longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180'),
  body('accuracy').optional({ nullable: true }).isFloat({ min: 0 }),
  body('altitude').optional({ nullable: true }).isFloat(),
  body('speed').optional({ nullable: true }).isFloat(),
  body('heading').optional({ nullable: true }).isFloat(),
  body('capturedAt').isISO8601().withMessage('capturedAt must be a valid ISO date'),
];

const createLocationValidation = [...groupIdValidation, ...locationFields];

const syncLocationsValidation = [
  ...groupIdValidation,
  body('locations').isArray({ min: 1, max: 100 }).withMessage('Locations are required'),
  body('locations.*.clientLocationId')
    .trim()
    .notEmpty()
    .withMessage('Client location id is required'),
  body('locations.*.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude must be between -90 and 90'),
  body('locations.*.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180'),
  body('locations.*.capturedAt')
    .isISO8601()
    .withMessage('capturedAt must be a valid ISO date'),
];

const latestLocationsValidation = groupIdValidation;

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (errors.isEmpty()) return next();

  return sendError(res, 'Validation failed', 422, {
    errors: errors.array().map((error) => ({
      field: error.path,
      message: error.msg,
    })),
  });
};

module.exports = {
  createLocationValidation,
  latestLocationsValidation,
  syncLocationsValidation,
  validate,
};
