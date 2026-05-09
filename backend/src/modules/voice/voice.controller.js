const voiceService = require('./voice.service');
const { sendSuccess } = require('../../utils/response');
const { emitVoiceNoteReceived } = require('../../socket/socket');

const uploadVoiceNote = async (req, res, next) => {
  try {
    const result = await voiceService.createOrFindVoiceNote({
      groupId: req.params.groupId,
      userId: req.user._id,
      body: req.body,
      file: req.file,
    });
    const voiceNote = voiceService.toVoiceNoteDto(result.voiceNote);
    if (result.created) emitVoiceNoteReceived(req.params.groupId, voiceNote);
    return sendSuccess(
      res,
      result.created ? 'Voice note uploaded successfully' : 'Voice note already exists',
      { data: { voiceNote } },
      result.created ? 201 : 200,
    );
  } catch (error) {
    next(error);
  }
};

const listVoiceNotes = async (req, res, next) => {
  try {
    const voiceNotes = await voiceService.listVoiceNotes({
      groupId: req.params.groupId,
      userId: req.user._id,
      limit: req.query.limit,
    });
    return sendSuccess(res, 'Voice notes fetched successfully', {
      data: { voiceNotes },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  listVoiceNotes,
  uploadVoiceNote,
};
