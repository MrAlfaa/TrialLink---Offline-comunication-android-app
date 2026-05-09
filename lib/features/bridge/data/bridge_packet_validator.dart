import '../../offline_chat/data/models/offline_packet_model.dart';

class BridgePacketValidationResult {
  const BridgePacketValidationResult._(this.isValid, this.message);

  const BridgePacketValidationResult.valid() : this._(true, null);

  const BridgePacketValidationResult.invalid(String message)
      : this._(false, message);

  final bool isValid;
  final String? message;
}

class BridgePacketValidator {
  static const maxHopCount = 5;

  BridgePacketValidationResult validate({
    required OfflinePacketModel packet,
    required String channelCode,
  }) {
    if (packet.channelCode != channelCode) {
      return const BridgePacketValidationResult.invalid(
        'This packet belongs to another channel and was ignored.',
      );
    }
    if (packet.ttl <= 0 || packet.hopCount > maxHopCount) {
      return const BridgePacketValidationResult.invalid(
        'Expired bridge packet ignored.',
      );
    }
    if ((packet.senderLocalId ?? packet.senderId).trim().isEmpty ||
        packet.senderName.trim().isEmpty) {
      return const BridgePacketValidationResult.invalid(
        'Malformed bridge packet ignored.',
      );
    }
    // TODO: Add channel HMAC/signature validation when packet signing lands.
    return const BridgePacketValidationResult.valid();
  }
}
