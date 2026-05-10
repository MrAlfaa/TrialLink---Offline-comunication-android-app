import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../connectivity_intelligence/data/connectivity_metrics_recorder.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_channel/data/offline_channel_repository.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import '../data/models/nearby_connection_status.dart';
import '../data/models/nearby_peer_model.dart';
import '../data/nearby_connections_transport.dart';
import '../data/nearby_packet_transport.dart';
import '../data/nearby_repository.dart';

enum NearbyFailureKind { staleEndpoint, permission, transport, unknown }

NearbyFailureKind nearbyFailureKind(Object error) {
  final text = error.toString();
  if (text.contains('STATUS_ENDPOINT_UNKNOWN') || text.contains('8011')) {
    return NearbyFailureKind.staleEndpoint;
  }
  if (text.toLowerCase().contains('permission')) {
    return NearbyFailureKind.permission;
  }
  if (text.toLowerCase().contains('bluetooth') ||
      text.toLowerCase().contains('wifi') ||
      text.toLowerCase().contains('nearby')) {
    return NearbyFailureKind.transport;
  }
  return NearbyFailureKind.unknown;
}

String nearbyUserMessageFromError(Object error) {
  switch (nearbyFailureKind(error)) {
    case NearbyFailureKind.staleEndpoint:
      return 'That peer is no longer reachable. Start discovery again and ask the other phone to keep Nearby open.';
    case NearbyFailureKind.permission:
      return 'Nearby permissions are required. Turn on Bluetooth, Wi-Fi, and location access, then try again.';
    case NearbyFailureKind.transport:
      return 'Nearby connection failed. Check Bluetooth, Wi-Fi, and Nearby discovery, then try again.';
    case NearbyFailureKind.unknown:
      return 'Nearby action failed. Try discovery again and keep both phones close with Nearby open.';
  }
}

final nearbyTransportProvider = Provider<NearbyPacketTransport>((ref) {
  final transport = NearbyConnectionsTransport();
  ref.onDispose(transport.dispose);
  return transport;
});

final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  final repository =
      NearbyRepository(transport: ref.watch(nearbyTransportProvider));
  ref.onDispose(() {
    unawaited(repository.dispose());
  });
  return repository;
});

class NearbyState {
  const NearbyState({
    this.peers = const [],
    this.isAdvertising = false,
    this.isDiscovering = false,
    this.hasPermission = false,
    this.isBusy = false,
    this.lastScanAt,
    this.errorMessage,
    this.successMessage,
  });

  final List<NearbyPeerModel> peers;
  final bool isAdvertising;
  final bool isDiscovering;
  final bool hasPermission;
  final bool isBusy;
  final DateTime? lastScanAt;
  final String? errorMessage;
  final String? successMessage;

  int get connectedCount => peers
      .where((peer) => peer.status == PeerConnectionStatus.connected)
      .length;

  NearbyState copyWith({
    List<NearbyPeerModel>? peers,
    bool? isAdvertising,
    bool? isDiscovering,
    bool? hasPermission,
    bool? isBusy,
    DateTime? lastScanAt,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return NearbyState(
      peers: peers ?? this.peers,
      isAdvertising: isAdvertising ?? this.isAdvertising,
      isDiscovering: isDiscovering ?? this.isDiscovering,
      hasPermission: hasPermission ?? this.hasPermission,
      isBusy: isBusy ?? this.isBusy,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearMessages ? null : successMessage ?? this.successMessage,
    );
  }
}

class NearbySessionArgs {
  const NearbySessionArgs({
    required this.channel,
    required this.user,
  });

  final OfflineChannelModel channel;
  final CurrentUserActor user;

  @override
  bool operator ==(Object other) {
    return other is NearbySessionArgs &&
        other.channel.channelId == channel.channelId &&
        other.user.localUserId == user.localUserId;
  }

