import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../trip/data/trip_session_repository.dart';
import '../data/bridge_local_data_source.dart';
import '../data/bridge_repository.dart';
import 'bridge_activity_screen.dart';

class BridgeDebugScreen extends ConsumerWidget {
  const BridgeDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Bridge debug tools are disabled.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Bridge Debug')),
      body: SafeArea(
        child: FutureBuilder<_BridgeDebugSnapshot>(
          future: _load(ref),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                StatusBanner(
                  title: 'Development bridge diagnostics',
                  message:
                      'Use this page for two-device bridge testing only. It is hidden in release builds.',
                  icon: Icons.bug_report_rounded,
                  color: AppColors.warning,
                  action: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.invalidate(bridgeRecordsProvider);
                          ref.invalidate(bridgeStatusProvider);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(bridgeRepositoryProvider)
                              .clearDebugRecords();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Bridge debug records cleared.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.cleaning_services_rounded),
                        label: const Text('Clear records'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section('State', {
                  'Identity': data.identity,
                  'Auth access': data.authAccess,
                  'User mode': data.userMode,
                  'Effective mode': data.effectiveMode,
                  'Backend reachable': data.backendReachable,
                  'Trip': data.trip,
                  'Cloud group': data.cloudGroup,
                  'Channel': data.channel,
                  'Connected peers': data.connectedPeers,
                  'Bridge enabled': data.bridgeEnabled,
                }),
                const SizedBox(height: 14),
                _section('Last bridge records', data.records),
                const SizedBox(height: 14),
                _section('Last processed IDs', data.processed),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_BridgeDebugSnapshot> _load(WidgetRef ref) async {
    final auth = ref.read(authAccessControllerProvider);
    final mode = ref.read(modeControllerProvider);
    final trip = await ref.read(tripSessionRepositoryProvider).getActiveTrip();
    final repository = ref.read(bridgeRepositoryProvider);
    final settings = await repository.getSettings();
    final records = await repository.lastRecords(limit: 10);
    final processed = await repository.lastProcessed(limit: 10);
    final peers = trip?.channelCode == null
        ? 0
        : (await BridgeLocalDataSource().connectedPeers(trip!.channelCode!))
            .length;
    return _BridgeDebugSnapshot(
      identity: auth.identity?.displayName ?? auth.user?.fullName ?? 'None',
      authAccess: auth.accessState.name,
      userMode: mode.userMode.name,
      effectiveMode: mode.effectiveMode.name,
      backendReachable: mode.backendReachable.toString(),
      trip: trip?.tripName ?? 'No active trip',
      cloudGroup: trip?.cloudGroupId ?? 'None',
      channel: trip?.channelCode ?? 'None',
      connectedPeers: peers.toString(),
      bridgeEnabled: settings.bridgeEnabled.toString(),
      records: {
        for (final record in records)
          record.bridgeRecordId:
              '${record.direction} · ${record.status} · ${record.errorMessage ?? 'ok'}',
      },
      processed: {
        for (final item in processed)
          item['unique_item_id'].toString():
              '${item['item_type']} · ${item['source_path']}',
      },
    );
  }

  Widget _section(String title, Map<String, String> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(entry.key)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BridgeDebugSnapshot {
  const _BridgeDebugSnapshot({
    required this.identity,
    required this.authAccess,
    required this.userMode,
    required this.effectiveMode,
    required this.backendReachable,
    required this.trip,
    required this.cloudGroup,
    required this.channel,
    required this.connectedPeers,
    required this.bridgeEnabled,
    required this.records,
    required this.processed,
  });

  final String identity;
  final String authAccess;
  final String userMode;
  final String effectiveMode;
  final String backendReachable;
  final String trip;
  final String cloudGroup;
  final String channel;
  final String connectedPeers;
  final String bridgeEnabled;
  final Map<String, String> records;
  final Map<String, String> processed;
}
