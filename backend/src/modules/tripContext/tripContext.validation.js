const { body, query, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const syncTripContextValidation = [
  body('trips').optional().isArray({ max: 100 }).withMessage('Trips must be an array'),
  body('channels').optional().isArray({ max: 200 }).withMessage('Channels must be an array'),
  body('chatRooms').optional().isArray({ max: 300 }).withMessage('Chat rooms must be an array'),
  body('trips.*.tripId').optional().trim().notEmpty().withMessage('tripId is required'),
  body('trips.*.tripName').optional().trim().isLength({ max: 120 }),
  body('trips.*.status')
    .optional()
    .isIn(['active', 'inactive', 'archived', 'completed'])
    .withMessage('Invalid trip status'),
  body('trips.*.mode')
    .optional()
    .isIn(['online', 'offline', 'hybrid'])
    .withMessage('Invalid trip mode'),
  body('channels.*.channelId').optional().trim().notEmpty().withMessage('channelId is required'),
  body('channels.*.tripId').optional().trim().notEmpty().withMessage('channel tripId is required'),
  body('channels.*.channelName').optional().trim().isLength({ max: 120 }),
  body('channels.*.channelStatus')
    .optional()
    .isIn(['active', 'inactive', 'ended', 'archived'])
    .withMessage('Invalid channel status'),
  body('chatRooms.*.chatId').optional().trim().notEmpty().withMessage('chatId is required'),
  body('chatRooms.*.tripId').optional().trim().notEmpty().withMessage('chat tripId is required'),
  body('chatRooms.*.chatType')
    .optional()
    .isIn(['cloud_group', 'offline_channel', 'trip_general'])
    .withMessage('Invalid chat type'),
  body('chatRooms.*.chatStatus')
    .optional()
    .isIn(['active', 'inactive', 'archived', 'read_only'])
    .withMessage('Invalid chat status'),
];

const getTripContextValidation = [
  query('updatedSince').optional().isISO8601().withMessage('updatedSince must be an ISO date'),
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
  getTripContextValidation,
  syncTripContextValidation,
  validate,
};
