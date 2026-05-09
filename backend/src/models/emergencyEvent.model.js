const mongoose = require('mongoose');

const acknowledgementSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    acknowledgedAt: {
      type: Date,
      default: Date.now,
    },
    note: {
      type: String,
      trim: true,
      maxlength: 300,
    },
  },
  { _id: false },
);

const emergencyEventSchema = new mongoose.Schema(
  {
    clientEventId: {
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
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    alertType: {
      type: String,
      enum: ['sos', 'medical', 'lost', 'danger', 'help', 'custom'],
      default: 'sos',
    },
    message: {
      type: String,
      trim: true,
      maxlength: 500,
    },
    priority: {
      type: String,
      enum: ['high', 'emergency'],
      default: 'emergency',
    },
    location: {
      latitude: Number,
      longitude: Number,
      accuracy: Number,
      capturedAt: Date,
    },
    status: {
      type: String,
      enum: ['active', 'acknowledged', 'resolved', 'cancelled'],
      default: 'active',
      index: true,
    },
    acknowledgements: [acknowledgementSchema],
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
    timestamps: true,
  },
);

emergencyEventSchema.index({ clientEventId: 1, senderId: 1 }, { unique: true });
emergencyEventSchema.index({ originLocalId: 1, clientEventId: 1, sourcePath: 1 });
emergencyEventSchema.index({ groupId: 1, createdAt: -1 });

module.exports = mongoose.model('EmergencyEvent', emergencyEventSchema);
