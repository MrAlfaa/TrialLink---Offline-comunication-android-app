import 'package:flutter/material.dart';

import '../connectivity/app_connection_mode.dart';
import '../constants/app_colors.dart';
import '../settings/trail_communication_mode.dart';

enum UserMode {
  auto,
  online,
  offline,
}

enum ModeControlType {
  auto,
  manual,
}

enum ManualCommunicationMode {
  online,
  offline,
}

enum DetectedConnectionState {
  backendOnline,
  backendOffline,
  reconnecting,
  unstable,
}

enum EffectiveMode {
  online,
  offline,
  hybridLimited,
}

class ModeState {
  const ModeState({
    required this.userMode,
    required this.modeControlType,
    required this.manualCommunicationMode,
    required this.connectionState,
    required this.effectiveMode,
    required this.autoSwitchEnabled,
    required this.backendReachable,
    required this.hasNetworkInterface,
    required this.socketConnected,
    required this.nearbyAvailable,
    required this.connectedPeerCount,
    this.lastCheckedAt,
    this.warningMessage,
    this.statusMessage,
  });

  factory ModeState.initial() {
    return const ModeState(
      userMode: UserMode.auto,
      modeControlType: ModeControlType.auto,
      manualCommunicationMode: ManualCommunicationMode.offline,
      connectionState: DetectedConnectionState.reconnecting,
      effectiveMode: EffectiveMode.hybridLimited,
      autoSwitchEnabled: true,
      backendReachable: false,
      hasNetworkInterface: false,
      socketConnected: false,
      nearbyAvailable: false,
      connectedPeerCount: 0,
      statusMessage: 'Checking TrailLink communication mode.',
    );
  }

  final UserMode userMode;
  final ModeControlType modeControlType;
  final ManualCommunicationMode manualCommunicationMode;
  final DetectedConnectionState connectionState;
  final EffectiveMode effectiveMode;
  final bool autoSwitchEnabled;
  final bool backendReachable;
  final bool hasNetworkInterface;
  final bool socketConnected;
  final bool nearbyAvailable;
  final int connectedPeerCount;
  final DateTime? lastCheckedAt;
  final String? warningMessage;
  final String? statusMessage;

  ModeState copyWith({
    UserMode? userMode,
    ModeControlType? modeControlType,
    ManualCommunicationMode? manualCommunicationMode,
    DetectedConnectionState? connectionState,
    EffectiveMode? effectiveMode,
    bool? autoSwitchEnabled,
    bool? backendReachable,
    bool? hasNetworkInterface,
    bool? socketConnected,
    bool? nearbyAvailable,
    int? connectedPeerCount,
    DateTime? lastCheckedAt,
    String? warningMessage,
    bool clearWarning = false,
    String? statusMessage,
  }) {
    return ModeState(
      userMode: userMode ?? this.userMode,
      modeControlType: modeControlType ?? this.modeControlType,
      manualCommunicationMode:
          manualCommunicationMode ?? this.manualCommunicationMode,
      connectionState: connectionState ?? this.connectionState,
      effectiveMode: effectiveMode ?? this.effectiveMode,
      autoSwitchEnabled: autoSwitchEnabled ?? this.autoSwitchEnabled,
      backendReachable: backendReachable ?? this.backendReachable,
      hasNetworkInterface: hasNetworkInterface ?? this.hasNetworkInterface,
      socketConnected: socketConnected ?? this.socketConnected,
      nearbyAvailable: nearbyAvailable ?? this.nearbyAvailable,
      connectedPeerCount: connectedPeerCount ?? this.connectedPeerCount,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      warningMessage:
          clearWarning ? null : warningMessage ?? this.warningMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  AppConnectionMode get compatibilityConnectionMode {
    return switch (effectiveMode) {
      EffectiveMode.online => AppConnectionMode.online,
      EffectiveMode.offline => AppConnectionMode.offline,
      EffectiveMode.hybridLimited => AppConnectionMode.unstable,
    };
  }
}

extension ModeControlTypeX on ModeControlType {
  String get label {
    return switch (this) {
      ModeControlType.auto => 'Auto Mode',
      ModeControlType.manual => 'Manual Mode',
    };
  }
}

extension ManualCommunicationModeX on ManualCommunicationMode {
  String get label {
    return switch (this) {
      ManualCommunicationMode.online => 'Online',
      ManualCommunicationMode.offline => 'Offline',
    };
  }

  UserMode get userMode {
    return switch (this) {
      ManualCommunicationMode.online => UserMode.online,
      ManualCommunicationMode.offline => UserMode.offline,
    };
  }
}

extension UserModeX on UserMode {
  String get label {
    return switch (this) {
      UserMode.auto => 'Auto Mode',
      UserMode.online => 'Online Mode',
      UserMode.offline => 'Offline Mode',
    };
  }

  String get shortLabel {
    return switch (this) {
      UserMode.auto => 'Auto',
      UserMode.online => 'Online',
      UserMode.offline => 'Offline',
    };
  }

  String get description {
    return switch (this) {
      UserMode.auto => 'TrailLink switches based on backend availability.',
      UserMode.online =>
        'TrailLink prefers cloud communication and backend sync.',
      UserMode.offline => 'TrailLink uses nearby and local communication.',
    };
  }

  IconData get icon {
    return switch (this) {
      UserMode.auto => Icons.sync_rounded,
      UserMode.online => Icons.cloud_done_rounded,
      UserMode.offline => Icons.settings_input_antenna_rounded,
    };
  }

  Color get color {
    return switch (this) {
      UserMode.auto => AppColors.skyBlue,
      UserMode.online => AppColors.success,
      UserMode.offline => AppColors.offlinePurple,
    };
  }

  TrailCommunicationMode get legacyMode {
    return switch (this) {
      UserMode.auto => TrailCommunicationMode.auto,
      UserMode.online => TrailCommunicationMode.online,
      UserMode.offline => TrailCommunicationMode.offline,
    };
  }
}

extension TrailCommunicationModeToUserMode on TrailCommunicationMode {
  UserMode get userMode {
    return switch (this) {
      TrailCommunicationMode.auto => UserMode.auto,
      TrailCommunicationMode.online => UserMode.online,
      TrailCommunicationMode.offline => UserMode.offline,
    };
  }
}

extension DetectedConnectionStateX on DetectedConnectionState {
  String get label {
    return switch (this) {
      DetectedConnectionState.backendOnline => 'Backend online',
      DetectedConnectionState.backendOffline => 'Backend offline',
      DetectedConnectionState.reconnecting => 'Reconnecting',
      DetectedConnectionState.unstable => 'Unstable',
    };
  }
}

extension EffectiveModeX on EffectiveMode {
  String get label {
    return switch (this) {
      EffectiveMode.online => 'Online',
      EffectiveMode.offline => 'Offline',
      EffectiveMode.hybridLimited => 'Hybrid limited',
    };
  }
}
