const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    clientMessageId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    groupId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Group',
      required: true,
      index: true,
    },
    tripId: { type: String, trim: true, index: true },
    channelId: { type: String, trim: true, index: true },
    chatId: { type: String, trim: true, index: true },
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    messageType: {
      type: String,
      enum: ['text', 'image', 'voice', 'file'],
      default: 'text',
    },
    content: {
      type: String,
      trim: true,
      maxlength: 2000,
      default: '',
    },
    mediaUrl: { type: String, trim: true },
    fileName: { type: String, trim: true, maxlength: 255 },
    fileSizeBytes: { type: Number, min: 0 },
    mimeType: { type: String, trim: true, maxlength: 100 },
    durationMs: { type: Number, min: 0 },
    thumbnailUrl: { type: String, trim: true },
    status: {
      type: String,
      enum: ['sent', 'delivered'],
      default: 'sent',
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
    timestamps: true,
  },
);

messageSchema.index({ clientMessageId: 1, senderId: 1 }, { unique: true });
messageSchema.index({ originLocalId: 1, clientMessageId: 1, sourcePath: 1 });
messageSchema.index({ groupId: 1, createdAt: -1 });
messageSchema.index({ tripId: 1, channelId: 1, chatId: 1, createdAt: -1 });

module.exports = mongoose.model('Message', messageSchema);
