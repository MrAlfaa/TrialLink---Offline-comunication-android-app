import 'package:uuid/uuid.dart';

import '../../../core/connectivity/app_connection_mode.dart';
import '../../auth/data/models/user_model.dart';
import '../../connectivity_intelligence/data/connectivity_metrics_recorder.dart';
import '../../location/data/location_repository.dart';
import '../../location/data/models/location_update_model.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'emergency_api.dart';
import 'emergency_local_data_source.dart';
import 'emergency_packet_service.dart';
import 'models/emergency_ack_model.dart';
import 'models/emergency_event_model.dart';

class EmergencyRepository {
  EmergencyRepository({
    EmergencyApi? api,
    EmergencyLocalDataSource? local,
    EmergencyPacketService? packetService,
    LocationRepository? locationRepository,
    NearbyRepository? nearbyRepository,
    ConnectivityMetricsRecorder? metricsRecorder,
    Uuid? uuid,
  })  : _api = api ?? EmergencyApi(),
        _local = local ?? EmergencyLocalDataSource(),
        _packetService = packetService ?? EmergencyPacketService(),
        _locationRepository = locationRepository ?? LocationRepository(),
        _nearby = nearbyRepository,
        _metricsRecorder = metricsRecorder ?? ConnectivityMetricsRecorder(),
        _uuid = uuid ?? const Uuid();

  static const maxHopCount = 5;

  final EmergencyApi _api;
  final EmergencyLocalDataSource _local;
  final EmergencyPacketService _packetService;
  final LocationRepository _locationRepository;
  final NearbyRepository? _nearby;
  final ConnectivityMetricsRecorder _metricsRecorder;
  final Uuid _uuid;

  Future<List<EmergencyEventModel>> history({
    String? groupId,
    String? offlineChannelId,
  }) {
    return _local.events(groupId: groupId, offlineChannelId: offlineChannelId);
  }

  Future<EmergencyEventModel?> latestEvent() => _local.latestEvent();

  Future<void> saveRemoteEvent(EmergencyEventModel event) {
    return _local.upsertEvent(event);
  }

  Future<void> syncPendingEmergencies() async {
    final pending = await _local.pendingSyncEvents();
    for (final event in pending) {
      final groupId = event.groupId;
      if (groupId == null || groupId.isEmpty) continue;
      try {
        final saved = await _api.createEmergency(
          groupId: groupId,
          event: event,
        );
        await _local.markEvent(
          localEventId: event.localEventId,
          serverEventId: saved.serverEventId,
          status: 'sent',
          syncState: 'synced',
        );
      } catch (error) {
        await _local.markSyncFailed(
          localEventId: event.localEventId,
          error: error.toString(),
        );
      }
    }
  }

  Future<EmergencyEventModel> triggerSos({
    required UserModel user,
    String? groupId,
    OfflineChannelModel? channel,
    required AppConnectionMode mode,
    String message = 'Need help',
    bool attachLocation = true,
    bool useLastKnownLocation = true,
  }) async {
    if (groupId == null && channel == null) {
      throw StateError('Select a group or offline channel before sending SOS.');
    }

    var location = attachLocation
        ? await _captureSosLocation(
            user: user,
            groupId: groupId,
            channel: channel,
            useLastKnownLocation: useLastKnownLocation,
          )
        : null;
    final deliveryMode = groupId != null && channel != null
        ? 'hybrid'
        : groupId != null
            ? 'online'
            : 'offline';
    final event = EmergencyEventModel(
      localEventId: _uuid.v4(),
      groupId: groupId,
      offlineChannelId: channel?.channelId,
      channelCode: channel?.channelCode,
      alertType: 'sos',
      message: message.trim().isEmpty ? 'Need help' : message.trim(),
      priority: 'emergency',
      latitude: location?.latitude,
      longitude: location?.longitude,
      accuracy: location?.accuracy,
      locationCapturedAt: location?.capturedAt,
      status: 'pending',
      deliveryMode: deliveryMode,
      ackStatus: 'waiting',
      retryCount: 0,
      createdAt: DateTime.now(),
      syncState: groupId == null ? 'local_only' : 'needs_sync',
    );
    await _local.upsertEvent(event);

    if (mode == AppConnectionMode.online && groupId != null) {
      try {
        final saved =
            await _api.createEmergency(groupId: groupId, event: event);
        await _local.markEvent(
          localEventId: event.localEventId,
          serverEventId: saved.serverEventId,
          status: 'sent',
          syncState: 'synced',
        );
      } catch (_) {
        // The event remains local and visible as pending/needs_sync.
      }
    }

    if (channel != null && _nearby != null) {
      final packet = _packetService.createSosPacket(
        channel: channel,
        user: user,
        event: event,
      );
      await _local.enqueuePacket(
        packetId: packet.packetId,
        event: event,
        payloadJson: packet.toJsonString(),
      );
      final peers = await _nearby.connectedPeers(channel.channelCode);
      for (final peer in peers) {
        await _nearby.sendPacket(
          endpointId: peer.endpointId,
          packetJson: packet.toJsonString(),
        );
      }
    }

    return event;
  }

  Future<LocationUpdateModel?> _captureSosLocation({
    required UserModel user,
    String? groupId,
    OfflineChannelModel? channel,
    required bool useLastKnownLocation,
  }) async {
    try {
      return await _locationRepository.captureCurrent(
        user: user,
        groupId: groupId,
        channel: channel,
      );
    } catch (_) {
      if (!useLastKnownLocation) return null;
      return _locationRepository.latestOwnLocation(user.id);
    }
  }

