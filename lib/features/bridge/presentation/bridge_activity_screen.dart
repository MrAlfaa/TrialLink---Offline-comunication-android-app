import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../trip/data/trip_session_repository.dart';
import '../data/bridge_local_data_source.dart';
import '../data/bridge_repository.dart';
import 'widgets/bridge_activity_tile.dart';
import 'widgets/bridge_status_card.dart';

final bridgeRecordsProvider = FutureProvider.autoDispose(
    (ref) => ref.read(bridgeRepositoryProvider).lastRecords());

final bridgeStatusProvider = FutureProvider.autoDispose((ref) async {
  final trip = await ref.read(tripSessionRepositoryProvider).getActiveTrip();
  final settings = await ref.read(bridgeRepositoryProvider).getSettings();
  final peerCount = trip?.channelCode == null
      ? 0
      : (await BridgeLocalDataSource().connectedPeers(trip!.channelCode!))
          .length;
  return (trip: trip, settings: settings, peerCount: peerCount);
});

class BridgeActivityScreen extends ConsumerWidget {
  const BridgeActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(bridgeStatusProvider);
    final records = ref.watch(bridgeRecordsProvider);
    final mode = ref.watch(modeControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bridge Activity'),
        actions: [
          IconButton(
            tooltip: 'Bridge Settings',
            onPressed: () => context.go('/settings/bridge'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bridgeStatusProvider);
            ref.invalidate(bridgeRecordsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              status.when(
                data: (value) => BridgeStatusCard(
                  settings: value.settings,
                  backendReachable: mode.backendReachable,
                  connectedPeerCount: value.peerCount,
                  channelCode: value.trip?.channelCode,
                ),
                loading: () => const StatusBanner(
                  title: 'Checking bridge state',
                  message: 'Loading current trip, peers, and bridge settings.',
                  icon: Icons.cable_rounded,
                  color: AppColors.skyBlue,
                ),
                error: (_, __) => const StatusBanner(
                  title: 'Bridge state unavailable',
                  message: 'Open Settings to verify bridge configuration.',
                  icon: Icons.warning_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 18),
              Text('Recent Activity',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              records.when(
                data: (items) => items.isEmpty
                    ? const StatusBanner(
                        title: 'No bridge activity yet',
                        message:
                            'Bridge records will appear here when online/offline data is forwarded.',
                        icon: Icons.info_outline_rounded,
                        color: AppColors.skyBlue,
                      )
                    : Column(
                        children: [
                          for (final record in items)
                            BridgeActivityTile(record: record),
                        ],
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const StatusBanner(
                  title: 'Activity unavailable',
                  message: 'Bridge history could not be loaded.',
                  icon: Icons.warning_rounded,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
