const { body, param, query, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const capabilitiesValidation = [
  body('capabilities').optional().isObject().withMessage('Capabilities must be an object'),
  body('capabilities.supportsNearby').optional().isBoolean().withMessage('supportsNearby must be boolean'),
  body('capabilities.supportsPtt').optional().isBoolean().withMessage('supportsPtt must be boolean'),
  body('capabilities.supportsLiveRadio').optional().isBoolean().withMessage('supportsLiveRadio must be boolean'),
];

const cloudPreparedCreateValidation = [
  body('tripName')
    .optional({ checkFalsy: true })
    .trim()
    .isLength({ min: 3, max: 120 })
    .withMessage('Trip name must be 3-120 characters'),
  body('groupName')
    .optional({ checkFalsy: true })
    .trim()
    .isLength({ min: 3, max: 120 })
    .withMessage('Group name must be 3-120 characters'),
  body().custom((value) => {
    if ((value.tripName || value.groupName || '').trim().length >= 3) return true;
    throw new Error('Trip name is required');
  }),
  body('description')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description is too long'),
  body('localUserId').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 120 }),
  body('appDeviceId').trim().notEmpty().isLength({ max: 120 }).withMessage('App device id is required'),
  ...capabilitiesValidation,
];

const cloudPreparedJoinValidation = [
  body('tripCode')
    .optional({ checkFalsy: true })
    .trim()
    .matches(/^TL-[A-Z0-9]{5}$/)
    .withMessage('Valid trip code is required'),
  body('groupCode')
    .optional({ checkFalsy: true })
    .trim()
    .matches(/^TL-[A-Z0-9]{5}$/)
    .withMessage('Valid group code is required'),
  body().custom((value) => {
    if ((value.tripCode || value.groupCode || '').trim().length > 0) return true;
    throw new Error('Trip code is required');
  }),
  body('localUserId').optional({ nullable: true, checkFalsy: true }).trim().isLength({ max: 120 }),
  body('appDeviceId').trim().notEmpty().isLength({ max: 120 }).withMessage('App device id is required'),
  ...capabilitiesValidation,
];

const cloudPreparedMetadataValidation = [
  param('tripId').trim().notEmpty().withMessage('Trip id is required'),
];

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
  cloudPreparedCreateValidation,
  cloudPreparedJoinValidation,
  cloudPreparedMetadataValidation,
  getTripContextValidation,
  syncTripContextValidation,
  validate,
};
