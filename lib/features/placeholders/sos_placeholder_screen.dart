import 'package:flutter/material.dart';

import 'placeholder_module_screen.dart';

class SosPlaceholderScreen extends StatelessWidget {
  const SosPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderModuleScreen(
      title: 'SOS',
      phase: 'Phase 03',
      icon: Icons.sos_rounded,
      description:
          'Emergency alert broadcasting and prioritization will be built after the communication foundation.',
    );
  }
}
