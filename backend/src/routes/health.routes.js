const express = require('express');
const {
  getDbHealth,
  getHealth,
  getPing,
} = require('../controllers/health.controller');

const router = express.Router();

router.get('/', getHealth);
router.get('/ping', getPing);
router.get('/db', getDbHealth);

module.exports = router;
