const mongoose = require('mongoose');

const tripSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    tripId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    tripName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    status: {
      type: String,
      enum: ['active', 'inactive', 'archived', 'completed'],
      default: 'inactive',
      index: true,
    },
    mode: {
      type: String,
      enum: ['online', 'offline', 'hybrid'],
      default: 'offline',
    },
    activeChannelId: { type: String, trim: true },
    cloudGroupId: { type: String, trim: true },
    lastOpenedAt: Date,
    clientCreatedAt: Date,
    clientUpdatedAt: Date,
  },
  { timestamps: true },
);

tripSchema.index({ ownerId: 1, tripId: 1 }, { unique: true });
tripSchema.index({ ownerId: 1, status: 1, lastOpenedAt: -1 });

module.exports = mongoose.model('Trip', tripSchema);
