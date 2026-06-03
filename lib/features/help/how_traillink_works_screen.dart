import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class HowTrailLinkWorksScreen extends StatelessWidget {
  const HowTrailLinkWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        Icons.hiking_rounded,
        'Choose a trip path',
        'Create an online trip, create an offline trip, or join with a code from your team.',
      ),
      (
        Icons.cloud_done_rounded,
        'Online trips use internet chat',
        'When internet is available, team chat and membership use the TrailLink server.',
      ),
      (
        Icons.hub_rounded,
        'Offline trips use nearby phones',
        'In remote areas, teammates use the same trip code and connect phones nearby.',
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
        'Online trips keep nearby support ready',
        'TrailLink saves the trip code and teammate details on this phone so the trip can keep working in remote areas.',
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
              'Online chat uses the internet. Nearby phone connection is for offline trips, remote areas, and safety support.',
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
