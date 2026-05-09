const mongoose = require('mongoose');

const voiceNoteSchema = new mongoose.Schema({
  clientVoiceId: {
    type: String,
    required: true,
    index: true,
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
  audioUrl: {
    type: String,
    required: true,
  },
  durationMs: Number,
  fileSizeBytes: Number,
  status: {
    type: String,
    enum: ['sent', 'delivered'],
    default: 'sent',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

voiceNoteSchema.index({ clientVoiceId: 1, senderId: 1 }, { unique: true });

module.exports = mongoose.model('VoiceNote', voiceNoteSchema);
