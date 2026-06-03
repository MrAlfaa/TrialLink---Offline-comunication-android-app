import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:record/record.dart';

class LiveAudioChunk {
  const LiveAudioChunk({
    required this.streamId,
    required this.sequence,
    required this.bytes,
    required this.createdAt,
    this.chunkDurationMs = LiveRadioAudioService.chunkDurationMs,
  });

  final String streamId;
  final int sequence;
  final Uint8List bytes;
  final DateTime createdAt;
  final int chunkDurationMs;
}

typedef LiveAudioChunkHandler = Future<void> Function(LiveAudioChunk chunk);
typedef LiveAudioChunkErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

class LiveRadioAudioService {
  LiveRadioAudioService({
    AudioRecorder? recorder,
    fs.FlutterSoundPlayer? player,
  })  : _recorder = recorder ?? AudioRecorder(),
        _player = player ?? fs.FlutterSoundPlayer();

  static const sampleRate = 16000;
  static const numChannels = 1;
  static const chunkDurationMs = 200;
  static const jitterBufferDelayMs = 600;
  static const incomingIdleTimeoutMs = 3000;
  static const _bytesPerSample = 2;
  static const _chunkBytes =
      sampleRate * numChannels * _bytesPerSample * chunkDurationMs ~/ 1000;

  final AudioRecorder _recorder;
  final fs.FlutterSoundPlayer _player;
  final _incoming = <String, _IncomingLiveStream>{};
  StreamSubscription<Uint8List>? _recordingSubscription;
  final List<int> _outgoingBuffer = [];
  Timer? _incomingCleanupTimer;
  Future<void> _feedQueue = Future<void>.value();
  bool _playerOpened = false;
  bool _playerStreaming = false;
  bool _incomingPlaybackFailed = false;
  bool _recording = false;
  int _sequence = 0;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startOutgoingStream({
    required String streamId,
    required LiveAudioChunkHandler onChunk,
    LiveAudioChunkErrorHandler? onChunkError,
  }) async {
    if (_recording) {
      throw StateError('Live Radio is already streaming.');
    }
    if (!await hasPermission()) {
      throw StateError('Microphone permission is required for Live Radio.');
    }
    _sequence = 0;
    _outgoingBuffer.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: numChannels,
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: _chunkBytes,
      ),
    );
    _recording = true;
    _recordingSubscription = stream.listen((data) {
      _outgoingBuffer.addAll(data);
      while (_outgoingBuffer.length >= _chunkBytes) {
        final chunk =
            Uint8List.fromList(_outgoingBuffer.take(_chunkBytes).toList());
        _outgoingBuffer.removeRange(0, _chunkBytes);
        unawaited(
          onChunk(
            LiveAudioChunk(
              streamId: streamId,
              sequence: _sequence++,
              bytes: chunk,
              createdAt: DateTime.now(),
            ),
          ).catchError((Object error, StackTrace stackTrace) {
            onChunkError?.call(error, stackTrace);
          }),
        );
      }
    });
  }

  Future<void> stopOutgoingStream() async {
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    if (_recording) {
      await _recorder.stop();
      _recording = false;
    }
    _outgoingBuffer.clear();
  }

  Future<void> startIncomingStream({
    required String streamId,
    required String senderName,
  }) async {
    _incoming.putIfAbsent(
      streamId,
      () => _IncomingLiveStream(
        streamId: streamId,
        senderName: senderName,
        startedAt: DateTime.now(),
      ),
    );
    await _ensurePlayerStreaming();
    _startIncomingCleanupTimer();
    _incoming[streamId]?.startPump(_feedChunk);
  }

  Future<void> addIncomingChunk(LiveAudioChunk chunk) async {
    final stream = _incoming[chunk.streamId];
    if (stream == null) return;
    stream.add(chunk);
  }

  Future<void> endIncomingStream(String streamId) async {
    final stream = _incoming.remove(streamId);
    stream?.dispose();
    if (_incoming.isEmpty) {
      _incomingCleanupTimer?.cancel();
      _incomingCleanupTimer = null;
      await _stopPlayerStream();
    }
  }

  Future<void> stopAll() async {
    await stopOutgoingStream();
    await stopIncomingStreams();
  }

  Future<void> stopIncomingStreams() async {
    for (final stream in _incoming.values) {
      stream.dispose();
    }
    _incoming.clear();
    _incomingCleanupTimer?.cancel();
    _incomingCleanupTimer = null;
    await _stopPlayerStream();
  }

  Future<void> dispose() async {
    await stopAll();
    await _recorder.dispose();
    if (_playerOpened) {
      await _player.closePlayer();
      _playerOpened = false;
    }
  }

  Future<void> _ensurePlayerStreaming() async {
    if (!_playerOpened) {
      await _player.openPlayer();
      _playerOpened = true;
    }
    if (_playerStreaming) return;
    _incomingPlaybackFailed = false;
    await _player.startPlayerFromStream(
      codec: fs.Codec.pcm16,
      interleaved: true,
      numChannels: numChannels,
      sampleRate: sampleRate,
      bufferSize: _chunkBytes * 6,
    );
    _playerStreaming = true;
  }

  Future<void> _feedChunk(Uint8List bytes) async {
    if (!_playerStreaming || _incomingPlaybackFailed) return;
    if (bytes.length != _chunkBytes) return;
    final chunk = Uint8List.fromList(bytes);
    _feedQueue =
        _feedQueue.then((_) => _safeFeedChunk(chunk)).catchError((_) {});
    await _feedQueue;
  }

  Future<void> _safeFeedChunk(Uint8List bytes) async {
    if (!_playerStreaming || _incomingPlaybackFailed) return;
    try {
      await _player.feedUint8FromStream(bytes);
    } catch (_) {
      _incomingPlaybackFailed = true;
      _playerStreaming = false;
      try {
        await _player.stopPlayer();
      } catch (_) {
        // Native audio playback can fail on some devices; do not crash P2P.
      }
    }
  }

  Future<void> _stopPlayerStream() async {
    if (!_playerStreaming) return;
    _playerStreaming = false;
    try {
      await _feedQueue.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    } catch (_) {
      // Playback is best-effort; stopping the stream must always complete.
    }
    await _player.stopPlayer();
    _feedQueue = Future<void>.value();
  }

  void _startIncomingCleanupTimer() {
    _incomingCleanupTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final expired = _incoming.values
          .where((stream) => stream.isIdleTimedOut)
          .map((stream) => stream.streamId)
          .toList();
      if (expired.isEmpty) return;
      for (final streamId in expired) {
        final stream = _incoming.remove(streamId);
        stream?.dispose();
      }
      if (_incoming.isEmpty) {
        _incomingCleanupTimer?.cancel();
        _incomingCleanupTimer = null;
        unawaited(_stopPlayerStream());
      }
    });
  }
}

