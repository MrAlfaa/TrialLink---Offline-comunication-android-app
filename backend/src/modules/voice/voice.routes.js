const express = require('express');
const multer = require('multer');
const path = require('path');

const voiceController = require('./voice.controller');
const {
  listVoiceNotesValidation,
  uploadVoiceNoteValidation,
  validate,
} = require('./voice.validation');

const uploadDir = path.join(__dirname, '../../../uploads/voice-notes');
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const safeClientId = (req.body.clientVoiceId || 'voice').replace(/[^a-zA-Z0-9_-]/g, '');
    const ext = path.extname(file.originalname || '.m4a') || '.m4a';
    cb(null, `${Date.now()}-${safeClientId}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: {
    fileSize: 2 * 1024 * 1024,
  },
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('audio/')) {
      return cb(new Error('Only audio files are allowed'));
    }
    return cb(null, true);
  },
});

const router = express.Router({ mergeParams: true });

router.post(
  '/',
  upload.single('audio'),
  uploadVoiceNoteValidation,
  validate,
  voiceController.uploadVoiceNote,
);

router.get('/', listVoiceNotesValidation, validate, voiceController.listVoiceNotes);

module.exports = router;
