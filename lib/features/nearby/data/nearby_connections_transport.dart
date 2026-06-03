import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'models/nearby_advertisement_payload.dart';
import 'models/nearby_connection_status.dart';
import 'models/nearby_peer_model.dart';
import 'nearby_packet_transport.dart';

class NearbyConnectionsTransport implements NearbyPacketTransport {
  NearbyConnectionsTransport({Nearby? nearby}) : _nearby = nearby ?? Nearby();

  static const _serviceId = 'com.example.traillink.nearby';
  static const _strategy = Strategy.P2P_CLUSTER;

  final Nearby _nearby;
  final _discoveredController = StreamController<NearbyPeerModel>.broadcast();
  final _lostController = StreamController<String>.broadcast();
  final _connectionController = StreamController<NearbyPeerModel>.broadcast();
  final _packetController = StreamController<String>.broadcast();
  final Map<String, NearbyPeerModel> _peers = {};

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _currentEndpointName;
  NearbyAdvertisementPayload? _currentPayload;
  String? _activeChannelCode;
  String _displayName = 'TrailLink User';

  @override
  Stream<NearbyPeerModel> get peerDiscoveredStream =>
      _discoveredController.stream;

  @override
  Stream<String> get peerLostStream => _lostController.stream;

  @override
  Stream<NearbyPeerModel> get peerConnectionChangedStream =>
      _connectionController.stream;

  @override
  Stream<String> get packetReceivedStream => _packetController.stream;

  @override
  bool get isAdvertising => _isAdvertising;

  @override
  bool get isDiscovering => _isDiscovering;

