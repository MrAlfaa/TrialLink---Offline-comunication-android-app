const path = require('path');

const VoiceNote = require('../../models/voiceNote.model');
const { ensureUserActiveGroupMember } = require('../groups/membership.service');

const toVoiceNoteDto = (voiceNote) => {
  const sender = voiceNote.senderId;
  return {
    voiceNoteId: voiceNote._id.toString(),
    clientVoiceId: voiceNote.clientVoiceId,
    groupId: voiceNote.groupId?.toString?.() || voiceNote.groupId,
    sender: {
      id: sender?._id?.toString?.() || sender?.toString?.() || voiceNote.senderId.toString(),
      fullName: sender?.fullName || 'TrailLink User',
    },
    audioUrl: voiceNote.audioUrl,
    durationMs: voiceNote.durationMs,
    fileSizeBytes: voiceNote.fileSizeBytes,
    status: voiceNote.status,
    createdAt: voiceNote.createdAt,
  };
};

const createOrFindVoiceNote = async ({ groupId, userId, body, file }) => {
  await ensureUserActiveGroupMember(userId, groupId);

  if (!file) {
    const error = new Error('Audio file is required');
    error.statusCode = 422;
    throw error;
  }

  const existing = await VoiceNote.findOne({
    clientVoiceId: body.clientVoiceId,
    senderId: userId,
  }).populate('senderId', 'fullName email');

  if (existing) return { voiceNote: existing, created: false };

  const audioUrl = `/uploads/voice-notes/${path.basename(file.filename)}`;
  const voiceNote = await VoiceNote.create({
    clientVoiceId: body.clientVoiceId,
    groupId,
    senderId: userId,
    audioUrl,
    durationMs: body.durationMs == null ? undefined : Number(body.durationMs),
    fileSizeBytes: file.size,
    ...(body.createdAt ? { createdAt: new Date(body.createdAt) } : {}),
  });
  await voiceNote.populate('senderId', 'fullName email');

  return { voiceNote, created: true };
};

const listVoiceNotes = async ({ groupId, userId, limit = 30 }) => {
  await ensureUserActiveGroupMember(userId, groupId);
  const numericLimit = Math.min(Math.max(Number.parseInt(limit, 10) || 30, 1), 100);
  const notes = await VoiceNote.find({ groupId })
    .populate('senderId', 'fullName email')
    .sort({ createdAt: -1 })
    .limit(numericLimit);
  return notes.reverse().map(toVoiceNoteDto);
};

module.exports = {
  createOrFindVoiceNote,
  listVoiceNotes,
  toVoiceNoteDto,
};
