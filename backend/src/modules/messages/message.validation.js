const { body, param, query, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const groupIdValidation = [
  param('groupId').isMongoId().withMessage('Valid group id is required'),
];

const listMessagesValidation = [
  ...groupIdValidation,
  query('page').optional().isInt({ min: 1 }).withMessage('Page must be a positive number'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100'),
  query('before').optional().isISO8601().withMessage('Before must be a valid ISO date'),
];

const syncMessagesValidation = [
  ...groupIdValidation,
  body('messages').isArray({ min: 1, max: 50 }).withMessage('Messages are required'),
  body('messages.*.clientMessageId')
    .trim()
    .notEmpty()
    .withMessage('Client message id is required'),
  body('messages.*.content')
    .trim()
    .notEmpty()
    .withMessage('Message content is required')
    .isLength({ max: 2000 })
    .withMessage('Message content is too long'),
  body('messages.*.messageType')
    .optional()
    .equals('text')
    .withMessage('Only text messages are supported'),
  body('messages.*.createdAt')
    .optional()
    .isISO8601()
    .withMessage('Message createdAt must be a valid ISO date'),
  body('messages.*.tripId').optional().trim().isLength({ max: 120 }),
  body('messages.*.channelId').optional().trim().isLength({ max: 120 }),
  body('messages.*.chatId').optional().trim().isLength({ max: 120 }),
];

const mediaMessageValidation = [
  ...groupIdValidation,
  body('clientMessageId')
    .trim()
    .notEmpty()
    .withMessage('Client message id is required'),
  body('messageType')
    .isIn(['image', 'voice', 'file'])
    .withMessage('Message type must be image, voice, or file'),
  body('content')
    .optional()
    .trim()
    .isLength({ max: 2000 })
    .withMessage('Message content is too long'),
  body('durationMs')
    .optional()
    .isInt({ min: 1, max: 30000 })
    .withMessage('Voice duration must be between 1 and 30000 ms'),
  body('createdAt')
    .optional()
    .isISO8601()
    .withMessage('Message createdAt must be a valid ISO date'),
  body('tripId').optional().trim().isLength({ max: 120 }),
  body('channelId').optional().trim().isLength({ max: 120 }),
  body('chatId').optional().trim().isLength({ max: 120 }),
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
  listMessagesValidation,
  mediaMessageValidation,
  syncMessagesValidation,
  validate,
};
