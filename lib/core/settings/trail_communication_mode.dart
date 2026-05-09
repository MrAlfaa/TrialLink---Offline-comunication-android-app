import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum TrailCommunicationMode {
  auto,
  online,
  offline,
}

extension TrailCommunicationModeX on TrailCommunicationMode {
  String get label {
    return switch (this) {
      TrailCommunicationMode.auto => 'Auto Mode',
      TrailCommunicationMode.online => 'Online Mode',
      TrailCommunicationMode.offline => 'Offline Mode',
    };
  }

  String get shortLabel {
    return switch (this) {
      TrailCommunicationMode.auto => 'Auto',
      TrailCommunicationMode.online => 'Online',
      TrailCommunicationMode.offline => 'Offline',
    };
  }

  String get description {
    return switch (this) {
      TrailCommunicationMode.auto =>
        'TrailLink previews automatic online/offline behavior.',
      TrailCommunicationMode.online =>
        'Use cloud chat, backend sync, and online safety tools.',
      TrailCommunicationMode.offline =>
        'Use nearby channel tools and local-first safety communication.',
    };
  }

  IconData get icon {
    return switch (this) {
      TrailCommunicationMode.auto => Icons.sync_rounded,
      TrailCommunicationMode.online => Icons.cloud_done_rounded,
      TrailCommunicationMode.offline => Icons.settings_input_antenna_rounded,
    };
  }

  Color get color {
    return switch (this) {
      TrailCommunicationMode.auto => AppColors.skyBlue,
      TrailCommunicationMode.online => AppColors.success,
      TrailCommunicationMode.offline => AppColors.offlinePurple,
    };
  }
}
