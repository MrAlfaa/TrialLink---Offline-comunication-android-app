const env = require('../config/env');
const { getDbState } = require('../config/db');
const { sendSuccess, sendError } = require('../utils/response');

const getHealth = (_req, res) => {
  return sendSuccess(res, 'TrailLink backend is running', {
    timestamp: new Date().toISOString(),
    environment: env.nodeEnv,
  });
};

const getPing = (_req, res) => {
  return sendSuccess(res, 'pong', {
    timestamp: new Date().toISOString(),
  });
};

const getDbHealth = (_req, res) => {
  const dbState = getDbState();

  if (dbState === 'connected') {
    return sendSuccess(res, 'MongoDB Atlas connected', { dbState });
  }

  return sendError(res, 'MongoDB Atlas not connected', 503, { dbState });
};

module.exports = {
  getHealth,
  getPing,
  getDbHealth,
};
