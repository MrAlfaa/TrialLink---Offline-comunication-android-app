import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../../p2p_session/data/p2p_session_guard.dart';
import '../../p2p_session/data/p2p_session_service.dart';
import '../../p2p_session/data/models/p2p_session_model.dart';
import '../../p2p_session/data/models/p2p_session_state.dart';
import '../../trip_context/data/trip_context_service.dart';
import 'nearby_controller.dart';
import 'widgets/discovery_status_banner.dart';
import 'widgets/nearby_permission_notice.dart';
import 'widgets/peer_card.dart';

class NearbyPeersScreen extends ConsumerWidget {
  const NearbyPeersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentUserActorProvider);
    final activeContext = ref.watch(activeTripContextProvider);
    final activeSession = ref.watch(activeP2PSessionProvider);
    final modeState = ref.watch(modeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Phones')),
      body: SafeArea(
        child: actor.when(
          data: (user) {
            if (user == null) {
              return const Center(
                child:
                    Text('Create your TrailLink profile before using Nearby.'),
              );
            }
            return activeContext.when(
              data: (tripContext) {
                final channel = tripContext?.activeChannel;
                if (channel == null) {
                  return _NoActiveChannel(
                    onOpenChannels: () => context.go('/offline-channel'),
                  );
                }
                final args = NearbySessionArgs(
                  tripId: tripContext!.trip.tripId,
                  channel: channel,
                  user: user,
                );
                final state = ref.watch(nearbyControllerProvider(args));
                final controller =
                    ref.read(nearbyControllerProvider(args).notifier);
                final session = activeSession.asData?.value;
                final connectedToAnotherTrip = session != null &&
                    session.tripId != tripContext.trip.tripId &&
                    session.blocksTripSwitch;

                return RefreshIndicator(
                  onRefresh: controller.refreshPeers,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                    children: [
                      CompactStatusRow(
                        children: [
                          ModeStatusChip(state: modeState),
                          PeerStatusChip(count: state.connectedCount),
                          _P2PStatusChip(
                            session: session,
                            currentTripId: tripContext.trip.tripId,
                            connectedCount: state.connectedCount,
                          ),
                          SyncStatusChip(
                            status: state.connectedCount > 0
                                ? SyncChipStatus.ready
                                : SyncChipStatus.paused,
                          ),
                        ],
                      ),
                      if (connectedToAnotherTrip) ...[
                        const SizedBox(height: 14),
                        _SessionMismatchWarning(
                          session: session,
                          onDisconnect: () async {
                            await ref
                                .read(p2pSessionGuardProvider)
                                .disconnectActiveSession(
                                  reason: 'switch_trip',
                                );
                            ref.invalidate(activeP2PSessionProvider);
                          },
                          onOpenCurrentTrip: () => context.go('/trips'),
                        ),
                      ],
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
                            label: const Text('Make my phone visible'),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.isBusy || !state.isAdvertising
                                ? null
                                : controller.stopAdvertising,
                            icon: const Icon(Icons.stop_circle_rounded),
                            label: const Text('Hide my phone'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: state.isBusy || state.isDiscovering
                                ? null
                                : controller.startDiscovery,
                            icon: const Icon(Icons.radar_rounded),
                            label: const Text('Find nearby phones'),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.isBusy || !state.isDiscovering
                                ? null
                                : controller.stopDiscovery,
                            icon: const Icon(Icons.pause_circle_rounded),
                            label: const Text('Stop finding phones'),
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

class _P2PStatusChip extends StatelessWidget {
  const _P2PStatusChip({
    required this.session,
    required this.currentTripId,
    required this.connectedCount,
  });

  final P2PSessionModel? session;
  final String currentTripId;
  final int connectedCount;

  @override
  Widget build(BuildContext context) {
    final connectedElsewhere = connectedCount == 0 &&
        session != null &&
        session!.tripId != currentTripId;
    final label = connectedCount > 0
        ? 'Connected to current trip'
        : connectedElsewhere
            ? 'Connected to another trip'
            : switch (session?.state) {
                P2PSessionState.connecting => 'Connecting',
                P2PSessionState.advertising => 'Visible',
                P2PSessionState.discovering => 'Finding phones',
                _ => 'Disconnected',
              };
    final color = connectedElsewhere
        ? AppColors.warning
        : connectedCount > 0 || session?.state == P2PSessionState.connected
            ? AppColors.success
            : AppColors.muted;
    return CompactStatusChip(
      label: label,
      color: color,
      icon: connectedElsewhere
          ? Icons.warning_amber_rounded
          : Icons.bluetooth_connected_rounded,
    );
  }
}

class _SessionMismatchWarning extends StatelessWidget {
  const _SessionMismatchWarning({
    required this.session,
    required this.onDisconnect,
    required this.onOpenCurrentTrip,
  });

  final P2PSessionModel session;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenCurrentTrip;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.warning.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are connected to another trip.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Your nearby connection is for ${session.channelCode}. Disconnect it before using this trip.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: () async => onDisconnect(),
                  child: const Text('Disconnect & Switch'),
                ),
                OutlinedButton(
                  onPressed: onOpenCurrentTrip,
                  child: const Text('Open Current Trip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _nearbyNoticeBody(String value) {
  if (value.contains('PlatformException')) {
    return 'Nearby connection failed. Find phones again and keep both phones close with TrailLink open.';
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
              'No nearby phones found on this channel.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Make one phone visible and tap Find nearby phones on the other phone using the same channel code.',
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
