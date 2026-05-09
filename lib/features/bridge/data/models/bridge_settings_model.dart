class BridgeSettingsModel {
  const BridgeSettingsModel({
    required this.bridgeEnabled,
    required this.bridgeText,
    required this.bridgeSos,
    required this.bridgeLocation,
    required this.bridgeNormalVoice,
    required this.bridgeEmergencyVoice,
    required this.bridgeOnlySameTrip,
    required this.updatedAt,
  });

  factory BridgeSettingsModel.defaults() {
    return BridgeSettingsModel(
      bridgeEnabled: true,
      bridgeText: true,
      bridgeSos: true,
      bridgeLocation: true,
      bridgeNormalVoice: false,
      bridgeEmergencyVoice: true,
      bridgeOnlySameTrip: true,
      updatedAt: DateTime.now(),
    );
  }

  factory BridgeSettingsModel.fromDb(Map<String, Object?> row) {
    return BridgeSettingsModel(
      bridgeEnabled: row['bridge_enabled'] != 0,
      bridgeText: row['bridge_text'] != 0,
      bridgeSos: row['bridge_sos'] != 0,
      bridgeLocation: row['bridge_location'] != 0,
      bridgeNormalVoice: row['bridge_normal_voice'] == 1,
      bridgeEmergencyVoice: row['bridge_emergency_voice'] != 0,
      bridgeOnlySameTrip: row['bridge_only_same_trip'] != 0,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  final bool bridgeEnabled;
  final bool bridgeText;
  final bool bridgeSos;
  final bool bridgeLocation;
  final bool bridgeNormalVoice;
  final bool bridgeEmergencyVoice;
  final bool bridgeOnlySameTrip;
  final DateTime updatedAt;

  BridgeSettingsModel copyWith({
    bool? bridgeEnabled,
    bool? bridgeText,
    bool? bridgeSos,
    bool? bridgeLocation,
    bool? bridgeNormalVoice,
    bool? bridgeEmergencyVoice,
    bool? bridgeOnlySameTrip,
  }) {
    return BridgeSettingsModel(
      bridgeEnabled: bridgeEnabled ?? this.bridgeEnabled,
      bridgeText: bridgeText ?? this.bridgeText,
      bridgeSos: bridgeSos ?? this.bridgeSos,
      bridgeLocation: bridgeLocation ?? this.bridgeLocation,
      bridgeNormalVoice: bridgeNormalVoice ?? this.bridgeNormalVoice,
      bridgeEmergencyVoice: bridgeEmergencyVoice ?? this.bridgeEmergencyVoice,
      bridgeOnlySameTrip: bridgeOnlySameTrip ?? this.bridgeOnlySameTrip,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'bridge_enabled': bridgeEnabled ? 1 : 0,
      'bridge_text': bridgeText ? 1 : 0,
      'bridge_sos': bridgeSos ? 1 : 0,
      'bridge_location': bridgeLocation ? 1 : 0,
      'bridge_normal_voice': bridgeNormalVoice ? 1 : 0,
      'bridge_emergency_voice': bridgeEmergencyVoice ? 1 : 0,
      'bridge_only_same_trip': bridgeOnlySameTrip ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
