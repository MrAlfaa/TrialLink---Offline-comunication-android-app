import 'dart:async';
import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/identity/local_identity_model.dart';
import '../../auth/data/models/user_model.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../nearby/data/nearby_repository.dart';
import 'models/offline_channel_member_model.dart';
import 'models/offline_channel_model.dart';
import 'models/offline_packet_model.dart';
import 'offline_channel_local_data_source.dart';
import 'offline_packet_filter.dart';
import 'offline_presence_service.dart';
import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import '../../offline_chat/data/models/offline_packet_model.dart'
    as chat_packet;

class OfflineChannelRepository {
  OfflineChannelRepository({
    OfflineChannelLocalDataSource? localDataSource,
    NearbyRepository? nearbyRepository,
  })  : _local = localDataSource ?? OfflineChannelLocalDataSource(),
        _nearby = nearbyRepository,
        _uuid = const Uuid();

  final OfflineChannelLocalDataSource _local;
  final NearbyRepository? _nearby;
  final Uuid _uuid;

  Future<List<OfflineChannelModel>> getChannels() => _local.getChannels();

  Future<OfflineChannelModel?> getChannel(String channelId) {
    return _local.getChannel(channelId);
  }

  Future<OfflineChannelModel?> getChannelByCode(String channelCode) {
    return _local.getChannelByCode(channelCode);
  }

  Future<OfflineChannelModel?> getActiveChannel() {
    return _local.getActiveChannel();
  }

  Future<List<OfflineChannelMemberModel>> getMembers(String channelId) {
    return _local.getMembers(channelId);
  }

  Future<void> upsertPeerPresence({
    required OfflineChannelModel channel,
    required NearbyPeerModel peer,
  }) async {
    if (peer.activeChannelCode != channel.channelCode) return;
    await _local.upsertMember(
      OfflinePresenceService.fromPeer(
        channelId: channel.channelId,
        peer: peer,
      ),
    );
  }

  Future<void> markPeerDisconnected({
    required String channelId,
    required String endpointId,
  }) async {
    final members = await _local.getMembers(channelId);
    final matches = members.where((member) => member.endpointId == endpointId);
    for (final member in matches) {
      await _local.updateMemberPresence(
        channelId: channelId,
        userId: member.userId,
        presenceStatus: 'disconnected',
        connectionStatus: PeerConnectionStatus.disconnected.name,
        lastSeenAt: DateTime.now(),
        endpointId: endpointId,
      );
    }
  }

  Future<void> sweepPresence(String channelId) {
    return _local.sweepPresence(
      channelId: channelId,
      now: DateTime.now(),
    );
  }

  Future<OfflineChannelModel> createChannel({
    required UserModel user,
    required String channelName,
    required String description,
    String? customCode,
  }) async {
    return createChannelForActor(
      actor: OfflineChannelActor.fromUser(user),
      channelName: channelName,
      description: description,
      customCode: customCode,
    );
  }

  Future<OfflineChannelModel> createChannelForIdentity({
    required LocalIdentityModel identity,
    required String channelName,
    required String description,
    String? customCode,
  }) {
    return createChannelForActor(
      actor: OfflineChannelActor.fromIdentity(identity),
      channelName: channelName,
      description: description,
      customCode: customCode,
    );
  }

  Future<OfflineChannelModel> createChannelForActor({
    required OfflineChannelActor actor,
    required String channelName,
    required String description,
    String? customCode,
  }) async {
    _validateName(channelName);
    _validateDescription(description);
    final channelCode = customCode == null || customCode.trim().isEmpty
        ? await _generateChannelCode()
        : _normalizeCode(customCode);
    await _ensureCodeAvailable(channelCode);

    final now = DateTime.now();
    final hasActive = await _local.getActiveChannel() != null;
    final channel = OfflineChannelModel(
      channelId: _uuid.v4(),
      channelCode: channelCode,
      channelName: channelName.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      createdByUserId: actor.userId,
      createdByName: actor.displayName,
      isActive: !hasActive,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );

    try {
      await _local.insertChannel(channel);
      await _local.upsertMember(_memberForActor(channel, actor, 'owner'));
      if (!hasActive) {
        await _local.setActiveChannel(channel.channelId);
      }
      return (await _local.getChannel(channel.channelId)) ?? channel;
    } on DatabaseException {
      throw StateError('This channel code already exists on this device.');
    }
  }

