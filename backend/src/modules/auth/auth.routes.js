const express = require('express');
const authController = require('./auth.controller');
const {
  loginValidation,
  bootstrapIdentityValidation,
  registerValidation,
  validate,
} = require('./auth.validation');
const { authenticate } = require('../../middleware/auth.middleware');

const router = express.Router();

router.post('/register', registerValidation, validate, authController.register);
router.post('/login', loginValidation, validate, authController.login);
router.post(
  '/identity/bootstrap',
  bootstrapIdentityValidation,
  validate,
  authController.bootstrapIdentity,
);
router.get('/me', authenticate, authController.me);

module.exports = router;