class _IncomingLiveStream {
  _IncomingLiveStream({
    required this.streamId,
    required this.senderName,
    required this.startedAt,
  });

  final String streamId;
  final String senderName;
  final DateTime startedAt;
  final _buffer = SplayTreeMap<int, LiveAudioChunk>();
  Timer? _pumpTimer;
  int _nextSequence = 0;
  DateTime _lastActivityAt = DateTime.now();
  bool _feeding = false;

  bool get isIdleTimedOut {
    return DateTime.now().difference(_lastActivityAt).inMilliseconds >
        LiveRadioAudioService.incomingIdleTimeoutMs;
  }

  void add(LiveAudioChunk chunk) {
    _lastActivityAt = DateTime.now();
    _buffer[chunk.sequence] = chunk;
  }

  void startPump(Future<void> Function(Uint8List bytes) feed) {
    _pumpTimer ??= Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_feeding) return;
      final now = DateTime.now();
      final next = _buffer.remove(_nextSequence);
      if (next != null) {
        _nextSequence++;
        _feedOne(feed, next.bytes);
        return;
      }
      if (_buffer.isEmpty) return;
      final oldest = _buffer.values.first;
      final age = now.difference(oldest.createdAt).inMilliseconds;
      if (age >= LiveRadioAudioService.jitterBufferDelayMs) {
        _nextSequence = oldest.sequence + 1;
        _buffer.remove(oldest.sequence);
        _feedOne(feed, oldest.bytes);
      }
    });
  }

  void _feedOne(
    Future<void> Function(Uint8List bytes) feed,
    Uint8List bytes,
  ) {
    _feeding = true;
    unawaited(
      feed(bytes).whenComplete(() {
        _feeding = false;
      }),
    );
  }

  void dispose() {
    _pumpTimer?.cancel();
    _buffer.clear();
    _feeding = false;
  }
}
