const express = require('express');

const router = express.Router();

const minDownloadBytes = 4096;
const maxDownloadBytes = 1024 * 1024;
const maxUploadBytes = 256 * 1024;
const requestWindowMs = 60 * 1000;
const maxRequestsPerWindow = 40;
const requestBuckets = new Map();

function rateLimitProbe(req, res, next) {
  const key = req.ip || req.socket?.remoteAddress || 'unknown';
  const now = Date.now();
  const bucket = requestBuckets.get(key) || { count: 0, resetAt: now + requestWindowMs };

  if (bucket.resetAt <= now) {
    bucket.count = 0;
    bucket.resetAt = now + requestWindowMs;
  }

  bucket.count += 1;
  requestBuckets.set(key, bucket);

  if (bucket.count > maxRequestsPerWindow) {
    return res.status(429).json({
      message: 'Network check is running too often. Wait a moment and try again.',
    });
  }

  return next();
}

function boundedBytes(value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) return 262144;
  return Math.min(Math.max(parsed, minDownloadBytes), maxDownloadBytes);
}

router.use(rateLimitProbe);

router.get('/ping', (_req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({
    ok: true,
    serverTime: new Date().toISOString(),
  });
});

router.get('/download', (req, res) => {
  const bytes = boundedBytes(req.query.bytes);
  res.set({
    'Cache-Control': 'no-store',
    'Content-Type': 'application/octet-stream',
    'Content-Length': bytes.toString(),
  });
  res.send(Buffer.alloc(bytes, 't'));
});

router.post('/upload', (req, res) => {
  const size = Buffer.byteLength(JSON.stringify(req.body || {}), 'utf8');
  if (size > maxUploadBytes) {
    return res.status(413).json({
      message: 'Upload probe is too large.',
      maxBytes: maxUploadBytes,
    });
  }

  return res.json({
    ok: true,
    receivedBytes: size,
    serverTime: new Date().toISOString(),
  });
});

module.exports = router;
