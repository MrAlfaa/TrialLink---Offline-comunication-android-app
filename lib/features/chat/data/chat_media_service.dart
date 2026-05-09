import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/env_config.dart';

class PickedChatMedia {
  const PickedChatMedia({
    required this.localFilePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.messageType,
    this.durationMs,
  });

  final String localFilePath;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final String messageType;
  final int? durationMs;
}

class ChatMediaService {
  ChatMediaService({
    ImagePicker? picker,
    AudioRecorder? recorder,
    AudioPlayer? player,
    Uuid? uuid,
  })  : _picker = picker ?? ImagePicker(),
        _recorder = recorder ?? AudioRecorder(),
        _player = player ?? AudioPlayer(),
        _uuid = uuid ?? const Uuid();

  final ImagePicker _picker;
  final AudioRecorder _recorder;
  final AudioPlayer _player;
  final Uuid _uuid;
  DateTime? _recordingStartedAt;
  String? _recordingPath;

  Future<PickedChatMedia?> pickImageFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (image == null) return null;
    final copied = await _copyToChatMedia(
      sourcePath: image.path,
      preferredName: image.name,
      prefix: 'image',
    );
    return PickedChatMedia(
      localFilePath: copied.path,
      fileName: path.basename(copied.path),
      fileSizeBytes: await copied.length(),
      mimeType: _mimeTypeFor(copied.path, fallback: 'image/jpeg'),
      messageType: 'image',
    );
  }

  Future<void> startVoiceRecording() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required for voice notes.');
    }
    final dir = await _chatMediaDir();
    final filePath = path.join(dir.path, 'voice_${_uuid.v4()}.m4a');
    _recordingStartedAt = DateTime.now();
    _recordingPath = filePath;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: filePath,
    );
  }

  Future<PickedChatMedia?> stopVoiceRecording() async {
    final fallbackPath = _recordingPath;
    final startedAt = _recordingStartedAt;
    final filePath = await _recorder.stop() ?? fallbackPath;
    _recordingStartedAt = null;
    _recordingPath = null;
    if (filePath == null || startedAt == null) return null;
    final file = File(filePath);
    if (!file.existsSync()) return null;
    return PickedChatMedia(
      localFilePath: file.path,
      fileName: path.basename(file.path),
      fileSizeBytes: await file.length(),
      mimeType: 'audio/mp4',
      messageType: 'voice',
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
  }

  Future<void> cancelVoiceRecording() async {
    await _recorder.cancel();
    final filePath = _recordingPath;
    _recordingStartedAt = null;
    _recordingPath = null;
    if (filePath != null) {
      final file = File(filePath);
      if (file.existsSync()) await file.delete();
    }
  }

  Future<bool> localFileExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    return File(filePath).exists();
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

  Future<File> _copyToChatMedia({
    required String sourcePath,
    required String preferredName,
    required String prefix,
  }) async {
    final source = File(sourcePath);
    final dir = await _chatMediaDir();
    final extension = path.extension(preferredName).isEmpty
        ? path.extension(sourcePath)
        : path.extension(preferredName);
    final fileName = '${prefix}_${_uuid.v4()}$extension';
    return source.copy(path.join(dir.path, fileName));
  }

  Future<Directory> _chatMediaDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(dir.path, 'chat_media'));
    if (!mediaDir.existsSync()) mediaDir.createSync(recursive: true);
    return mediaDir;
  }

  String _mimeTypeFor(String filePath, {required String fallback}) {
    return switch (path.extension(filePath).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.heic' => 'image/heic',
      '.m4a' => 'audio/mp4',
      '.aac' => 'audio/aac',
      '.mp3' => 'audio/mpeg',
      _ => fallback,
    };
  }
}
