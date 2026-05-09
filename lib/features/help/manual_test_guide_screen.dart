import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class ManualTestGuideScreen extends StatelessWidget {
  const ManualTestGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const flows = [
      (
        'First-time setup test',
        [
          'Install the app fresh.',
          'Create local profile.',
          'Confirm Home shows Start Trip and Join Trip.',
        ],
      ),
      (
        'Online trip test',
        [
          'Use Cloud + Offline Backup.',
          'Confirm cloud chat and offline channel summary appear.',
          'Switch Online Mode and confirm sync starts.',
        ],
      ),
      (
        'Offline-only trip test',
        [
          'Start Offline Only trip.',
          'Copy the offline channel code.',
          'Confirm Offline Chat, Nearby Peers, SOS, Map, and Walkie-talkie are available.',
        ],
      ),
      (
        'Two-device P2P test',
        [
          'Device A: Start Offline-Only Trip.',
          'Device A: Copy channel code.',
          'Device A: Open Nearby Peers and start discovery/advertising.',
          'Device B: Join Existing Trip with Device A channel code.',
          'Device B: Open Nearby Peers and connect to Device A.',
          'Test offline chat, SOS, location, and PTT.',
        ],
      ),
      (
        'Mode switch test',
        [
          'Switch Auto, Online, and Offline.',
          'Confirm trip tools remain visible.',
          'Confirm pending local data stays queued when offline.',
        ],
      ),
      (
        'SOS test',
        [
          'Open SOS from the active trip.',
          'Send a test alert.',
          'Confirm local save and retry/sync status.',
        ],
      ),
      (
        'Location test',
        [
          'Open Map & Locations.',
          'Get GPS permission.',
          'Share location and confirm latest known coordinate card.',
        ],
      ),
      (
        'PTT test',
        [
          'Open Walkie-talkie.',
          'Hold to record a voice note.',
          'Release and confirm received/saved state.',
        ],
      ),
      (
        'Bridge test if available',
        [
          'Enable bridge settings if the build supports it.',
          'Confirm bridge records stay local-safe when no bridge is active.',
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Manual Test Guide')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 112),
          children: [
            Text(
              'Supervisor and demo testing',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Use these flows to test TrailLink in a predictable order.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.mutedText,
                  ),
            ),
            const SizedBox(height: 18),
            for (final flow in flows) ...[
              _ManualFlowCard(title: flow.$1, steps: flow.$2),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManualFlowCard extends StatelessWidget {
  const _ManualFlowCard({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}.',
                      style: const TextStyle(
                        color: AppColors.deepForest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
