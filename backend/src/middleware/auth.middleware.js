const User = require('../models/user.model');
const { sendError } = require('../utils/response');
const { verifyToken } = require('../utils/jwt');

const authenticate = async (req, res, next) => {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return sendError(res, 'Authentication token is required', 401);
  }

  try {
    const payload = verifyToken(token);
    const user = await User.findById(payload.sub).select('-passwordHash');

    if (!user) {
      return sendError(res, 'Invalid authentication token', 401);
    }

    req.user = user;
    next();
  } catch (_error) {
    return sendError(res, 'Invalid or expired authentication token', 401);
  }
};

module.exports = {
  authenticate,
};
