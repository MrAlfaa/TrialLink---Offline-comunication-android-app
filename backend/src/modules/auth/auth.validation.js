const { body, validationResult } = require('express-validator');
const { sendError } = require('../../utils/response');

const registerValidation = [
  body('fullName')
    .trim()
    .notEmpty()
    .withMessage('Full name is required'),
  body('email')
    .trim()
    .isEmail()
    .withMessage('A valid email is required')
    .normalizeEmail(),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Password must be at least 8 characters'),
  body('phoneNumber')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .matches(/^[+0-9\s-]{7,20}$/)
    .withMessage('Phone number must be 7-20 digits or leave it blank'),
];

const loginValidation = [
  body('email')
    .trim()
    .isEmail()
    .withMessage('A valid email is required')
    .normalizeEmail(),
  body('password')
    .notEmpty()
    .withMessage('Password is required'),
];

const bootstrapIdentityValidation = [
  body('displayName')
    .trim()
    .notEmpty()
    .withMessage('Display name is required')
    .bail()
    .isLength({ min: 2, max: 50 })
    .withMessage('Display name must be 2-50 characters'),
  body('fullName')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isLength({ min: 2, max: 50 })
    .withMessage('Full name must be 2-50 characters'),
  body('email')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isEmail()
    .withMessage('A valid email is required when email is provided')
    .normalizeEmail(),
  body('phoneNumber')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .matches(/^[+0-9\s-]{7,20}$/)
    .withMessage('Phone number must be 7-20 digits or leave it blank'),
  body('localUserId')
    .trim()
    .notEmpty()
    .withMessage('Local user ID is required')
    .bail()
    .isLength({ min: 4, max: 100 })
    .withMessage('Local user ID is invalid'),
  body('emergencyNote')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isLength({ max: 200 })
    .withMessage('Emergency note must be 200 characters or less'),
  body('deviceId')
    .optional({ nullable: true, checkFalsy: true })
    .trim()
    .isLength({ min: 4, max: 120 })
    .withMessage('Device ID is invalid'),
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
  registerValidation,
  loginValidation,
  bootstrapIdentityValidation,
  validate,
};
