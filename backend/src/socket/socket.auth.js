const User = require('../models/user.model');
const { verifyToken } = require('../utils/jwt');

const authenticateSocket = async (socket, next) => {
  try {
    const token = socket.handshake.auth?.token;

    if (!token) {
      return next(new Error('Authentication token is required'));
    }

    const payload = verifyToken(token);
    const user = await User.findById(payload.sub).select('-passwordHash');

    if (!user) {
      return next(new Error('Invalid authentication token'));
    }

    socket.user = user;
    return next();
  } catch (_error) {
    return next(new Error('Invalid or expired authentication token'));
  }
};

module.exports = {
  authenticateSocket,
};