  @override
  Future<void> startAdvertising({
    required String userId,
    required String displayName,
    required String activeChannelId,
    required String activeChannelCode,
    String? tripId,
    String? tripName,
    String? ownerLocalId,
    String? ownerName,
    String memberRole = 'member',
    String? publicUserId,
    String? appDeviceId,
    List<String> capabilities = const ['text'],
  }) async {
    _displayName = displayName;
    _activeChannelCode = activeChannelCode;
    final deviceName = await _deviceName();
    _currentPayload = NearbyAdvertisementPayload(
      userId: userId,
      displayName: displayName,
      activeChannelId: activeChannelId,
      activeChannelCode: activeChannelCode,
      deviceName: deviceName,
      timestamp: DateTime.now(),
      tripId: tripId,
      tripName: tripName,
      ownerLocalId: ownerLocalId,
      ownerName: ownerName,
      memberRole: memberRole,
      publicUserId: publicUserId,
      appDeviceId: appDeviceId,
      capabilities: capabilities,
      protocolVersion: '3.0',
    );
    _currentEndpointName = _currentPayload!.toEndpointName();

    await _bestEffortStop('restart_advertising', _nearby.stopAdvertising);
    _isAdvertising = false;
    final ok = await _nearby.startAdvertising(
      _currentEndpointName!,
      _strategy,
      serviceId: _serviceId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
    if (!ok) throw StateError('Could not make this phone visible.');
    _isAdvertising = true;
  }

  @override
  Future<void> stopAdvertising() async {
    await _nearby.stopAdvertising();
    _isAdvertising = false;
  }

  @override
  Future<void> startDiscovery({required String activeChannelCode}) async {
    _activeChannelCode = activeChannelCode;
    await _bestEffortStop('restart_discovery', _nearby.stopDiscovery);
    _isDiscovering = false;
    final ok = await _nearby.startDiscovery(
      _currentEndpointName ?? 'TrailLink',
      _strategy,
      serviceId: _serviceId,
      onEndpointFound: _onEndpointFound,
      onEndpointLost: (endpointId) {
        if (endpointId == null) return;
        final existing = _peers[endpointId];
        if (existing != null) {
          if (existing.status == PeerConnectionStatus.connected) {
            _debugNearbyPacket(
              'discovery_lost_connected_ignored',
              endpointId: endpointId,
              reason: 'Endpoint discovery was lost while connection is alive.',
            );
            return;
          }
          _emitConnection(
            existing.copyWith(
              status: PeerConnectionStatus.lost,
              lastSeenAt: DateTime.now(),
            ),
          );
        }
        _lostController.add(endpointId);
      },
    );
    if (!ok) throw StateError('Could not start finding phones.');
    _isDiscovering = true;
  }

  @override
  Future<void> stopDiscovery() async {
    await _nearby.stopDiscovery();
    _isDiscovering = false;
  }

  @override
  Future<void> connectToPeer(String endpointId) async {
    final existing = _peers[endpointId];
    if (existing != null) {
      _emitConnection(
        existing.copyWith(
          status: PeerConnectionStatus.connecting,
          lastSeenAt: DateTime.now(),
        ),
      );
    }
    final ok = await _nearby.requestConnection(
      _currentEndpointName ?? _displayName,
      endpointId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
    if (!ok) throw StateError('Could not request Nearby connection.');
  }

  @override
  Future<void> disconnectFromPeer(String endpointId) async {
    await _nearby.disconnectFromEndpoint(endpointId);
    final existing = _peers[endpointId];
    if (existing != null) {
      _emitConnection(
        existing.copyWith(
          status: PeerConnectionStatus.disconnected,
          lastSeenAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> disconnectAllPeers() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    _isAdvertising = false;
    _isDiscovering = false;
    final endpointIds = _peers.keys.toList(growable: false);
    for (final endpointId in endpointIds) {
      await _nearby.disconnectFromEndpoint(endpointId);
      final existing = _peers[endpointId];
      if (existing != null) {
        _emitConnection(
          existing.copyWith(
            status: PeerConnectionStatus.disconnected,
            lastSeenAt: DateTime.now(),
          ),
        );
      }
    }
  }

  @override
  bool isConnected(String endpointId) {
    return _peers[endpointId]?.status == PeerConnectionStatus.connected;
  }

  @override
  List<NearbyPeerModel> connectedPeersForChannel(String channelCode) {
    return _peers.values
        .where(
          (peer) =>
              peer.activeChannelCode == channelCode &&
              peer.isSameChannel &&
              peer.status == PeerConnectionStatus.connected,
        )
        .toList(growable: false);
  }

  @override
  Future<void> sendPacket({
    required String endpointId,
    required String packetJson,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(packetJson));
    _debugNearbyPacket(
      'tx_start',
      endpointId: endpointId,
      packetJson: packetJson,
      byteLength: bytes.length,
    );
    await _nearby.sendBytesPayload(
      endpointId,
      bytes,
    );
    _debugNearbyPacket(
      'tx_enqueued',
      endpointId: endpointId,
      packetJson: packetJson,
      byteLength: bytes.length,
    );
  }

  Future<void> _onConnectionInitiated(
    String endpointId,
    ConnectionInfo info,
  ) async {
    final peer = _peerFromEndpointName(
      endpointId: endpointId,
      endpointName: info.endpointName,
      fallbackStatus: PeerConnectionStatus.connecting,
    );
    if (peer != null) _emitConnection(peer);
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (id, payload) {
        if (payload.type != PayloadType.BYTES || payload.bytes == null) return;
        try {
          final packetJson = utf8.decode(payload.bytes!);
          _debugNearbyPacket(
            'rx_bytes',
            endpointId: id,
            packetJson: packetJson,
            byteLength: payload.bytes!.length,
          );
          _rememberConnectedPeerFromPacket(
            endpointId: id,
            packetJson: packetJson,
          );
          _packetController.add(packetJson);
        } catch (error) {
          _debugNearbyPacket(
            'rx_invalid_utf8',
            endpointId: id,
            byteLength: payload.bytes!.length,
            reason: error.toString(),
          );
        }
      },
      onPayloadTransferUpdate: (id, update) {
        _debugPayloadTransfer(
          endpointId: id,
          update: update,
        );
      },
    );
  }

  void _onConnectionResult(String endpointId, Status status) {
    final existing = _peers[endpointId];
    if (existing == null) return;
    final nextStatus = status == Status.CONNECTED
        ? PeerConnectionStatus.connected
        : PeerConnectionStatus.failed;
    _emitConnection(
      existing.copyWith(status: nextStatus, lastSeenAt: DateTime.now()),
    );
    if (nextStatus == PeerConnectionStatus.connected) {
      unawaited(_sendPeerHello(endpointId));
    }
  }

  void _onDisconnected(String endpointId) {
    final existing = _peers[endpointId];
    if (existing == null) return;
    _emitConnection(
      existing.copyWith(
        status: PeerConnectionStatus.disconnected,
        lastSeenAt: DateTime.now(),
      ),
    );
  }

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    if (serviceId != _serviceId) return;
    final peer = _peerFromEndpointName(
      endpointId: endpointId,
      endpointName: endpointName,
      fallbackStatus: PeerConnectionStatus.discovered,
    );
    if (peer == null || !peer.isSameChannel) return;
    _peers[endpointId] = peer;
    _discoveredController.add(peer);
  }

  NearbyPeerModel? _peerFromEndpointName({
    required String endpointId,
    required String endpointName,
    required PeerConnectionStatus fallbackStatus,
  }) {
    try {
      final payload = NearbyAdvertisementPayload.fromEndpointName(endpointName);
      if (_isCurrentDevicePayload(payload)) return null;
      final channelCode = _activeChannelCode;
      if (channelCode == null || !payload.isCompatibleWith(channelCode)) {
        return null;
      }
      final now = DateTime.now();
      final existing = _peers[endpointId];
      final status = switch (existing?.status) {
        PeerConnectionStatus.connected ||
        PeerConnectionStatus.connecting =>
          existing!.status,
        _ => fallbackStatus,
      };
      return NearbyPeerModel(
        endpointId: endpointId,
        userId: payload.userId,
        displayName: payload.displayName,
        deviceName: payload.deviceName,
        activeChannelId: payload.activeChannelId,
        activeChannelCode: payload.activeChannelCode,
        tripId: payload.tripId,
        publicUserId: payload.publicUserId,
        appDeviceId: payload.appDeviceId,
        verificationStatus: 'unknown_same_channel',
        status: status,
        discoveredAt: existing?.discoveredAt ?? now,
        lastSeenAt: now,
        isSameChannel: true,
      );
    } catch (_) {
      return null;
    }
  }

  void _emitConnection(NearbyPeerModel peer) {
    if (_isCurrentPeer(peer)) return;
    _peers[peer.endpointId] = peer;
    _connectionController.add(peer);
  }

  void _rememberConnectedPeerFromPacket({
    required String endpointId,
    required String packetJson,
  }) {
    try {
      final data = jsonDecode(packetJson) as Map<String, dynamic>;
      final packetChannelCode = data['channelCode']?.toString();
      final senderLocalId = data['senderLocalId']?.toString();
      final senderId = data['senderId']?.toString();
      if (_isCurrentSender(senderLocalId) || _isCurrentSender(senderId)) {
        return;
      }
      final channelCode = _activeChannelCode;
      if (channelCode == null ||
          packetChannelCode == null ||
          packetChannelCode != channelCode) {
        return;
      }

      final payload = data['payload'];
      final payloadMap = payload is Map<String, dynamic> ? payload : null;
      final now = DateTime.now();
      final existing = _peers[endpointId];
      final peer = NearbyPeerModel(
        endpointId: endpointId,
        userId: _stringFrom(
              payloadMap,
              'localUserId',
              fallback: data['senderLocalId']?.toString(),
            ) ??
            data['senderId']?.toString() ??
            endpointId,
        displayName: _stringFrom(
              payloadMap,
              'displayName',
              fallback: data['senderName']?.toString(),
            ) ??
            'Nearby phone',
        deviceName: _stringFrom(payloadMap, 'deviceName') ?? 'Nearby phone',
        activeChannelId: _stringFrom(
              payloadMap,
              'activeChannelId',
              fallback: data['channelId']?.toString(),
            ) ??
            '',
        activeChannelCode: packetChannelCode,
        tripId: _stringFrom(payloadMap, 'tripId'),
        publicUserId: _stringFrom(
          payloadMap,
          'publicUserId',
          fallback: data['senderId']?.toString(),
        ),
        appDeviceId: _stringFrom(payloadMap, 'appDeviceId'),
        verificationStatus:
            existing?.verificationStatus ?? 'unknown_same_channel',
        status: PeerConnectionStatus.connected,
        discoveredAt: existing?.discoveredAt ?? now,
        lastSeenAt: now,
        isSameChannel: true,
      );
      _emitConnection(peer);
      _debugNearbyPacket(
        'rx_peer_promoted',
        endpointId: endpointId,
        packetJson: packetJson,
        reason: 'Incoming packet confirmed a live same-channel endpoint.',
      );
    } catch (error) {
      _debugNearbyPacket(
        'rx_peer_promote_failed',
        endpointId: endpointId,
        packetJson: packetJson,
        reason: error.toString(),
      );
    }
  }

  bool _isCurrentDevicePayload(NearbyAdvertisementPayload payload) {
    final current = _currentPayload;
    if (current == null) return false;
    return _sameNonEmpty(payload.appDeviceId, current.appDeviceId) ||
        _sameNonEmpty(payload.publicUserId, current.publicUserId) ||
        _sameNonEmpty(payload.userId, current.userId);
  }

  bool _isCurrentPeer(NearbyPeerModel peer) {
    final current = _currentPayload;
    if (current == null) return false;
    return _sameNonEmpty(peer.appDeviceId, current.appDeviceId) ||
        _sameNonEmpty(peer.publicUserId, current.publicUserId) ||
        _sameNonEmpty(peer.userId, current.userId);
  }

  bool _isCurrentSender(String? senderId) {
    final current = _currentPayload;
    if (current == null) return false;
    return _sameNonEmpty(senderId, current.userId) ||
        _sameNonEmpty(senderId, current.publicUserId);
  }

  Future<String> _deviceName() async {
    if (!Platform.isAndroid) return 'TrailLink Device';
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}'.trim();
  }

  Future<void> _bestEffortStop(
    String action,
    Future<void> Function() stop,
  ) async {
    try {
      await stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (error) {
      _debugNearbyLifecycle(action, reason: error.toString());
    }
  }

  Future<void> _sendPeerHello(String endpointId) async {
    final payload = _currentPayload;
    if (payload == null) return;
    final packet = jsonEncode({
      'packetId': 'peer_hello_${DateTime.now().microsecondsSinceEpoch}',
      'packetType': 'peer_hello',
      'channelId': payload.activeChannelId,
      'channelCode': payload.activeChannelCode,
      'senderId': payload.publicUserId ?? payload.userId,
      'senderLocalId': payload.userId,
      'senderName': payload.displayName,
      'targetType': 'broadcast',
      'requiresAck': false,
      'payload': payload.toPeerHelloJson(),
      'tripName': payload.tripName,
      'createdAt': DateTime.now().toIso8601String(),
    });
    try {
      await sendPacket(endpointId: endpointId, packetJson: packet);
    } catch (error) {
      _debugNearbyPacket(
        'peer_hello_failed',
        endpointId: endpointId,
        packetJson: packet,
        reason: error.toString(),
      );
    }
  }

  @override
  Future<void> dispose() async {
    await _nearby.stopDiscovery();
    await _nearby.stopAdvertising();
    await _nearby.stopAllEndpoints();
    _isAdvertising = false;
    _isDiscovering = false;
    await _discoveredController.close();
    await _lostController.close();
    await _connectionController.close();
    await _packetController.close();
  }
}

bool _sameNonEmpty(String? left, String? right) {
  final leftValue = left?.trim();
  final rightValue = right?.trim();
  if (leftValue == null || leftValue.isEmpty) return false;
  if (rightValue == null || rightValue.isEmpty) return false;
  return leftValue == rightValue;
}

void _debugNearbyLifecycle(String event, {String? reason}) {
  if (!kDebugMode) return;
  debugPrint(
    '[TrailLink][NearbyLifecycle] event=$event reason=${reason ?? '-'}',
  );
}

void _debugNearbyPacket(
  String event, {
  required String endpointId,
  String? packetJson,
  int? byteLength,
  String? reason,
}) {
  if (!kDebugMode) return;
  final decoded = _packetSummary(packetJson);
  debugPrint(
    '[TrailLink][NearbyPacket] event=$event '
    'endpoint=$endpointId '
    'type=${decoded['packetType'] ?? 'unknown'} '
    'packet=${decoded['packetId'] ?? 'unknown'} '
    'channel=${decoded['channelCode'] ?? 'unknown'} '
    'bytes=${byteLength ?? 0} '
    'reason=${reason ?? '-'}',
  );
}

void _debugPayloadTransfer({
  required String endpointId,
  required PayloadTransferUpdate update,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[TrailLink][NearbyPayload] endpoint=$endpointId '
    'payload=${update.id} status=${update.status.name} '
    'bytes=${update.bytesTransferred}/${update.totalBytes}',
  );
}

Map<String, Object?> _packetSummary(String? packetJson) {
  if (packetJson == null || packetJson.isEmpty) return const {};
  try {
    final data = jsonDecode(packetJson) as Map<String, dynamic>;
    return {
      'packetId': data['packetId']?.toString(),
      'packetType': data['packetType']?.toString(),
      'channelCode': data['channelCode']?.toString(),
    };
  } catch (_) {
    return const {};
  }
}

String? _stringFrom(
  Map<String, dynamic>? data,
  String key, {
  String? fallback,
}) {
  final value = data?[key]?.toString().trim();
  if (value != null && value.isNotEmpty) return value;
  final fallbackValue = fallback?.trim();
  if (fallbackValue != null && fallbackValue.isNotEmpty) {
    return fallbackValue;
  }
  return null;
}