  Future<OfflineChannelModel> joinChannel({
    required UserModel user,
    required String channelCode,
  }) async {
    return joinChannelForActor(
      actor: OfflineChannelActor.fromUser(user),
      channelCode: channelCode,
    );
  }

  Future<OfflineChannelModel> joinChannelForIdentity({
    required LocalIdentityModel identity,
    required String channelCode,
  }) {
    return joinChannelForActor(
      actor: OfflineChannelActor.fromIdentity(identity),
      channelCode: channelCode,
    );
  }

  Future<OfflineChannelModel> joinChannelForActor({
    required OfflineChannelActor actor,
    required String channelCode,
  }) async {
    final normalized = _normalizeCode(channelCode);
    final existing = await _local.getChannelByCode(normalized);
    if (existing != null) {
      await _local.upsertMember(_memberForActor(existing, actor, 'member'));
      await _local.setActiveChannel(existing.channelId);
      return (await _local.getChannel(existing.channelId)) ?? existing;
    }

    final now = DateTime.now();
    final channel = OfflineChannelModel(
      channelId: _uuid.v4(),
      channelCode: normalized,
      channelName: 'Offline Channel $normalized',
      description:
          'Channel membership will be verified with nearby devices in the peer discovery phase.',
      createdByUserId: actor.userId,
      createdByName: actor.displayName,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );

    await _local.insertChannel(channel);
    await _local.upsertMember(_memberForActor(channel, actor, 'member'));
    await _local.setActiveChannel(channel.channelId);
    return (await _local.getChannel(channel.channelId)) ?? channel;
  }

  Future<void> setActiveChannel(String channelId) {
    return _local.setActiveChannel(channelId);
  }

  Future<void> deleteChannel(String channelId) {
    return _local.deleteChannel(channelId);
  }

  Future<void> setInactiveChannel(String channelId) {
    return _local.markChannelStatus(
      channelId: channelId,
      channelStatus: 'inactive',
    );
  }

  Future<void> endChannel({
    required OfflineChannelModel channel,
    required CurrentUserActor actor,
    String reason = 'Channel ended by owner.',
  }) async {
    _assertOwner(channel: channel, actor: actor);
    final packet = _statusPacket(
      channel: channel,
      actor: actor,
      channelStatus: 'ended',
      reason: reason,
    );
    await _sendStatusPacket(channel, packet);
    await _local.markChannelStatus(
      channelId: channel.channelId,
      channelStatus: 'ended',
      endedByUserId: actor.localUserId,
      endedReason: reason,
      endedAt: DateTime.now(),
    );
  }

