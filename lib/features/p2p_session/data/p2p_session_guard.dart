import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nearby/data/nearby_repository.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../trip/data/trip_session_repository.dart';
import '../../trip_context/data/trip_context_service.dart';
import 'models/p2p_session_state.dart';
import 'p2p_disconnect_service.dart';
import 'p2p_session_service.dart';

final p2pSessionGuardProvider = Provider<P2PSessionGuard>((ref) {
  return P2PSessionGuard(
    sessionService: ref.read(p2pSessionServiceProvider),
    disconnectService: ref.read(p2pDisconnectServiceProvider),
    tripContextService: ref.read(tripContextServiceProvider),
    tripRepository: ref.read(tripSessionRepositoryProvider),
    nearbyRepository: ref.read(nearbyRepositoryProvider),
  );
});

class P2PSessionGuard {
  P2PSessionGuard({
    required P2PSessionService sessionService,
    required P2PDisconnectService disconnectService,
    required TripContextService tripContextService,
    required TripSessionRepository tripRepository,
    required NearbyRepository nearbyRepository,
  })  : _sessionService = sessionService,
        _disconnectService = disconnectService,
        _tripContextService = tripContextService,
        _tripRepository = tripRepository,
        _nearbyRepository = nearbyRepository;

  final P2PSessionService _sessionService;
  final P2PDisconnectService _disconnectService;
  final TripContextService _tripContextService;
  final TripSessionRepository _tripRepository;
  final NearbyRepository _nearbyRepository;

  Future<TripSwitchDecision> canSwitchToTrip(
    String newTripId, {
    String? newTripName,
  }) async {
    final session = await _sessionService.getActiveSession();
    if (session == null || !session.blocksTripSwitch) {
      return TripSwitchDecision(
        type: TripSwitchDecisionType.allowed,
        newTripName: newTripName,
      );
    }
    if (session.tripId == newTripId) {
      return TripSwitchDecision(
        type: TripSwitchDecisionType.sameTrip,
        currentTripName: newTripName,
        newTripName: newTripName,
      );
    }
    final currentTrip = await _tripRepository.getTrip(session.tripId);
    return TripSwitchDecision(
      type: TripSwitchDecisionType.requiresDisconnect,
      currentTripName: currentTrip?.tripName ?? session.channelCode,
      newTripName: newTripName,
    );
  }

  Future<bool> requireDisconnectBeforeSwitch(String newTripId) async {
    return (await canSwitchToTrip(newTripId)).requiresDisconnect;
  }

  Future<void> disconnectAndSwitchTrip(
    String newTripId, {
    String reason = 'switch_trip',
  }) async {
    await _disconnectService.stopActiveSession(
      nearbyRepository: _nearbyRepository,
      reason: reason,
    );
    await _tripContextService.activateTrip(newTripId);
  }

  Future<void> disconnectActiveSession({
    String reason = 'manual_disconnect',
  }) {
    return _disconnectService.stopActiveSession(
      nearbyRepository: _nearbyRepository,
      reason: reason,
    );
  }
}
