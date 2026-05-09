import '../../../core/identity/auth_access_state.dart';
import '../../../core/mode/mode_models.dart';
import '../../offline_chat/data/models/offline_packet_model.dart';
import '../../trip/data/trip_session_model.dart';
import 'bridge_packet_validator.dart';
import 'models/bridge_settings_model.dart';

class BridgePolicyResult {
  const BridgePolicyResult.allowed()
      : allowed = true,
        reason = null;
  const BridgePolicyResult.denied(this.reason) : allowed = false;

  final bool allowed;
  final String? reason;
}

class BridgePolicy {
  BridgePolicy({BridgePacketValidator? validator})
      : _validator = validator ?? BridgePacketValidator();

  final BridgePacketValidator _validator;

  BridgePolicyResult canBridgeOfflineToOnline({
    required bool featureEnabled,
    required BridgeSettingsModel settings,
    required TripSessionModel? activeTrip,
    required OfflinePacketModel packet,
    required AuthAccessState authAccessState,
    required ModeState modeState,
    required bool duplicate,
  }) {
    if (!featureEnabled || !settings.bridgeEnabled) {
      return const BridgePolicyResult.denied(
        'Bridge Mode is disabled in Settings.',
      );
    }
    if (activeTrip == null) {
      return const BridgePolicyResult.denied('No active trip.');
    }
    if ((activeTrip.cloudGroupId ?? '').isEmpty) {
      return const BridgePolicyResult.denied('Missing cloud group ID.');
    }
    if ((activeTrip.channelCode ?? '').isEmpty) {
      return const BridgePolicyResult.denied('Missing offline channel code.');
    }
    final validation = _validator.validate(
      packet: packet,
      channelCode: activeTrip.channelCode!,
    );
    if (!validation.isValid) {
      return BridgePolicyResult.denied(validation.message!);
    }
    if (duplicate) {
      return const BridgePolicyResult.denied('Duplicate packet ignored.');
    }
    if (authAccessState != AuthAccessState.authenticatedOnline) {
      return const BridgePolicyResult.denied(
        'Bridge actor must be authenticated online.',
      );
    }
    if (!modeState.backendReachable) {
      return const BridgePolicyResult.denied(
        'Backend unavailable. Bridge upload queued.',
      );
    }
    if (!_packetTypeAllowed(packet.packetType, settings, packet.payload)) {
      return const BridgePolicyResult.denied(
        'This bridge data type is disabled.',
      );
    }
    return const BridgePolicyResult.allowed();
  }

  BridgePolicyResult canBridgeOnlineToOffline({
    required bool featureEnabled,
    required BridgeSettingsModel settings,
    required TripSessionModel? activeTrip,
    required String groupId,
    required bool duplicate,
    required int connectedPeerCount,
  }) {
    if (!featureEnabled || !settings.bridgeEnabled) {
      return const BridgePolicyResult.denied(
        'Bridge Mode is disabled in Settings.',
      );
    }
    if (!settings.bridgeText) {
      return const BridgePolicyResult.denied('Text bridge is disabled.');
    }
    if (activeTrip == null) {
      return const BridgePolicyResult.denied('No active trip.');
    }
    if (activeTrip.cloudGroupId != groupId) {
      return const BridgePolicyResult.denied(
        'Message is not for the active trip group.',
      );
    }
    if ((activeTrip.offlineChannelId ?? '').isEmpty ||
        (activeTrip.channelCode ?? '').isEmpty) {
      return const BridgePolicyResult.denied('Missing offline channel code.');
    }
    if (duplicate) {
      return const BridgePolicyResult.denied('Duplicate packet ignored.');
    }
    if (connectedPeerCount <= 0) {
      return const BridgePolicyResult.denied(
        'No nearby offline peers to bridge.',
      );
    }
    return const BridgePolicyResult.allowed();
  }

  bool _packetTypeAllowed(
    String packetType,
    BridgeSettingsModel settings,
    Map<String, dynamic> payload,
  ) {
    return switch (packetType) {
      'text' => settings.bridgeText,
      'sos' => settings.bridgeSos,
      'location' => settings.bridgeLocation,
      'voice_note' => payload['priority'] == 'emergency'
          ? settings.bridgeEmergencyVoice
          : settings.bridgeNormalVoice,
      _ => false,
    };
  }
}