  Future<String> handleChannelStatusPacket({
    required chat_packet.OfflinePacketModel packet,
    required CurrentUserActor currentUser,
  }) async {
    if (packet.packetType != 'channel_status_update') {
      return 'Unsupported channel lifecycle packet ignored.';
    }
    final channel = await _local.getChannel(packet.channelId) ??
        await _local.getChannelByCode(packet.channelCode);
    if (channel == null) return 'Unknown channel lifecycle update ignored.';
    if (channel.channelCode != packet.channelCode) {
      return 'Channel lifecycle update ignored.';
    }

    final currentMembership = await _local.getMember(
      channelId: channel.channelId,
      userId: currentUser.localUserId,
    );
    final senderIsKnownOwner = packet.senderId == channel.createdByUserId ||
        packet.senderLocalId == channel.createdByUserId ||
        await _isMemberOwner(channel.channelId, packet.senderLocalId) ||
        await _isMemberOwner(channel.channelId, packet.senderId);
    final localUserIsOwner = currentMembership?.memberRole == 'owner' ||
        channel.createdByUserId == currentUser.localUserId ||
        channel.createdByUserId == currentUser.backendUserId;
    if (localUserIsOwner && !senderIsKnownOwner) {
      return 'Channel lifecycle update from non-owner ignored.';
    }

    final status = packet.payload['channelStatus']?.toString() ?? '';
    if (!['active', 'inactive', 'ended'].contains(status)) {
      return 'Invalid channel lifecycle update ignored.';
    }
    await _local.markChannelStatus(
      channelId: channel.channelId,
      channelStatus: status,
      endedByUserId: packet.payload['changedByUserId']?.toString() ??
          packet.senderLocalId ??
          packet.senderId,
      endedReason: packet.payload['reason']?.toString(),
      endedAt: DateTime.tryParse(
        packet.payload['changedAt']?.toString() ?? '',
      ),
    );
    if (status == 'ended') {
      return 'This channel was ended by the owner. Chat history is read-only.';
    }
    return 'Channel status updated.';
  }

  Future<void> leaveChannel({
    required String channelId,
    required String localUserId,
  }) async {
    await _local.markMemberLeft(channelId: channelId, userId: localUserId);
    await _local.clearActiveChannel(channelId);
  }

  void _assertOwner({
    required OfflineChannelModel channel,
    required CurrentUserActor actor,
  }) {
    final ids = {
      actor.localUserId,
      if (actor.backendUserId != null) actor.backendUserId!
    };
    if (!ids.contains(channel.createdByUserId)) {
      throw StateError('Only the channel owner can end this channel.');
    }
  }

  chat_packet.OfflinePacketModel _statusPacket({
    required OfflineChannelModel channel,
    required CurrentUserActor actor,
    required String channelStatus,
    required String reason,
  }) {
    final changedAt = DateTime.now();
    return chat_packet.OfflinePacketModel(
      packetId: _uuid.v4(),
      packetType: 'channel_status_update',
      channelId: channel.channelId,
      channelCode: channel.channelCode,
      senderId: actor.backendUserId ?? actor.localUserId,
      senderLocalId: actor.localUserId,
      senderBackendId: actor.backendUserId,
      senderName: actor.displayName,
      identityType: actor.identityType,
      sourcePath: 'offline',
      targetType: 'channel',
      targetId: channel.channelId,
      payload: {
        'channelId': channel.channelId,
        'channelCode': channel.channelCode,
        'channelStatus': channelStatus,
        'changedByUserId': actor.localUserId,
        'changedByName': actor.displayName,
        'changedAt': changedAt.toIso8601String(),
        'reason': reason,
      },
      priority: 'high',
      ttl: 3,
      hopCount: 0,
      requiresAck: false,
      createdAt: changedAt,
    );
  }

  Future<void> _sendStatusPacket(
    OfflineChannelModel channel,
    chat_packet.OfflinePacketModel packet,
  ) async {
    final nearby = _nearby;
    if (nearby == null) return;
    final peers = (await nearby.getPeers(channel.channelCode))
        .where((peer) => peer.status == PeerConnectionStatus.connected);
    for (final peer in peers) {
      try {
        await nearby.sendPacket(
          endpointId: peer.endpointId,
          packetJson: packet.toJsonString(),
        );
      } catch (_) {
        // Offline lifecycle propagation is best-effort; disconnected devices
        // update when they rediscover or receive a relayed packet later.
      }
    }
  }

  Future<bool> _isMemberOwner(String channelId, String? userId) async {
    if (userId == null || userId.isEmpty) return false;
    final member = await _local.getMember(channelId: channelId, userId: userId);
    return member?.memberRole == 'owner';
  }