  @override
  int get hashCode => Object.hash(channel.channelId, user.localUserId);
}

class NearbyController extends StateNotifier<NearbyState> {
  NearbyController({
    required this.args,
    required NearbyRepository repository,
    OfflineChannelRepository? offlineChannelRepository,
    ConnectivityMetricsRecorder? metricsRecorder,
  })  : _repository = repository,
        _offlineChannelRepository =
            offlineChannelRepository ?? OfflineChannelRepository(),
        _metricsRecorder = metricsRecorder ?? ConnectivityMetricsRecorder(),
        super(const NearbyState()) {
    _init();
  }

  final NearbySessionArgs args;
  final NearbyRepository _repository;
  final OfflineChannelRepository _offlineChannelRepository;
  final ConnectivityMetricsRecorder _metricsRecorder;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Uuid _uuid = const Uuid();
  Timer? _heartbeatTimer;

  Future<void> _init() async {
    _subscriptions
      ..add(_repository.peerDiscoveredStream.listen(_onPeer))
      ..add(_repository.peerConnectionChangedStream.listen(_onPeer))
      ..add(_repository.peerLostStream.listen(_onPeerLost));
    await refreshPeers();
  }

  Future<void> refreshPeers() async {
    final peers = await _repository.getPeers(args.channel.channelCode);
    if (!mounted) return;
    state = state.copyWith(peers: peers, lastScanAt: DateTime.now());
  }

  Future<bool> requestPermissions() async {
    state = state.copyWith(isBusy: true, clearMessages: true);
    final result = await _repository.requestPermissions();
    if (!mounted) return result.granted;
    state = state.copyWith(
      hasPermission: result.granted,
      isBusy: false,
      errorMessage: result.granted ? null : result.message,
      clearMessages: result.granted,
    );
    return result.granted;
  }

  Future<void> startAdvertising() async {
    if (!await requestPermissions()) return;
    await _run(
      () => _repository.startAdvertising(
        userId: args.user.localUserId,
        displayName: args.user.displayName,
        activeChannelId: args.channel.channelId,
        activeChannelCode: args.channel.channelCode,
      ),
      successMessage: 'Advertising started.',
      after: () {
        state = state.copyWith(isAdvertising: true);
        _startHeartbeat();
      },
    );
  }

  Future<void> stopAdvertising() async {
    await _run(
      _repository.stopAdvertising,
      successMessage: 'Advertising stopped.',
      after: () {
        state = state.copyWith(isAdvertising: false);
        _stopHeartbeatIfIdle();
      },
    );
  }

  Future<void> startDiscovery() async {
    if (!await requestPermissions()) return;
    await _run(
      () => _repository.startDiscovery(args.channel.channelCode),
      successMessage: 'Discovery started.',
      after: () {
        state = state.copyWith(
          isDiscovering: true,
          lastScanAt: DateTime.now(),
        );
        _startHeartbeat();
      },
    );
  }

  Future<void> stopDiscovery() async {
    await _run(
      _repository.stopDiscovery,
      successMessage: 'Discovery stopped.',
      after: () {
        state = state.copyWith(isDiscovering: false);
        _stopHeartbeatIfIdle();
      },
    );
  }

  Future<void> connectToPeer(String endpointId) async {
    _setPeerStatus(endpointId, PeerConnectionStatus.connecting);
    await _run(
      () => _repository.connectToPeer(endpointId),
      successMessage: 'Connection request sent.',
      onError: (error) async {
        if (nearbyFailureKind(error) == NearbyFailureKind.staleEndpoint) {
          await _repository.markLost(endpointId);
          await _offlineChannelRepository.markPeerDisconnected(
            channelId: args.channel.channelId,
            endpointId: endpointId,
          );
          _setPeerStatus(endpointId, PeerConnectionStatus.lost);
          return;
        }
        _setPeerStatus(endpointId, PeerConnectionStatus.failed);
      },
    );
  }

  Future<void> disconnectFromPeer(String endpointId) async {
    await _run(
      () => _repository.disconnectFromPeer(endpointId),
      successMessage: 'Peer disconnected.',
      after: () =>
          _setPeerStatus(endpointId, PeerConnectionStatus.disconnected),
    );
  }

