import 'package:flutter/material.dart';

import 'placeholder_module_screen.dart';

class ChatPlaceholderScreen extends StatelessWidget {
  const ChatPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderModuleScreen(
      title: 'Chat',
      phase: 'Phase 02',
      icon: Icons.forum_rounded,
      description:
          'Online and offline messaging workflows will be added after the foundation is verified.',
    );
  }
}
