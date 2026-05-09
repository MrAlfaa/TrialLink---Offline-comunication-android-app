import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/env_config.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'models/send_message_request.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.disconnect);
  return service;
});

enum ChatSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class SocketService {
  SocketService({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService.instance;

  final SecureStorageService _storage;
  final _statusController = StreamController<ChatSocketStatus>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _ackController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _emergencyAckController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _pttGrantedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _pttDeniedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _pttSpeakerChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _pttSpeakerReleasedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _voiceNoteController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _groupArchivedController =
      StreamController<Map<String, dynamic>>.broadcast();

  io.Socket? _socket;
  String? _activeGroupId;

  Stream<ChatSocketStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get ackStream => _ackController.stream;
  Stream<Map<String, dynamic>> get errorStream => _errorController.stream;
  Stream<Map<String, dynamic>> get emergencyStream =>
      _emergencyController.stream;
  Stream<Map<String, dynamic>> get emergencyAckStream =>
      _emergencyAckController.stream;
  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;
  Stream<Map<String, dynamic>> get pttGrantedStream =>
      _pttGrantedController.stream;
  Stream<Map<String, dynamic>> get pttDeniedStream =>
      _pttDeniedController.stream;
  Stream<Map<String, dynamic>> get pttSpeakerChangedStream =>
      _pttSpeakerChangedController.stream;
  Stream<Map<String, dynamic>> get pttSpeakerReleasedStream =>
      _pttSpeakerReleasedController.stream;
  Stream<Map<String, dynamic>> get voiceNoteStream =>
      _voiceNoteController.stream;
  Stream<Map<String, dynamic>> get groupArchivedStream =>
      _groupArchivedController.stream;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (isConnected) return;

    final token = await _storage.readToken();
    if (token == null || token.isEmpty || EnvConfig.socketBaseUrl.isEmpty) {
      _statusController.add(ChatSocketStatus.error);
      return;
    }

    _statusController.add(ChatSocketStatus.connecting);
    _socket?.dispose();
    _socket = io.io(
      EnvConfig.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(900)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _statusController.add(ChatSocketStatus.connected);
        final groupId = _activeGroupId;
        if (groupId != null) {
          joinGroup(groupId);
        }
      })
      ..onDisconnect(
          (_) => _statusController.add(ChatSocketStatus.disconnected))
      ..onReconnectAttempt(
          (_) => _statusController.add(ChatSocketStatus.reconnecting))
      ..onConnectError((_) => _statusController.add(ChatSocketStatus.error))
      ..on('new_group_message', (data) {
        if (data is Map) {
          _messageController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('message_sent_ack', (data) {
        if (data is Map) {
          _ackController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('socket_error', (data) {
        if (data is Map) {
          _errorController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('emergency_alert', (data) {
        if (data is Map) {
          _emergencyController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('emergency_ack', (data) {
        if (data is Map) {
          _emergencyAckController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('location_update', (data) {
        if (data is Map) {
          _locationController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('ptt_granted', (data) {
        if (data is Map) {
          _pttGrantedController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('ptt_denied', (data) {
        if (data is Map) {
          _pttDeniedController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('ptt_speaker_changed', (data) {
        if (data is Map) {
          _pttSpeakerChangedController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('ptt_speaker_released', (data) {
        if (data is Map) {
          _pttSpeakerReleasedController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('voice_note_received', (data) {
        if (data is Map) {
          _voiceNoteController.add(Map<String, dynamic>.from(data));
        }
      })
      ..on('group_archived', (data) {
        if (data is Map) {
          _groupArchivedController.add(Map<String, dynamic>.from(data));
        }
      })
      ..connect();
  }

  void joinGroup(String groupId) {
    _activeGroupId = groupId;
    _socket?.emit('join_group', {'groupId': groupId});
  }

  void leaveGroup(String groupId) {
    if (_activeGroupId == groupId) {
      _activeGroupId = null;
    }
    _socket?.emit('leave_group', {'groupId': groupId});
  }

  void sendGroupMessage(SendMessageRequest request) {
    _socket?.emit('send_group_message', request.toJson());
  }

  void acknowledgeEmergency({
    required String groupId,
    required String eventId,
    String note = 'Received',
  }) {
    _socket?.emit('ack_emergency', {
      'groupId': groupId,
      'eventId': eventId,
      'note': note,
    });
  }

  void requestPttFloor({
    required String groupId,
    required String clientRequestId,
  }) {
    _socket?.emit('ptt_request', {
      'groupId': groupId,
      'clientRequestId': clientRequestId,
      'requestedAt': DateTime.now().toIso8601String(),
    });
  }

  void releasePttFloor({required String groupId}) {
    _socket?.emit('ptt_release', {
      'groupId': groupId,
      'releasedAt': DateTime.now().toIso8601String(),
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _statusController.add(ChatSocketStatus.disconnected);
  }
}