  Future<EmergencyPacketHandleResult> handleIncomingSosPacket({
    required OfflinePacketModel packet,
    required OfflineChannelModel activeChannel,
    required UserModel currentUser,
    bool sendAck = false,
  }) async {
    if (packet.channelCode != activeChannel.channelCode) {
      await _markProcessed(packet, 'ignored_wrong_channel');
      return const EmergencyPacketHandleResult(
        message: 'Emergency packet belongs to another channel.',
      );
    }
    if (packet.ttl <= 0 || packet.hopCount > maxHopCount) {
      await _markProcessed(packet, 'ignored_expired');
      return const EmergencyPacketHandleResult(
        message: 'Expired emergency packet ignored.',
      );
    }
    if (await _local.processedPacketExists(packet.packetId)) {
      return const EmergencyPacketHandleResult(
        message: 'Duplicate emergency packet ignored.',
      );
    }

    if (packet.packetType == 'sos_ack') {
      final localEventId = packet.payload['ackForEventId']?.toString();
      if (localEventId != null && localEventId.isNotEmpty) {
        await _local.saveAck(
          EmergencyAckModel(
            ackId: packet.packetId,
            localEventId: localEventId,
            ackFromUserId: packet.senderId,
            ackFromName: packet.senderName,
            ackMode: 'offline',
            receivedAt: DateTime.now(),
          ),
        );
        await _local.markEvent(
          localEventId: localEventId,
          status: 'acknowledged',
          ackStatus: 'acknowledged',
        );
        final List<NearbyPeerModel> peers = _nearby == null
            ? <NearbyPeerModel>[]
            : await _nearby.connectedPeers(activeChannel.channelCode);
        final matchingPeer =
            peers.where((peer) => peer.userId == packet.senderId);
        await _metricsRecorder.recordAck(
          endpointId: matchingPeer.isEmpty
              ? packet.senderId
              : matchingPeer.first.endpointId,
          userId: packet.senderId,
          displayName: packet.senderName,
          channelId: packet.channelId,
          channelCode: packet.channelCode,
          ackRttMs:
              DateTime.now().difference(packet.createdAt).inMilliseconds.abs(),
        );
      }
      await _markProcessed(packet, 'accepted');
      return const EmergencyPacketHandleResult(
        message: 'Emergency alert acknowledged.',
      );
    }

    if (packet.packetType != 'sos') {
      return const EmergencyPacketHandleResult(
        message: 'Unsupported emergency packet.',
      );
    }

    final location = packet.payload['location'] as Map<String, dynamic>?;
    final localEventId =
        packet.payload['localEventId']?.toString() ?? packet.packetId;
    final event = EmergencyEventModel(
      localEventId: localEventId,
      offlineChannelId: activeChannel.channelId,
      channelCode: activeChannel.channelCode,
      alertType: packet.payload['alertType']?.toString() ?? 'sos',
      message: packet.payload['message']?.toString(),
      priority: 'emergency',
      latitude: _nullableDouble(location?['latitude']),
      longitude: _nullableDouble(location?['longitude']),
      accuracy: _nullableDouble(location?['accuracy']),
      locationCapturedAt:
          DateTime.tryParse(location?['capturedAt']?.toString() ?? ''),
      status: 'broadcasting',
      deliveryMode: 'offline',
      ackStatus: 'waiting',
      retryCount: 0,
      createdAt: packet.createdAt,
      syncState: 'local_only',
    );
    await _local.upsertEvent(event);
    await _markProcessed(packet, 'accepted');

    if (sendAck && packet.senderId != currentUser.id) {
      await sendOfflineSosAck(
        receivedPacket: packet,
        activeChannel: activeChannel,
        currentUser: currentUser,
      );
    }

    return EmergencyPacketHandleResult(
      message: 'Emergency alert received.',
      event: event,
      receivedPacket: packet,
      senderName: packet.senderName,
    );
  }

  Future<void> sendOfflineSosAck({
    required OfflinePacketModel receivedPacket,
    required OfflineChannelModel activeChannel,
    required UserModel currentUser,
  }) async {
    if (_nearby == null || receivedPacket.senderId == currentUser.id) return;
    final ack = _packetService.createSosAckPacket(
      receivedPacket: receivedPacket,
      user: currentUser,
    );
    final peers = await _nearby.connectedPeers(activeChannel.channelCode);
    for (final peer in peers) {
      await _nearby.sendPacket(
        endpointId: peer.endpointId,
        packetJson: ack.toJsonString(),
      );
      await _metricsRecorder.recordPacketResult(
        endpointId: peer.endpointId,
        userId: peer.userId,
        displayName: peer.displayName,
        channelId: activeChannel.channelId,
        channelCode: activeChannel.channelCode,
        success: true,
      );
    }
  }

  Future<void> acknowledgeOnline({
    required String groupId,
    required String eventId,
  }) async {
    final event = await _api.acknowledge(groupId: groupId, eventId: eventId);
    await _local.upsertEvent(event);
  }

  Future<void> _markProcessed(OfflinePacketModel packet, String action) {
    return _local.markProcessed(
      packetId: packet.packetId,
      channelId: packet.channelId,
      channelCode: packet.channelCode,
      senderId: packet.senderId,
      action: action,
    );
  }

  double? _nullableDouble(Object? value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

class EmergencyPacketHandleResult {
  const EmergencyPacketHandleResult({
    required this.message,
    this.event,
    this.receivedPacket,
    this.senderName,
  });

  final String message;
  final EmergencyEventModel? event;
  final OfflinePacketModel? receivedPacket;
  final String? senderName;
}
