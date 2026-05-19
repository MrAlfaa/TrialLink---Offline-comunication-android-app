import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trip_context/data/models/active_trip_context.dart';
import '../../trip_context/data/trip_member_device_roster_repository.dart';
import 'models/nearby_peer_model.dart';

final peerValidationServiceProvider = Provider<PeerValidationService>((ref) {
  return PeerValidationService(
    rosterRepository: ref.read(tripMemberDeviceRosterRepositoryProvider),
  );
});

enum PeerValidationResult {
  verifiedMember,
  cachedMember,
  unknownSameChannel,
  mismatch,
}

class PeerValidationService {
  const PeerValidationService({
    required TripMemberDeviceRosterRepository rosterRepository,
  }) : _rosterRepository = rosterRepository;

  final TripMemberDeviceRosterRepository _rosterRepository;

  Future<PeerValidationResult> validatePeer({
    required ActiveTripContext context,
    required NearbyPeerModel peer,
    bool allowUnknownSameChannel = true,
  }) async {
    final channel = context.activeChannel;
    if (channel == null) return PeerValidationResult.mismatch;
    if (peer.activeChannelCode != channel.channelCode) {
      return PeerValidationResult.mismatch;
    }
    final tripId = peer.tripId;
    final hasTripMismatch = tripId != null &&
        tripId.isNotEmpty &&
        !_matchesCompact(context.trip.tripId, tripId);
    if (hasTripMismatch && !allowUnknownSameChannel) {
      return PeerValidationResult.mismatch;
    }
    final match = await _rosterRepository.findMatchingDevice(
      tripId: context.trip.tripId,
      peer: peer,
    );
    if (match != null) {
      return match['app_device_id']?.toString() == peer.appDeviceId
          ? PeerValidationResult.verifiedMember
          : PeerValidationResult.cachedMember;
    }
    return allowUnknownSameChannel
        ? PeerValidationResult.unknownSameChannel
        : PeerValidationResult.mismatch;
  }

  static String statusName(PeerValidationResult result) {
    return switch (result) {
      PeerValidationResult.verifiedMember => 'verified_member',
      PeerValidationResult.cachedMember => 'cached_member',
      PeerValidationResult.unknownSameChannel => 'unknown_same_channel',
      PeerValidationResult.mismatch => 'mismatch',
    };
  }

  static bool _matchesCompact(String full, String compact) {
    return full == compact ||
        full.startsWith(compact) ||
        compact.startsWith(full);
  }
}
