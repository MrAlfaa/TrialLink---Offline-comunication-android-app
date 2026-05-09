const authService = require('./auth.service');
const { sendSuccess } = require('../../utils/response');

const register = async (req, res, next) => {
  try {
    const result = await authService.register(req.body);
    return sendSuccess(res, 'Registration successful', { data: result }, 201);
  } catch (error) {
    next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const result = await authService.login(req.body);
    return sendSuccess(res, 'Login successful', { data: result });
  } catch (error) {
    next(error);
  }
};

const me = async (req, res, next) => {
  try {
    const user = await authService.getCurrentUser(req.user._id);
    return sendSuccess(res, 'Current user loaded', { data: { user } });
  } catch (error) {
    next(error);
  }
};

const bootstrapIdentity = async (req, res, next) => {
  try {
    const result = await authService.bootstrapIdentity(req.body);
    return sendSuccess(res, 'TrailLink identity synced', { data: result }, 201);
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  me,
  bootstrapIdentity,
};
