import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../trip_context/data/trip_context_service.dart';
import 'offline_channel_controller.dart';
import 'widgets/offline_channel_card.dart';
import 'widgets/offline_mode_notice.dart';

class OfflineChannelListScreen extends ConsumerWidget {
  const OfflineChannelListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsValue = ref.watch(offlineChannelListProvider);
    final controller = ref.read(offlineChannelControllerProvider.notifier);
    final modeState = ref.watch(modeControllerProvider);
    ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Channel')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(offlineChannelListProvider);
            ref.invalidate(activeOfflineChannelProvider);
            ref.invalidate(activeUsableOfflineChannelProvider);
            ref.invalidate(activeTripChannelProvider);
            ref.invalidate(activeTripContextProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
            children: [
              CompactStatusRow(
                children: [
                  ModeStatusChip(state: modeState),
                  SyncStatusChip(
                    status: modeState.effectiveMode == EffectiveMode.online
                        ? SyncChipStatus.ready
                        : SyncChipStatus.paused,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const OfflineModeNotice(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go('/offline-channel/create'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/offline-channel/join'),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Join'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/nearby-peers'),
                icon: const Icon(Icons.radar_rounded),
                label: const Text('Nearby Peers'),
              ),
              const SizedBox(height: 16),
              channelsValue.when(
                data: (channels) {
                  if (channels.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hub_rounded,
                            size: 62,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No offline channels yet',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create or join a channel before entering remote areas.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: channels
                        .map(
                          (channel) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OfflineChannelCard(
                              channel: channel,
                              onTap: () => context.go(
                                '/offline-channel/${channel.channelId}',
                              ),
                              onSetActive: () async {
                                await controller
                                    .setActiveChannel(channel.channelId);
                                ref.invalidate(offlineChannelListProvider);
                                ref.invalidate(activeOfflineChannelProvider);
                                ref.invalidate(
                                    activeUsableOfflineChannelProvider);
                                ref.invalidate(activeTripChannelProvider);
                                ref.invalidate(activeTripContextProvider);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text(error.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
