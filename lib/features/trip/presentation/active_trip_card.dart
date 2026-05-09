import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/status_banner.dart';
import '../data/trip_session_model.dart';

class ActiveTripCard extends StatelessWidget {
  const ActiveTripCard({required this.trip, super.key});

  final TripSessionModel trip;

  @override
  Widget build(BuildContext context) {
    final isOffline = trip.mode == 'offline';
    return StatusBanner(
      title: isOffline ? 'Offline trip active' : 'Online trip active',
      message: isOffline
          ? 'Channel Code: ${trip.channelCode ?? 'Not set'}'
          : 'Cloud group connected: ${trip.cloudGroupName ?? trip.tripName}',
      icon: isOffline
          ? Icons.settings_input_antenna_rounded
          : Icons.cloud_done_rounded,
      color: isOffline ? AppColors.offlinePurple : AppColors.success,
    );
  }
}

class NoActiveTripBanner extends StatelessWidget {
  const NoActiveTripBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const StatusBanner(
      title: 'No active trip',
      message:
          'Create or join a trip to connect communication and safety tools.',
      icon: Icons.hiking_rounded,
      color: AppColors.warning,
    );
  }
}
