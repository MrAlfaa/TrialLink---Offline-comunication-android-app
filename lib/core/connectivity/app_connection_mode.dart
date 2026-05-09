import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum AppConnectionMode {
  online,
  offline,
  reconnecting,
  unstable,
}

extension AppConnectionModeX on AppConnectionMode {
  String get label {
    return switch (this) {
      AppConnectionMode.online => 'Online',
      AppConnectionMode.offline => 'Offline Mode',
      AppConnectionMode.reconnecting => 'Reconnecting',
      AppConnectionMode.unstable => 'Unstable Connection',
    };
  }

  String get description {
    return switch (this) {
      AppConnectionMode.online => 'Backend communication is available.',
      AppConnectionMode.offline =>
        'Offline mode active. Data will be saved locally.',
      AppConnectionMode.reconnecting =>
        'Network detected. Checking backend connection.',
      AppConnectionMode.unstable =>
        'Connection is unstable. Messages may be queued.',
    };
  }

  Color get color {
    return switch (this) {
      AppConnectionMode.online => AppColors.success,
      AppConnectionMode.offline => AppColors.warning,
      AppConnectionMode.reconnecting => AppColors.skyBlue,
      AppConnectionMode.unstable => AppColors.signalOrange,
    };
  }
}
