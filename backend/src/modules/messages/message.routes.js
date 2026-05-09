const express = require('express');
const fs = require('fs');
const multer = require('multer');
const path = require('path');
const messageController = require('./message.controller');
const {
  listMessagesValidation,
  mediaMessageValidation,
  syncMessagesValidation,
  validate,
} = require('./message.validation');

const router = express.Router({ mergeParams: true });
const uploadDir = path.join(__dirname, '../../../uploads/chat-media');
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const safeClientId = (req.body.clientMessageId || 'media').replace(/[^a-zA-Z0-9_-]/g, '');
    const ext = path.extname(file.originalname || '') || (file.mimetype.startsWith('audio/') ? '.m4a' : '.jpg');
    cb(null, `${Date.now()}-${safeClientId}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const type = req.body.messageType;
    if (type === 'file') {
      const error = new Error('File attachments are not enabled yet');
      error.statusCode = 422;
      return cb(error);
    }
    if (type === 'image' && !file.mimetype.startsWith('image/')) {
      const error = new Error('Only image files are allowed');
      error.statusCode = 422;
      return cb(error);
    }
    if (type === 'voice' && !file.mimetype.startsWith('audio/')) {
      const error = new Error('Only audio files are allowed');
      error.statusCode = 422;
      return cb(error);
    }
    return cb(null, true);
  },
});

router.get('/', listMessagesValidation, validate, messageController.getGroupMessages);
router.post(
  '/media',
  upload.single('file'),
  mediaMessageValidation,
  validate,
  messageController.uploadMediaMessage,
);
router.post('/sync', syncMessagesValidation, validate, messageController.syncGroupMessages);

module.exports = router;
