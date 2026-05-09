import 'package:flutter/material.dart';

import 'placeholder_module_screen.dart';

class OfflineChannelPlaceholderScreen extends StatelessWidget {
  const OfflineChannelPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderModuleScreen(
      title: 'Offline Channel',
      phase: 'Phase 02',
      icon: Icons.hub_rounded,
      description:
          'BLE, Wi-Fi Direct, and Nearby-style local channel communication are reserved for later implementation.',
    );
  }
}
