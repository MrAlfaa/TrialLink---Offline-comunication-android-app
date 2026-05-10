const mongoose = require('mongoose');

const tripChannelSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    channelId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    tripId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    channelName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    channelCode: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
      maxlength: 40,
    },
    isPrimary: { type: Boolean, default: false },
    isActive: { type: Boolean, default: false, index: true },
    channelStatus: {
      type: String,
      enum: ['active', 'inactive', 'ended', 'archived'],
      default: 'active',
    },
    clientCreatedAt: Date,
    clientUpdatedAt: Date,
  },
  { timestamps: true },
);

tripChannelSchema.index({ ownerId: 1, channelId: 1 }, { unique: true });
tripChannelSchema.index({ ownerId: 1, tripId: 1, isActive: 1 });

module.exports = mongoose.model('TripChannel', tripChannelSchema);
