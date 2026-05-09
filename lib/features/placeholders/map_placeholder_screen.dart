import 'package:flutter/material.dart';

import 'placeholder_module_screen.dart';

class MapPlaceholderScreen extends StatelessWidget {
  const MapPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderModuleScreen(
      title: 'Map',
      phase: 'Phase 03',
      icon: Icons.map_rounded,
      description:
          'Offline location sharing, cached map support, and teammate visibility are future modules.',
    );
  }
}