  Future<void> _onPeer(NearbyPeerModel peer) async {
    if (peer.activeChannelCode != args.channel.channelCode) return;
    await _repository.savePeer(peer);
    await _offlineChannelRepository.upsertPeerPresence(
      channel: args.channel,
      peer: peer,
    );
    await _metricsRecorder.recordPeerEvent(peer, source: peer.status.name);
    final peers = [
      peer,
      ...state.peers.where((item) => item.endpointId != peer.endpointId),
    ]..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    if (!mounted) return;
    state = state.copyWith(peers: peers, lastScanAt: DateTime.now());
  }

  void _startHeartbeat() {
    _heartbeatTimer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _sendHeartbeat(),
    );
  }

  void _stopHeartbeatIfIdle() {
    if (state.isAdvertising || state.isDiscovering) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final connected = state.peers
        .where((peer) => peer.status == PeerConnectionStatus.connected)
        .toList();
    if (connected.isEmpty) return;
    final packet = OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'heartbeat',
      channelId: args.channel.channelId,
      channelCode: args.channel.channelCode,
      senderId: args.user.localUserId,
      senderName: args.user.displayName,
      targetType: 'channel',
      targetId: args.channel.channelId,
      payload: {'status': 'available'},
      priority: 'low',
      ttl: 2,
      hopCount: 0,
      requiresAck: false,
      createdAt: DateTime.now(),
    );
    for (final peer in connected) {
      try {
        await _repository.sendPacket(
          endpointId: peer.endpointId,
          packetJson: packet.toJsonString(),
        );
      } catch (_) {
        await _onPeerLost(peer.endpointId);
      }
    }
  }

  Future<void> _onPeerLost(String endpointId) async {
    await _repository.markLost(endpointId);
    await _offlineChannelRepository.markPeerDisconnected(
      channelId: args.channel.channelId,
      endpointId: endpointId,
    );
    _setPeerStatus(endpointId, PeerConnectionStatus.lost);
    final lostPeer = state.peers.where((peer) => peer.endpointId == endpointId);
    if (lostPeer.isNotEmpty) {
      await _metricsRecorder.recordPeerEvent(
        lostPeer.first.copyWith(
          status: PeerConnectionStatus.lost,
          lastSeenAt: DateTime.now(),
        ),
        source: 'connection_event',
      );
    }
  }

  void _setPeerStatus(String endpointId, PeerConnectionStatus status) {
    final peers = state.peers.map((peer) {
      if (peer.endpointId != endpointId) return peer;
      return peer.copyWith(status: status, lastSeenAt: DateTime.now());
    }).toList();
    state = state.copyWith(peers: peers);
    if (status == PeerConnectionStatus.disconnected ||
        status == PeerConnectionStatus.lost ||
        status == PeerConnectionStatus.failed) {
      unawaited(
        _offlineChannelRepository.markPeerDisconnected(
          channelId: args.channel.channelId,
          endpointId: endpointId,
        ),
      );
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String successMessage,
    VoidCallback? after,
    FutureOr<void> Function(Object error)? onError,
  }) async {
    state = state.copyWith(isBusy: true, clearMessages: true);
    try {
      await action();
      if (!mounted) return;
      after?.call();
      state = state.copyWith(
        isBusy: false,
        successMessage: successMessage,
      );
    } catch (error) {
      if (!mounted) return;
      await onError?.call(error);
      if (!mounted) return;
      state = state.copyWith(
        isBusy: false,
        errorMessage: nearbyUserMessageFromError(error),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

typedef VoidCallback = void Function();

final nearbyControllerProvider = StateNotifierProvider.autoDispose
    .family<NearbyController, NearbyState, NearbySessionArgs>((ref, args) {
  return NearbyController(
    args: args,
    repository: ref.watch(nearbyRepositoryProvider),
    metricsRecorder: ConnectivityMetricsRecorder(),
  );
});
