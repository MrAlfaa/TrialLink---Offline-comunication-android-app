const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    publicUserId: {
      type: String,
      trim: true,
    },
    localUserId: {
      type: String,
      trim: true,
    },
    fullName: {
      type: String,
      required: true,
      trim: true,
    },
    displayName: {
      type: String,
      trim: true,
      default: null,
    },
    email: {
      type: String,
      lowercase: true,
      trim: true,
    },
    passwordHash: {
      type: String,
      required: true,
    },
    authProvider: {
      type: String,
      enum: ['password', 'bootstrap'],
      default: 'password',
    },
    isBootstrapProfile: {
      type: Boolean,
      default: false,
    },
    bootstrapLocalUserId: {
      type: String,
      trim: true,
      default: null,
      index: true,
    },
    emergencyNote: {
      type: String,
      trim: true,
      default: null,
    },
    identitySource: {
      type: String,
      enum: ['local_bootstrap', 'direct_cloud'],
      default: 'direct_cloud',
    },
    createdFromDeviceId: {
      type: String,
      trim: true,
      default: null,
    },
    phoneNumber: {
      type: String,
      trim: true,
      default: null,
    },
    avatarUrl: {
      type: String,
      trim: true,
      default: null,
    },
    role: {
      type: String,
      enum: ['user', 'admin'],
      default: 'user',
    },
    lastLoginAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  },
);

userSchema.index(
  { publicUserId: 1 },
  {
    unique: true,
    partialFilterExpression: { publicUserId: { $type: 'string' } },
  },
);
userSchema.index(
  { localUserId: 1 },
  {
    unique: true,
    partialFilterExpression: { localUserId: { $type: 'string' } },
  },
);
userSchema.index(
  { email: 1 },
  {
    unique: true,
    partialFilterExpression: { email: { $type: 'string' } },
  },
);

module.exports = mongoose.model('User', userSchema);
