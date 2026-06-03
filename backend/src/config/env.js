const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const nodeEnv = process.env.NODE_ENV || 'development';
const jwtSecret = process.env.JWT_SECRET || '';
const placeholderSecrets = new Set([
  'replace_with_secure_secret',
  'replace_with_a_long_secure_random_secret',
]);

if (nodeEnv === 'production' && (!jwtSecret || placeholderSecrets.has(jwtSecret))) {
  throw new Error('JWT_SECRET must be set to a long, non-placeholder secret in production.');
}

const resolvedJwtSecret =
  jwtSecret && !placeholderSecrets.has(jwtSecret)
    ? jwtSecret
    : 'traillink-development-only-secret-change-me';

const env = {
  port: Number.parseInt(process.env.PORT || '5001', 10),
  nodeEnv,
  mongoUri: process.env.MONGO_URI || '',
  jwtSecret: resolvedJwtSecret,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
};

module.exports = env;
