import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class HowTrailLinkWorksScreen extends StatelessWidget {
  const HowTrailLinkWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.hiking_rounded,
        'Start or join a trip',
        'A trip connects messages, SOS, map, nearby peers, and walkie-talkie tools in one place.',
      ),
      (
        Icons.cloud_done_rounded,
        'Online mode uses cloud chat',
        'When internet is available, TrailLink can use cloud groups for team chat and syncing.',
      ),
      (
        Icons.hub_rounded,
        'Offline mode uses nearby phones and channel code',
        'In remote areas, teammates use the same offline channel code and nearby discovery.',
      ),
      (
        Icons.sos_rounded,
        'SOS works even without internet',
        'Emergency alerts are saved locally first and sent through the best available path.',
      ),
      (
        Icons.location_on_rounded,
        'Location sharing is optional',
        'You can share GPS when permission is granted. Saved teammate locations remain visible offline.',
      ),
      (
        Icons.record_voice_over_rounded,
        'Voice-note PTT works in offline mode',
        'Walkie-talkie records a short voice note and sends it after release.',
      ),
      (
        Icons.sync_rounded,
        'Data saves locally first and syncs later',
        'TrailLink keeps your latest known trip data on this phone and syncs when Online Mode is ready.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('How TrailLink Works')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
          children: [
            Text(
              'Use TrailLink by starting with a trip.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The app chooses online, offline, or saved-local paths based on your mode and connection.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mutedText,
                  ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < items.length; i++) ...[
              _HowItWorksCard(
                number: i + 1,
                icon: items[i].$1,
                title: items[i].$2,
                message: items[i].$3,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.message,
  });

  final int number;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.deepForest,
              foregroundColor: Colors.white,
              child: Text('$number'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: AppColors.deepForest),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
