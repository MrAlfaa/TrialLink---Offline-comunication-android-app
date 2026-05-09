const { body, param, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const createGroupValidation = [
  body('groupName')
    .trim()
    .notEmpty()
    .withMessage('Group name is required')
    .isLength({ max: 120 })
    .withMessage('Group name is too long'),
  body('description')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isLength({ max: 500 })
    .withMessage('Description is too long'),
];

const joinGroupValidation = [
  body('groupCode')
    .trim()
    .matches(/^TL-[A-Z0-9]{5}$/)
    .withMessage('Valid group code is required'),
];

const groupIdValidation = [
  param('groupId')
    .isMongoId()
    .withMessage('Valid group id is required'),
];

const memberIdValidation = [
  ...groupIdValidation,
  param('memberId')
    .isMongoId()
    .withMessage('Valid member id is required'),
];

const updateMemberRoleValidation = [
  ...memberIdValidation,
  body('memberRole')
    .isIn(['admin', 'member'])
    .withMessage('Valid member role is required'),
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
  createGroupValidation,
  joinGroupValidation,
  groupIdValidation,
  memberIdValidation,
  updateMemberRoleValidation,
  validate,
};
