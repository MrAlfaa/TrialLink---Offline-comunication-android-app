import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

enum LocationFreshness {
  fresh,
  old,
  stale,
}

extension LocationFreshnessX on LocationFreshness {
  String get label {
    return switch (this) {
      LocationFreshness.fresh => 'Fresh',
      LocationFreshness.old => 'Old',
      LocationFreshness.stale => 'Stale',
    };
  }

  Color get color {
    return switch (this) {
      LocationFreshness.fresh => AppColors.success,
      LocationFreshness.old => AppColors.warning,
      LocationFreshness.stale => AppColors.danger,
    };
  }
}

LocationFreshness calculateLocationFreshness(DateTime capturedAt) {
  final age = DateTime.now().difference(capturedAt);
  if (age <= const Duration(minutes: 5)) return LocationFreshness.fresh;
  if (age <= const Duration(minutes: 30)) return LocationFreshness.old;
  return LocationFreshness.stale;
}
