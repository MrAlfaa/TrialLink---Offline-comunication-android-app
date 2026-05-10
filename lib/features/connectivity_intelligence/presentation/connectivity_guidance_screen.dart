import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import 'connectivity_controller.dart';
import 'widgets/guidance_banner.dart';
import 'widgets/network_health_card.dart';
import 'widgets/peer_quality_card.dart';

class ConnectivityGuidanceScreen extends ConsumerWidget {
  const ConnectivityGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityControllerProvider);
    final controller = ref.read(connectivityControllerProvider.notifier);
    final summary = state.summary;
    final modeState = ref.watch(modeControllerProvider);
    final activeChannel =
        ref.watch(activeUsableOfflineChannelProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connectivity Guidance'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isRefreshing ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
            children: [
              CompactStatusRow(
                children: [
                  ModeStatusChip(state: modeState),
                  PeerStatusChip(count: summary?.qualities.length ?? 0),
                  CompactStatusChip(
                    label: '${summary?.pendingOfflineMessages ?? 0} queued',
                    color: (summary?.pendingOfflineMessages ?? 0) > 0
                        ? AppColors.warning
                        : AppColors.muted,
                    icon: Icons.inventory_2_rounded,
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activeChannel != null) ...[
                CompactStatusChip(
                  label: activeChannel.channelCode,
                  color: AppColors.offlinePurple,
                  icon: Icons.hub_rounded,
                  dense: true,
                ),
                const SizedBox(height: 12),
              ],
              if (summary == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (activeChannel == null) ...[
                  InlineInfoNotice(
                    message:
                        'Create or join an offline channel to use peer guidance.',
                    icon: Icons.hub_rounded,
                    action: TextButton(
                      onPressed: () => context.go('/offline-channel'),
                      child: const Text('Open'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GuidanceBanner(guidance: summary.guidance),
                const SizedBox(height: 12),
                NetworkHealthCard(summary: summary),
                const SizedBox(height: 16),
                Text(
                  'Peer Ranking',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (summary.qualities.isEmpty)
                  InlineInfoNotice(
                    message:
                        'Start Nearby Discovery to collect ACK delay and packet metrics.',
                    icon: Icons.radar_rounded,
                    action: TextButton(
                      onPressed: () => context.go('/nearby-peers'),
                      child: const Text('Start'),
                    ),
                  )
                else
                  ...summary.qualities.map(
                    (peer) => PeerQualityCard(peer: peer),
                  ),
              ],
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
