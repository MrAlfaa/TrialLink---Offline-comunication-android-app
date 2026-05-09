const { sendError } = require('../utils/response');

const notFound = (req, res, next) => {
  const error = new Error(`Route not found: ${req.originalUrl}`);
  error.statusCode = 404;
  next(error);
};

const errorHandler = (error, _req, res, _next) => {
  const statusCode = error.statusCode || (error.name === 'MulterError' ? 422 : 500);
  const message = error.message || 'Internal server error';

  return sendError(res, message, statusCode);
};

module.exports = {
  notFound,
  errorHandler,
};
