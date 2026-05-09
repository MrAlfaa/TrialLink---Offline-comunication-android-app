import 'package:flutter/material.dart';

import 'placeholder_module_screen.dart';

class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderModuleScreen(
      title: 'Settings',
      phase: 'Phase 02',
      icon: Icons.settings_rounded,
      description:
          'Profile-free app preferences, connectivity defaults, and safety options will be added later.',
    );
  }
}
