const express = require('express');
const authController = require('../auth/auth.controller');
const {
  bootstrapIdentityValidation,
  validate,
} = require('../auth/auth.validation');

const router = express.Router();

router.post(
  '/bootstrap',
  bootstrapIdentityValidation,
  validate,
  authController.bootstrapIdentity,
);

module.exports = router;