  Future<List<String>> runPacketFilterTest(
      OfflineChannelModel channel, UserModel user) async {
    final duplicatePacketId = _uuid.v4();
    final samples = [
      OfflinePacketModel(
        packetId: _uuid.v4(),
        channelId: channel.channelId,
        channelCode: channel.channelCode,
        packetType: 'text',
        senderId: user.id,
        payloadJson: '{"text":"same channel"}',
        createdAt: DateTime.now(),
      ),
      OfflinePacketModel(
        packetId: _uuid.v4(),
        channelId: 'different-channel',
        channelCode: 'OTHER-99',
        packetType: 'text',
        senderId: user.id,
        payloadJson: '{"text":"different channel"}',
        createdAt: DateTime.now(),
      ),
      OfflinePacketModel(
        packetId: _uuid.v4(),
        channelId: channel.channelId,
        channelCode: channel.channelCode,
        packetType: 'text',
        senderId: user.id,
        payloadJson: '{"text":"expired"}',
        ttl: 0,
        createdAt: DateTime.now(),
      ),
      OfflinePacketModel(
        packetId: duplicatePacketId,
        channelId: channel.channelId,
        channelCode: channel.channelCode,
        packetType: 'text',
        senderId: user.id,
        payloadJson: '{"text":"duplicate"}',
        createdAt: DateTime.now(),
      ),
    ];

    await _local.insertPacket(samples.last);

    final results = <String>[];
    for (final sample in samples) {
      final duplicate = await _local.packetExists(sample.packetId);
      final accepted = shouldProcessPacket(
        packet: sample,
        activeChannelId: channel.channelId,
        activeChannelCode: channel.channelCode,
        isDuplicate: sample.packetId == duplicatePacketId && duplicate,
      );
      if (accepted) {
        await _local.insertPacket(sample);
      }
      results
          .add('${sample.payloadJson}: ${accepted ? "processed" : "ignored"}');
    }

    return results;
  }

  OfflineChannelMemberModel _memberForActor(
    OfflineChannelModel channel,
    OfflineChannelActor actor,
    String role,
  ) {
    return OfflineChannelMemberModel(
      channelId: channel.channelId,
      userId: actor.userId,
      displayName: actor.displayName,
      memberRole: role,
      source: 'local',
      status: 'active',
      membershipStatus: 'active',
      presenceStatus: 'connected',
      connectionStatus: 'connected',
      identityType: actor.identityType,
      joinedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
    );
  }

  Future<String> _generateChannelCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    for (var attempt = 0; attempt < 20; attempt++) {
      final suffix = List.generate(
        4,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
      final code = 'TL-OFF-$suffix';
      if (await _local.getChannelByCode(code) == null) return code;
    }
    throw StateError('Could not generate a unique channel code.');
  }

  String _normalizeCode(String value) {
    final code = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9-]{4,20}$').hasMatch(code)) {
      throw StateError(
          'Invalid channel code. Use letters, numbers, and hyphens only.');
    }
    return code;
  }

  Future<void> _ensureCodeAvailable(String code) async {
    if (await _local.getChannelByCode(code) != null) {
      throw StateError('This channel code already exists on this device.');
    }
  }

  void _validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.length < 3 || trimmed.length > 50) {
      throw StateError('Channel name must be 3-50 characters.');
    }
  }

  void _validateDescription(String value) {
    if (value.trim().length > 200) {
      throw StateError('Description must be 200 characters or less.');
    }
  }
}

class OfflineChannelActor {
  const OfflineChannelActor({
    required this.userId,
    required this.displayName,
    this.identityType = 'authenticated_cached',
  });

  final String userId;
  final String displayName;
  final String identityType;

  factory OfflineChannelActor.fromUser(UserModel user) {
    return OfflineChannelActor(
      userId: user.id,
      displayName: user.fullName,
      identityType: 'authenticated_cached',
    );
  }

  factory OfflineChannelActor.fromIdentity(LocalIdentityModel identity) {
    return OfflineChannelActor(
      userId: identity.localUserId,
      displayName: identity.displayName,
      identityType: identity.identityType,
    );
  }
}
