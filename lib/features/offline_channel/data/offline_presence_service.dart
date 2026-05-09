import '../../nearby/data/models/nearby_connection_status.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import 'models/offline_channel_member_model.dart';

class OfflinePresenceService {
  const OfflinePresenceService._();

  static const recentlySeenThreshold = Duration(seconds: 30);
  static const disconnectedThreshold = Duration(seconds: 120);

  static String presenceStatusForLastSeen({
    required DateTime? lastSeenAt,
    required DateTime now,
    required String currentPresence,
  }) {
    if (lastSeenAt == null) return 'unknown';
    final age = now.difference(lastSeenAt);
    if (age >= disconnectedThreshold) return 'disconnected';
    if (age >= recentlySeenThreshold) return 'recently_seen';
    if (currentPresence == 'disconnected') return 'nearby';
    return currentPresence;
  }

  static OfflineChannelMemberModel fromPeer({
    required String channelId,
    required NearbyPeerModel peer,
  }) {
    final presence = switch (peer.status) {
      PeerConnectionStatus.connected => 'connected',
      PeerConnectionStatus.discovered => 'nearby',
      PeerConnectionStatus.connecting => 'nearby',
      PeerConnectionStatus.disconnected => 'disconnected',
      PeerConnectionStatus.lost => 'disconnected',
      PeerConnectionStatus.failed => 'disconnected',
    };
    return OfflineChannelMemberModel(
      channelId: channelId,
      userId: peer.userId,
      displayName: peer.displayName,
      memberRole: 'member',
      source: 'peer',
      status: 'active',
      membershipStatus: 'active',
      presenceStatus: presence,
      connectionStatus: peer.status.name,
      endpointId: peer.endpointId,
      identityType: 'guest',
      joinedAt: peer.discoveredAt,
      lastSeenAt: peer.lastSeenAt,
    );
  }
}
