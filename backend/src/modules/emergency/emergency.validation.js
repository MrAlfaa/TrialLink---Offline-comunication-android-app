const { body, param, query, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const groupIdValidation = [
  param('groupId').isMongoId().withMessage('Valid group id is required'),
];

const eventIdValidation = [
  ...groupIdValidation,
  param('eventId').isMongoId().withMessage('Valid emergency event id is required'),
];

const createEmergencyValidation = [
  ...groupIdValidation,
  body('clientEventId').trim().notEmpty().withMessage('Client event id is required'),
  body('alertType')
    .optional()
    .isIn(['sos', 'medical', 'lost', 'danger', 'help', 'custom'])
    .withMessage('Invalid emergency alert type'),
  body('message')
    .optional({ nullable: true })
    .trim()
    .isLength({ max: 500 })
    .withMessage('Emergency message must be 500 characters or less'),
  body('location.latitude')
    .optional({ nullable: true })
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitude must be between -90 and 90'),
  body('location.longitude')
    .optional({ nullable: true })
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitude must be between -180 and 180'),
  body('location.accuracy')
    .optional({ nullable: true })
    .isFloat({ min: 0 })
    .withMessage('Accuracy must be a positive number'),
  body('location.capturedAt')
    .optional({ nullable: true })
    .isISO8601()
    .withMessage('Location capturedAt must be a valid ISO date'),
  body('createdAt').optional().isISO8601().withMessage('createdAt must be a valid ISO date'),
];

const listEmergencyValidation = [
  ...groupIdValidation,
  query('status')
    .optional()
    .isIn(['active', 'acknowledged', 'resolved', 'cancelled'])
    .withMessage('Invalid emergency status'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
];

const acknowledgeEmergencyValidation = [
  ...eventIdValidation,
  body('note')
    .optional({ nullable: true })
    .trim()
    .isLength({ max: 300 })
    .withMessage('Acknowledgement note must be 300 characters or less'),
];

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
  acknowledgeEmergencyValidation,
  createEmergencyValidation,
  eventIdValidation,
  listEmergencyValidation,
  validate,
};
