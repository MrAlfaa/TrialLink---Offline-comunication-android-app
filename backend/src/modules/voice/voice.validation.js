const { body, param, query, validationResult } = require('express-validator');

const { sendError } = require('../../utils/response');

const groupIdValidation = [
  param('groupId').isMongoId().withMessage('Valid group id is required'),
];

const uploadVoiceNoteValidation = [
  ...groupIdValidation,
  body('clientVoiceId').trim().notEmpty().withMessage('Client voice id is required'),
  body('durationMs')
    .optional({ nullable: true })
    .isInt({ min: 1, max: 30000 })
    .withMessage('durationMs must be between 1 and 30000'),
  body('createdAt').optional({ nullable: true }).isISO8601(),
];

const listVoiceNotesValidation = [
  ...groupIdValidation,
  query('limit').optional({ nullable: true }).isInt({ min: 1, max: 100 }),
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
  listVoiceNotesValidation,
  uploadVoiceNoteValidation,
  validate,
};
