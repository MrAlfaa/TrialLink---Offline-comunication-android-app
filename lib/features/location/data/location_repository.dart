import '../../auth/data/models/user_model.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import 'location_api.dart';
import 'location_local_data_source.dart';
import 'location_packet_service.dart';
import 'location_service.dart';
import 'models/location_freshness.dart';
import 'models/location_update_model.dart';
import 'models/teammate_location_model.dart';

class LocationRepository {
  LocationRepository({
    LocationApi? api,
    LocationLocalDataSource? local,
    LocationService? locationService,
    LocationPacketService? packetService,
    NearbyRepository? nearbyRepository,
  })  : _api = api ?? LocationApi(),
        _local = local ?? LocationLocalDataSource(),
        _locationService = locationService ?? LocationService(),
        _packetService = packetService ?? LocationPacketService(),
        _nearby = nearbyRepository;

  static const maxHopCount = 5;

  final LocationApi _api;
  final LocationLocalDataSource _local;
  final LocationService _locationService;
  final LocationPacketService _packetService;
  final NearbyRepository? _nearby;

  Future<LocationUpdateModel?> latestOwnLocation(String userId) {
    return _local.latestOwnLocation(userId);
  }

  Future<LocationUpdateModel> captureCurrent({
    required UserModel user,
    String? groupId,
    OfflineChannelModel? channel,
  }) {
    return _locationService.captureCurrentLocation(
      user: user,
      groupId: groupId,
      offlineChannelId: channel?.channelId,
      channelCode: channel?.channelCode,
    );
  }

  Future<LocationUpdateModel> shareLocation({
    required UserModel user,
    CurrentUserActor? actor,
    String? groupId,
    OfflineChannelModel? channel,
    required bool online,
  }) async {
    final location = await captureCurrent(
      user: user,
      groupId: groupId,
      channel: channel,
    );
    await _local.upsertLocation(location);

    if (online && groupId != null) {
      try {
        final saved = await _api.shareLocation(
          groupId: groupId,
          location: location,
        );
        await _local.markShared(
          localLocationId: location.localLocationId,
          serverLocationId: saved.serverLocationId,
        );
      } catch (_) {
        // The local row remains needs_sync and will be retried later.
      }
    }

    if (channel != null && _nearby != null) {
      final packet = _packetService.createLocationPacket(
        channel: channel,
        user: user,
        actor: actor,
        location: location,
      );
      await _local.enqueueLocationPacket(
        packetId: packet.packetId,
        localLocationId: location.localLocationId,
        offlineChannelId: channel.channelId,
        channelCode: channel.channelCode,
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

    return location;
  }

  Future<List<TeammateLocationModel>> loadTeammates({
    String? groupId,
    String? offlineChannelId,
  }) {
    return _local.teammateLocations(
      groupId: groupId,
      offlineChannelId: offlineChannelId,
    );
  }

  Future<List<TeammateLocationModel>> refreshBackendTeammates(
    String groupId,
  ) async {
    final teammates = await _api.latestLocations(groupId);
    for (final teammate in teammates) {
      await _local.upsertTeammateLocation(teammate);
    }
    return _local.teammateLocations(groupId: groupId);
  }

  Future<void> syncPendingLocations() async {
    final pending = await _local.pendingSyncLocations();
    final byGroup = <String, List<LocationUpdateModel>>{};
    for (final location in pending) {
      final groupId = location.groupId;
      if (groupId == null) continue;
      byGroup.putIfAbsent(groupId, () => []).add(location);
    }

    for (final entry in byGroup.entries) {
      final synced = await _api.syncLocations(
        groupId: entry.key,
        currentUserId: entry.value.first.userId,
        locations: entry.value,
      );
      for (final saved in synced) {
        await _local.markShared(
          localLocationId: saved.localLocationId,
          serverLocationId: saved.serverLocationId,
        );
      }
    }
  }

  Future<String> handleIncomingPacket({
    required OfflinePacketModel packet,
    required OfflineChannelModel activeChannel,
    required UserModel currentUser,
  }) async {
    if (packet.packetType != 'location') return 'Unsupported location packet.';
    if (packet.channelCode != activeChannel.channelCode) {
      await _local.markProcessed(
        packetId: packet.packetId,
        channelId: packet.channelId,
        channelCode: packet.channelCode,
        senderId: packet.senderId,
        action: 'ignored_wrong_channel',
      );
      return 'Location packet belongs to another channel.';
    }
    if (packet.ttl <= 0 || packet.hopCount > maxHopCount) {
      await _local.markProcessed(
        packetId: packet.packetId,
        channelId: packet.channelId,
        channelCode: packet.channelCode,
        senderId: packet.senderId,
        action: 'ignored_expired',
      );
      return 'Expired location packet ignored.';
    }
    if (await _local.processedPacketExists(packet.packetId)) {
      return 'Duplicate location packet ignored.';
    }

    final capturedAt =
        DateTime.tryParse(packet.payload['capturedAt']?.toString() ?? '') ??
            packet.createdAt;
    if (packet.senderLocalId != currentUser.id &&
        packet.senderId != currentUser.id) {
      await _local.upsertTeammateLocation(
        TeammateLocationModel(
          userId: packet.senderId,
          userName: packet.senderName,
          offlineChannelId: activeChannel.channelId,
          channelCode: activeChannel.channelCode,
          latitude: double.parse(packet.payload['latitude'].toString()),
          longitude: double.parse(packet.payload['longitude'].toString()),
          accuracy: packet.payload['accuracy'] == null
              ? null
              : double.tryParse(packet.payload['accuracy'].toString()),
          capturedAt: capturedAt,
          receivedAt: DateTime.now(),
          source: 'peer',
          freshness: calculateLocationFreshness(capturedAt),
        ),
      );
    }
    await _local.markProcessed(
      packetId: packet.packetId,
      channelId: packet.channelId,
      channelCode: packet.channelCode,
      senderId: packet.senderId,
      action: 'accepted',
    );
    return 'Location update received.';
  }
}
