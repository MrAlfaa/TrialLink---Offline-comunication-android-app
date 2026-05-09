const mongoose = require('mongoose');
const env = require('./env');
const User = require('../models/user.model');

const DB_STATES = {
  0: 'disconnected',
  1: 'connected',
  2: 'connecting',
  3: 'disconnecting',
};

const getDbState = () => DB_STATES[mongoose.connection.readyState] || 'unknown';

const connectDb = async () => {
  if (!env.mongoUri || env.mongoUri.includes('your_mongodb_atlas_connection_string')) {
    console.warn('MongoDB Atlas connection skipped: MONGO_URI is not configured.');
    return;
  }

  try {
    await mongoose.connect(env.mongoUri);
    await User.syncIndexes();
    console.log(`MongoDB Atlas ${getDbState()}`);
  } catch (error) {
    console.error('MongoDB Atlas connection failed:', error.message);
  }
};

module.exports = {
  connectDb,
  getDbState,
};
