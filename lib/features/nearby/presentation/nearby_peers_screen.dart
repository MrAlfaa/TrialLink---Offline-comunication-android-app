import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import 'nearby_controller.dart';
import 'widgets/discovery_status_banner.dart';
import 'widgets/nearby_permission_notice.dart';
import 'widgets/peer_card.dart';

class NearbyPeersScreen extends ConsumerWidget {
  const NearbyPeersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentUserActorProvider);
    final activeChannel = ref.watch(activeUsableOfflineChannelProvider);
    final modeState = ref.watch(modeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Peers')),
      body: SafeArea(
        child: actor.when(
          data: (user) {
            if (user == null) {
              return const Center(
                child:
                    Text('Create your TrailLink profile before using Nearby.'),
              );
            }
            return activeChannel.when(
              data: (channel) {
                if (channel == null) {
                  return _NoActiveChannel(
                    onOpenChannels: () => context.go('/offline-channel'),
                  );
                }
                final args = NearbySessionArgs(channel: channel, user: user);
                final state = ref.watch(nearbyControllerProvider(args));
                final controller =
                    ref.read(nearbyControllerProvider(args).notifier);

                return RefreshIndicator(
                  onRefresh: controller.refreshPeers,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                    children: [
                      CompactStatusRow(
                        children: [
                          ModeStatusChip(state: modeState),
                          PeerStatusChip(count: state.connectedCount),
                          SyncStatusChip(
                            status: state.connectedCount > 0
                                ? SyncChipStatus.ready
                                : SyncChipStatus.paused,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppColors.deepForest,
                                foregroundColor: Colors.white,
                                child: Icon(Icons.hub_rounded),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      channel.channelName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      'Channel Code ${channel.channelCode}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              const Chip(label: Text('Active')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DiscoveryStatusBanner(
                        isAdvertising: state.isAdvertising,
                        isDiscovering: state.isDiscovering,
                        connectedCount: state.connectedCount,
                        lastScanAt: state.lastScanAt,
                      ),
                      const SizedBox(height: 14),
                      if (state.errorMessage != null)
                        state.errorMessage!.toLowerCase().contains('permission')
                            ? NearbyPermissionNotice(
                                message: state.errorMessage!,
                                onRequest: controller.requestPermissions,
                              )
                            : _NearbyErrorNotice(message: state.errorMessage!),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: state.isBusy || state.isAdvertising
                                ? null
                                : controller.startAdvertising,
                            icon: const Icon(Icons.campaign_rounded),
                            label: const Text('Start Advertising'),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.isBusy || !state.isAdvertising
                                ? null
                                : controller.stopAdvertising,
                            icon: const Icon(Icons.stop_circle_rounded),
                            label: const Text('Stop Advertising'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: state.isBusy || state.isDiscovering
                                ? null
                                : controller.startDiscovery,
                            icon: const Icon(Icons.radar_rounded),
                            label: const Text('Start Discovery'),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.isBusy || !state.isDiscovering
                                ? null
                                : controller.stopDiscovery,
                            icon: const Icon(Icons.pause_circle_rounded),
                            label: const Text('Stop Discovery'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (state.peers.isEmpty)
                        const _EmptyPeers()
                      else
                        ...state.peers.map(
                          (peer) => TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: PeerCard(
                              peer: peer,
                              onConnect: () =>
                                  controller.connectToPeer(peer.endpointId),
                              onDisconnect: () => controller
                                  .disconnectFromPeer(peer.endpointId),
                            ),
                          ),
                        ),
                      if (state.successMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.successMessage!,
                          style: const TextStyle(color: AppColors.success),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
        ),
      ),
    );
  }
}

class _NearbyErrorNotice extends StatelessWidget {
  const _NearbyErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby action failed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(_nearbyNoticeBody(message)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _nearbyNoticeBody(String value) {
  if (value.contains('PlatformException')) {
    return 'Nearby connection failed. Start discovery again and keep both phones close with Nearby open.';
  }
  return value;
}

class _NoActiveChannel extends StatelessWidget {
  const _NoActiveChannel({required this.onOpenChannels});

  final VoidCallback onOpenChannels;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hub_outlined, size: 54, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'Please create or join an offline channel first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onOpenChannels,
              icon: const Icon(Icons.hub_rounded),
              label: const Text('Open Offline Channels'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPeers extends StatelessWidget {
  const _EmptyPeers();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.travel_explore_rounded,
                size: 46, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(
              'No nearby TrailLink users found on this channel.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Start advertising and discovery on both phones using the same channel code.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
