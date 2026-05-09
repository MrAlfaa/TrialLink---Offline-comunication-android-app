const mongoose = require('mongoose');

const locationUpdateSchema = new mongoose.Schema(
  {
    clientLocationId: {
      type: String,
      required: true,
      index: true,
      trim: true,
    },
    groupId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Group',
      required: true,
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    latitude: {
      type: Number,
      required: true,
    },
    longitude: {
      type: Number,
      required: true,
    },
    accuracy: Number,
    altitude: Number,
    speed: Number,
    heading: Number,
    capturedAt: {
      type: Date,
      required: true,
      index: true,
    },
    sourcePath: {
      type: String,
      enum: ['online', 'offline', 'bridge'],
      default: 'online',
      index: true,
    },
    originLocalId: { type: String, trim: true, index: true },
    originDisplayName: { type: String, trim: true, maxlength: 100 },
    originBackendId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    originIdentityType: {
      type: String,
      enum: ['authenticated_cached', 'guest', 'verified'],
    },
    bridgedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    bridgedByLocalId: { type: String, trim: true },
    bridgedByName: { type: String, trim: true, maxlength: 100 },
    bridgedAt: Date,
    originalPacketId: { type: String, trim: true, index: true },
    channelCode: { type: String, trim: true, uppercase: true },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  },
);

locationUpdateSchema.index({ clientLocationId: 1, userId: 1 }, { unique: true });
locationUpdateSchema.index({ originLocalId: 1, clientLocationId: 1, sourcePath: 1 });
locationUpdateSchema.index({ groupId: 1, userId: 1, capturedAt: -1 });

module.exports = mongoose.model('LocationUpdate', locationUpdateSchema);
