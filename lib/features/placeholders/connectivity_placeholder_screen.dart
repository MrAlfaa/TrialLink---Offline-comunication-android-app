import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/mode/mode_controller.dart';
import '../../shared/widgets/mode_status_widgets.dart';

class ConnectivityPlaceholderScreen extends ConsumerWidget {
  const ConnectivityPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeState = ref.watch(modeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Connectivity')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            CompactStatusRow(
              children: [
                ModeStatusChip(state: modeState),
                PeerStatusChip(count: modeState.connectedPeerCount),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.deepForest,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.radar_rounded),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nearby offline discovery',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Find and connect TrailLink users on the same active offline channel. Discovery works without backend internet access.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/nearby-peers'),
                      icon: const Icon(Icons.travel_explore_rounded),
                      label: const Text('Open Nearby Peers'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Future guidance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Signal guidance and advanced connectivity recommendations remain planned for later phases.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
