const mongoose = require('mongoose');

const chatRoomSchema = new mongoose.Schema(
  {
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    chatId: {
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
    channelId: { type: String, trim: true, index: true },
    cloudGroupId: { type: String, trim: true },
    chatName: {
      type: String,
      required: true,
      trim: true,
      maxlength: 120,
    },
    chatType: {
      type: String,
      enum: ['cloud_group', 'offline_channel', 'trip_general'],
      required: true,
    },
    isDefault: { type: Boolean, default: false },
    isActive: { type: Boolean, default: false, index: true },
    chatStatus: {
      type: String,
      enum: ['active', 'inactive', 'archived', 'read_only'],
      default: 'active',
    },
    clientCreatedAt: Date,
    clientUpdatedAt: Date,
  },
  { timestamps: true },
);

chatRoomSchema.index({ ownerId: 1, chatId: 1 }, { unique: true });
chatRoomSchema.index({ ownerId: 1, tripId: 1, channelId: 1, isActive: 1 });

module.exports = mongoose.model('ChatRoom', chatRoomSchema);
