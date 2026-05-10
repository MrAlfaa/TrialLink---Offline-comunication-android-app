import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../trip/data/trip_session_model.dart';
import '../data/trip_context_service.dart';

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
                  'Channel: ${trip.channelCode}',
              ].join('  |  '),
              style: Theme.of(context).textTheme.bodySmall,
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
                  return const Text('No offline channels linked yet.');
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
                          await service.archiveTrip(trip.tripId);
                          ref.invalidate(activeTripContextProvider);
                        },
                  icon: const Icon(Icons.archive_rounded),
                  label: const Text('Archive'),
                ),
                TextButton.icon(
                  onPressed: () => _showCreateChannelDialog(context, ref, trip),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add channel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
        active ? 'Active' : label,
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

Future<void> _showCreateChannelDialog(
  BuildContext context,
  WidgetRef ref,
  TripSessionModel trip,
) async {
  final nameController = TextEditingController(text: '${trip.tripName} Backup');
  final codeController = TextEditingController();
  final service = ref.read(tripContextServiceProvider);
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Create channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Channel name'),
            ),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Custom code',
                hintText: 'Optional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await service.createChannelUnderTrip(
                tripId: trip.tripId,
                channelName: name,
                customCode: codeController.text.trim().isEmpty
                    ? null
                    : codeController.text.trim(),
              );
              ref.invalidate(activeTripContextProvider);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
  nameController.dispose();
  codeController.dispose();
}
