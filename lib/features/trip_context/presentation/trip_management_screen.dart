import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../p2p_session/data/p2p_session_guard.dart';
import '../../p2p_session/data/p2p_session_service.dart';
import '../../p2p_session/presentation/p2p_session_switch_dialog.dart';
import '../../trip/data/trip_session_model.dart';
import '../data/trip_context_service.dart';
import '../data/trip_member_device_roster_repository.dart';

class TripManagementScreen extends ConsumerWidget {
  const TripManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContext = ref.watch(activeTripContextProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          IconButton(
            tooltip: 'Refresh trips',
            onPressed: () => ref.invalidate(activeTripContextProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: activeContext.when(
        data: (_) => FutureBuilder<List<TripSessionModel>>(
          future: ref.read(tripContextServiceProvider).getTrips(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final trips = snapshot.data ?? const [];
            if (trips.isEmpty) {
              return const _EmptyTripsState();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _TripManagementCard(trip: trips[index]);
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString(), textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _TripManagementCard extends ConsumerWidget {
  const _TripManagementCard({required this.trip});

  final TripSessionModel trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(tripContextServiceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trip.tripName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _StatusChip(label: trip.status, active: trip.isActive),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                'Mode: ${trip.mode}',
                if ((trip.channelCode ?? '').isNotEmpty)
                  'Trip code: ${trip.channelCode}',
              ].join('  |  '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            FutureBuilder<(int, int)>(
              future: _rosterCounts(ref, trip.tripId),
              builder: (context, snapshot) {
                final counts = snapshot.data ?? (0, 0);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusChip(
                      label: trip.cloudGroupId == null
                          ? 'Internet not linked'
                          : 'Internet trip',
                      active: trip.cloudGroupId != null,
                    ),
                    _StatusChip(
                      label: trip.offlineBackupReady
                          ? 'Nearby support ready'
                          : 'Nearby support not ready',
                      active: trip.offlineBackupReady,
                    ),
                    if ((trip.channelCode ?? '').isNotEmpty)
                      _StatusChip(
                        label: 'Trip code ${trip.channelCode}',
                        active: true,
                      ),
                    _StatusChip(
                      label: 'Members saved ${counts.$1}',
                      active: counts.$1 > 0,
                    ),
                    _StatusChip(
                      label: 'Phones saved ${counts.$2}',
                      active: counts.$2 > 0,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<OfflineChannelModel>>(
              future: service.getChannelsForTrip(trip.tripId),
              builder: (context, snapshot) {
                final channels = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                if (channels.isEmpty) {
                  return const Text('No trip code linked yet.');
                }
                return Column(
                  children: [
                    for (final channel in channels)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          channel.isActive
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: channel.isActive
                              ? AppColors.success
                              : AppColors.mutedText,
                        ),
                        title: Text(channel.channelName),
                        subtitle: Text(channel.channelCode),
                        trailing: channel.isActive
                            ? const Text('Active')
                            : TextButton(
                                onPressed: () async {
                                  final action = await _resolveTripSwitchAction(
                                    context,
                                    ref,
                                    trip,
                                    allowCreateInactive: false,
                                  );
                                  if (action == P2PSessionSwitchAction.cancel) {
                                    return;
                                  }
                                  if (action ==
                                      P2PSessionSwitchAction
                                          .disconnectAndSwitch) {
                                    await ref
                                        .read(p2pSessionGuardProvider)
                                        .disconnectActiveSession(
                                          reason: 'switch_trip',
                                        );
                                  }
                                  await service
                                      .switchActiveChannel(channel.channelId);
                                  ref.invalidate(activeTripContextProvider);
                                },
                                child: const Text('Activate'),
                              ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: trip.isActive
                      ? null
                      : () async {
                          final action = await _resolveTripSwitchAction(
                            context,
                            ref,
                            trip,
                            allowCreateInactive: false,
                          );
                          if (action == P2PSessionSwitchAction.cancel) {
                            return;
                          }
                          if (action ==
                              P2PSessionSwitchAction.disconnectAndSwitch) {
                            await ref
                                .read(p2pSessionGuardProvider)
                                .disconnectActiveSession(
                                  reason: 'switch_trip',
                                );
                          }
                          await service.activateTrip(trip.tripId);
                          ref.invalidate(activeTripContextProvider);
                        },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Activate trip'),
                ),
                OutlinedButton.icon(
                  onPressed: trip.status == 'archived'
                      ? null
                      : () async {
                          final session = await ref
                              .read(p2pSessionServiceProvider)
                              .getActiveSession();
                          if (session?.tripId == trip.tripId) {
                            await ref
                                .read(p2pSessionGuardProvider)
                                .disconnectActiveSession(
                                  reason: 'archive_trip',
                                );
                          }
                          await service.archiveTrip(trip.tripId);
                          ref.invalidate(activeTripContextProvider);
                        },
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Archive'),
                ),
                FutureBuilder<bool>(
                  future: service.canDeleteTrip(trip.tripId),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) {
                      return const SizedBox.shrink();
                    }
                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: () => _confirmDeleteTrip(context, ref, trip),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Delete Trip'),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDeleteTrip(
  BuildContext context,
  WidgetRef ref,
  TripSessionModel trip,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete trip?'),
      content: Text(
        'This will delete "${trip.tripName}", its saved channel, members, cached messages, voice notes, SOS, and location history from this phone. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(tripContextServiceProvider).deleteTrip(trip.tripId);
    ref.invalidate(activeTripContextProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${trip.tripName} deleted.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<P2PSessionSwitchAction> _resolveTripSwitchAction(
  BuildContext context,
  WidgetRef ref,
  TripSessionModel trip, {
  required bool allowCreateInactive,
}) async {
  final session = await ref.read(p2pSessionServiceProvider).getActiveSession();
  if (session == null ||
      !session.blocksTripSwitch ||
      session.tripId == trip.tripId) {
    return P2PSessionSwitchAction.disconnectAndSwitch;
  }
  if (!context.mounted) return P2PSessionSwitchAction.cancel;
  return showP2PSessionSwitchDialog(
    context: context,
    currentTripName: session.channelCode,
    newTripName: trip.tripName,
    allowCreateInactive: allowCreateInactive,
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.mutedText.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? AppColors.success : AppColors.mutedText,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyTripsState extends StatelessWidget {
  const _EmptyTripsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No trips found. Start or join a trip to create an active channel.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Future<(int, int)> _rosterCounts(WidgetRef ref, String tripId) async {
  final repository = ref.read(tripMemberDeviceRosterRepositoryProvider);
  final members = await repository.countMembers(tripId);
  final devices = await repository.countDevices(tripId);
  return (members, devices);
}
