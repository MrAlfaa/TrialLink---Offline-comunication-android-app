import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env_config.dart';

class RecordedVoiceClip {
  const RecordedVoiceClip({
    required this.filePath,
    required this.durationMs,
    required this.fileSizeBytes,
  });

  final String filePath;
  final int durationMs;
  final int fileSizeBytes;
}

class PttAudioService {
  PttAudioService({
    AudioRecorder? recorder,
    AudioPlayer? player,
    Uuid? uuid,
  })  : _recorder = recorder ?? AudioRecorder(),
        _player = player ?? AudioPlayer(),
        _uuid = uuid ?? const Uuid();

  final AudioRecorder _recorder;
  final AudioPlayer _player;
  final Uuid _uuid;
  DateTime? _recordingStartedAt;
  String? _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> startRecording() async {
    if (!await hasPermission()) {
      throw StateError('Microphone permission is required for voice notes.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final voiceDir = Directory('${dir.path}/voice_notes');
    if (!voiceDir.existsSync()) voiceDir.createSync(recursive: true);
    final path = '${voiceDir.path}/voice_${_uuid.v4()}.m4a';
    _recordingStartedAt = DateTime.now();
    _currentPath = path;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  Future<RecordedVoiceClip?> stopRecording() async {
    final fallbackPath = _currentPath;
    final path = await _recorder.stop();
    final started = _recordingStartedAt;
    _recordingStartedAt = null;
    _currentPath = null;
    final filePath = path ?? fallbackPath;
    if (filePath == null || started == null) return null;
    final file = File(filePath);
    if (!file.existsSync()) return null;
    return RecordedVoiceClip(
      filePath: filePath,
      durationMs: DateTime.now().difference(started).inMilliseconds,
      fileSizeBytes: await file.length(),
    );
  }

  Future<void> play(String pathOrUrl) async {
    final source = pathOrUrl.startsWith('/uploads')
        ? '${EnvConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '')}$pathOrUrl'
        : pathOrUrl;
    if (source.startsWith('http')) {
      await _player.setUrl(source);
    } else {
      await _player.setFilePath(source);
    }
    await _player.play();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    await _player.dispose();
  }
}
