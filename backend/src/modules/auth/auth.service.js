const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const User = require('../../models/user.model');
const UidCounter = require('../../models/uidCounter.model');
const { signToken } = require('../../utils/jwt');

const toPublicUser = (user) => ({
  id: user._id.toString(),
  publicUserId: user.publicUserId,
  localUserId: user.localUserId || user.bootstrapLocalUserId,
  fullName: user.fullName,
  displayName: user.displayName || user.fullName,
  email: user.email,
  phoneNumber: user.phoneNumber,
  emergencyNote: user.emergencyNote,
  avatarUrl: user.avatarUrl,
  role: user.role,
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
  lastLoginAt: user.lastLoginAt,
  authProvider: user.authProvider,
  isBootstrapProfile: user.isBootstrapProfile,
  identitySource: user.identitySource,
});

const normalizeEmail = (email) => {
  const trimmed = (email || '').trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
};

const generatePublicUserId = async () => {
  const now = new Date();
  const dateKey = now.toISOString().slice(0, 10).replace(/-/g, '');
  const counter = await UidCounter.findOneAndUpdate(
    { dateKey },
    {
      $inc: { sequence: 1 },
      $set: { updatedAt: now },
    },
    { upsert: true, new: true },
  );
  return `UID-${dateKey}${String(counter.sequence).padStart(4, '0')}`;
};

const register = async ({ fullName, email, password, phoneNumber }) => {
  const normalizedEmail = normalizeEmail(email);
  const existing = await User.findOne({ email: normalizedEmail });

  if (existing) {
    const error = new Error('Email already registered');
    error.statusCode = 409;
    throw error;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const publicUserId = await generatePublicUserId();
  const user = await User.create({
    publicUserId,
    fullName,
    displayName: fullName,
    email: normalizedEmail,
    passwordHash,
    phoneNumber: phoneNumber || null,
    identitySource: 'direct_cloud',
  });

  const token = signToken(user);

  return {
    user: toPublicUser(user),
    token,
  };
};

const login = async ({ email, password }) => {
  const user = await User.findOne({ email: normalizeEmail(email) });

  if (!user) {
    const error = new Error('Invalid email or password');
    error.statusCode = 401;
    throw error;
  }

  const matches = await bcrypt.compare(password, user.passwordHash);

  if (!matches) {
    const error = new Error('Invalid email or password');
    error.statusCode = 401;
    throw error;
  }

  user.lastLoginAt = new Date();
  await user.save();

  const token = signToken(user);

  return {
    user: toPublicUser(user),
    token,
  };
};

const getCurrentUser = async (userId) => {
  const user = await User.findById(userId).select('-passwordHash');

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  return toPublicUser(user);
};

const bootstrapIdentity = async ({
  fullName,
  displayName,
  email,
  phoneNumber,
  localUserId,
  emergencyNote,
  deviceId,
}) => {
  const normalizedEmail = normalizeEmail(email);
  const safeName = (fullName || displayName || 'TrailLink User').trim();
  const safeLocalUserId = (localUserId || '').trim();

  const existingByLocalId = await User.findOne({
    $or: [
      { localUserId: safeLocalUserId },
      { bootstrapLocalUserId: safeLocalUserId },
    ],
  });

  if (existingByLocalId) {
    existingByLocalId.lastLoginAt = new Date();
    await existingByLocalId.save();
    return {
      user: toPublicUser(existingByLocalId),
      token: signToken(existingByLocalId),
    };
  }

  if (normalizedEmail) {
    const existingByEmail = await User.findOne({ email: normalizedEmail });
    if (existingByEmail) {
      const error = new Error(
        'This email is already connected to another TrailLink cloud profile.',
      );
      error.statusCode = 409;
      throw error;
    }
  }

  const unusablePassword = crypto.randomBytes(48).toString('hex');
  const passwordHash = await bcrypt.hash(unusablePassword, 12);
  const publicUserId = await generatePublicUserId();
  const user = await User.create({
    publicUserId,
    localUserId: safeLocalUserId,
    fullName: safeName,
    displayName: safeName,
    email: normalizedEmail,
    passwordHash,
    phoneNumber: phoneNumber || null,
    emergencyNote: emergencyNote || null,
    authProvider: 'bootstrap',
    isBootstrapProfile: true,
    bootstrapLocalUserId: safeLocalUserId,
    identitySource: 'local_bootstrap',
    createdFromDeviceId: deviceId || null,
    lastLoginAt: new Date(),
  });

  return {
    user: toPublicUser(user),
    token: signToken(user),
  };
};

module.exports = {
  register,
  login,
  getCurrentUser,
  bootstrapIdentity,
  toPublicUser,
};
