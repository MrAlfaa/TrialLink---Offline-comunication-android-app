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

  String? _currentEndpointName;
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
  Future<void> startAdvertising({
    required String userId,
    required String displayName,
    required String activeChannelId,
    required String activeChannelCode,
  }) async {
    _displayName = displayName;
    _activeChannelCode = activeChannelCode;
    final deviceName = await _deviceName();
    _currentEndpointName = NearbyAdvertisementPayload(
      userId: userId,
      displayName: displayName,
      activeChannelId: activeChannelId,
      activeChannelCode: activeChannelCode,
      deviceName: deviceName,
      timestamp: DateTime.now(),
    ).toEndpointName();

    final ok = await _nearby.startAdvertising(
      _currentEndpointName!,
      _strategy,
      serviceId: _serviceId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
    if (!ok) throw StateError('Could not start Nearby advertising.');
  }

  @override
  Future<void> stopAdvertising() => _nearby.stopAdvertising();

  @override
  Future<void> startDiscovery({required String activeChannelCode}) async {
    _activeChannelCode = activeChannelCode;
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
    if (!ok) throw StateError('Could not start Nearby discovery.');
  }

  @override
  Future<void> stopDiscovery() => _nearby.stopDiscovery();

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
      final channelCode = _activeChannelCode;
      if (channelCode == null || !payload.isCompatibleWith(channelCode)) {
        return null;
      }
      final now = DateTime.now();
      final existing = _peers[endpointId];
      return NearbyPeerModel(
        endpointId: endpointId,
        userId: payload.userId,
        displayName: payload.displayName,
        deviceName: payload.deviceName,
        activeChannelId: payload.activeChannelId,
        activeChannelCode: payload.activeChannelCode,
        status: existing?.status ?? fallbackStatus,
        discoveredAt: existing?.discoveredAt ?? now,
        lastSeenAt: now,
        isSameChannel: true,
      );
    } catch (_) {
      return null;
    }
  }

  void _emitConnection(NearbyPeerModel peer) {
    _peers[peer.endpointId] = peer;
    _connectionController.add(peer);
  }

  Future<String> _deviceName() async {
    if (!Platform.isAndroid) return 'TrailLink Device';
    final info = await DeviceInfoPlugin().androidInfo;
    return '${info.manufacturer} ${info.model}'.trim();
  }

  @override
  Future<void> dispose() async {
    await _nearby.stopDiscovery();
    await _nearby.stopAdvertising();
    await _nearby.stopAllEndpoints();
    await _discoveredController.close();
    await _lostController.close();
    await _connectionController.close();
    await _packetController.close();
  }
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
