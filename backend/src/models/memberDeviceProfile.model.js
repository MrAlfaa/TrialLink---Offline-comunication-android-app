const mongoose = require('mongoose');

const memberDeviceProfileSchema = new mongoose.Schema(
  {
    tripId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    channelId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    cloudGroupId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    publicUserId: {
      type: String,
      trim: true,
      default: null,
      index: true,
    },
    localUserId: {
      type: String,
      trim: true,
      default: null,
      index: true,
    },
    appDeviceId: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
      index: true,
    },
    displayName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    phoneNumber: {
      type: String,
      trim: true,
      default: null,
    },
    capabilities: {
      supportsNearby: { type: Boolean, default: true },
      supportsPtt: { type: Boolean, default: false },
      supportsLiveRadio: { type: Boolean, default: false },
    },
    lastSeenAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true },
);

memberDeviceProfileSchema.index(
  { tripId: 1, userId: 1, appDeviceId: 1 },
  { unique: true },
);
memberDeviceProfileSchema.index({ tripId: 1, publicUserId: 1 });
memberDeviceProfileSchema.index({ tripId: 1, localUserId: 1 });

module.exports = mongoose.model(
  'MemberDeviceProfile',
  memberDeviceProfileSchema,
);
