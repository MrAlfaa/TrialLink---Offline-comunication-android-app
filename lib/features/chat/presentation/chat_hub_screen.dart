import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../groups/data/models/group_model.dart';
import '../../groups/presentation/group_controller.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import '../../trip/data/trip_session_model.dart';
import '../../trip/data/trip_session_service.dart';
import '../../trip_context/data/trip_context_service.dart';

class ChatHubScreen extends ConsumerStatefulWidget {
  const ChatHubScreen({
    this.initialTab,
    super.key,
  });

  final String? initialTab;

  @override
  ConsumerState<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends ConsumerState<ChatHubScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = switch (widget.initialTab) {
      'offline' => 1,
      'recent' => 2,
      _ => 0,
    };
  }

  @override
  void didUpdateWidget(covariant ChatHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    setState(() {
      _selectedIndex = switch (widget.initialTab) {
        'offline' => 1,
        'recent' => 2,
        _ => 0,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripProvider);
    final activeContext = ref.watch(activeTripContextProvider).asData?.value;
    final trip = activeTrip.asData?.value;
    final groupsState = ref.watch(myGroupsControllerProvider);
    final channelsValue = ref.watch(offlineChannelListProvider);
    final activeTripChannel = ref.watch(activeTripChannelProvider);
    final activeUsableChannel = ref.watch(activeUsableOfflineChannelProvider);
    final channel =
        activeTripChannel.asData?.value ?? activeUsableChannel.asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: SafeArea(
        child: activeTrip.isLoading
            ? const Center(child: CircularProgressIndicator())
            : trip == null
                ? const _NoTripMessagesPrompt()
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(myGroupsControllerProvider.notifier)
                          .load();
                      ref.invalidate(offlineChannelListProvider);
                      ref.invalidate(activeTripChannelProvider);
                      ref.invalidate(activeUsableOfflineChannelProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 112),
                      children: [
                        _TripMessageShortcuts(
                          trip: trip,
                          channel: channel,
                          chatId: activeContext?.activeChat?.chatId,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Create a group or join a team using a TrailLink code.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.mutedText,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _openCreate,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openJoin,
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Join'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SegmentedTabs(
                          selectedIndex: _selectedIndex,
                          onChanged: (index) =>
                              setState(() => _selectedIndex = index),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: switch (_selectedIndex) {
                            0 => _CloudGroupsPane(groupsState: groupsState),
                            1 => _OfflineChannelsPane(
                                channelsValue: channelsValue),
                            _ => const _RecentPane(),
                          },
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _openCreate() {
    if (_selectedIndex == 1) {
      context.go('/offline-channel/create');
      return;
    }
    context.go('/groups/create');
  }

  void _openJoin() {
    if (_selectedIndex == 1) {
      context.go('/offline-channel/join');
      return;
    }
    context.go('/groups/join');
  }
}

class _NoTripMessagesPrompt extends StatelessWidget {
  const _NoTripMessagesPrompt();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create or join a trip first',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Messages are available after your trip is ready.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/trip/setup-wizard'),
                        icon: const Icon(Icons.add_road_rounded),
                        label: const Text('Start Trip'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.go('/trip/setup-wizard?intent=join'),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Join Trip'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TripMessageShortcuts extends StatelessWidget {
  const _TripMessageShortcuts({
    required this.trip,
    required this.channel,
    this.chatId,
  });

  final TripSessionModel trip;
  final OfflineChannelModel? channel;
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    final hybrid = trip.mode == 'hybrid';
    final offline = trip.isOffline || hybrid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.tripName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              hybrid
                  ? 'Cloud + Offline Backup'
                  : trip.isOffline
                      ? 'Offline Only'
                      : 'Cloud Trip',
            ),
            if (trip.channelCode?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                trip.channelCode!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.offlinePurple,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            if (trip.cloudGroupId != null)
              _ShortcutButton(
                label: 'Cloud Chat',
                icon: Icons.cloud_done_rounded,
                onTap: () => context.go('/groups/${trip.cloudGroupId}/chat'),
              ),
            if (offline && channel != null)
              _ShortcutButton(
                label: 'Offline Channel Chat',
                icon: Icons.hub_rounded,
                onTap: () => _openOfflineChat(context, trip, channel!, chatId),
              ),
            if (trip.isOffline && channel != null) ...[
              _ShortcutButton(
                label: 'Nearby Peers',
                icon: Icons.people_alt_rounded,
                onTap: () => context.go('/nearby-peers'),
              ),
              _ShortcutButton(
                label: 'Channel Details',
                icon: Icons.info_outline_rounded,
                onTap: () => _openOfflineDetails(context, channel!),
              ),
            ],
            const _ShortcutButton(
              label: 'Recent Messages',
              icon: Icons.history_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

void _openOfflineChat(
  BuildContext context,
  TripSessionModel trip,
  OfflineChannelModel channel,
  String? chatId,
) {
  if (chatId != null && chatId.isNotEmpty) {
    context.go(
        '/trips/${trip.tripId}/channels/${channel.channelId}/chats/$chatId');
    return;
  }
  context.go('/offline-channel/${channel.channelId}/chat');
}

void _openOfflineDetails(BuildContext context, OfflineChannelModel channel) {
  context.go('/offline-channel/${channel.channelId}');
}

class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tileColor: AppColors.surface,
        leading: Icon(icon, color: AppColors.deepForest),
        title: Text(label),
        trailing:
            onTap == null ? null : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Cloud Groups', 'Offline Channels', 'Recent'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _SegmentButton(
                label: labels[i],
                selected: selectedIndex == i,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.deepForest : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : AppColors.mutedText,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _CloudGroupsPane extends StatelessWidget {
  const _CloudGroupsPane({required this.groupsState});

  final MyGroupsState groupsState;

  @override
  Widget build(BuildContext context) {
    if (groupsState.isLoading) {
      return const Center(
        key: ValueKey('cloud-loading'),
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (groupsState.groups.isEmpty) {
      return const _EmptyMessagesState(
        key: ValueKey('cloud-empty'),
        icon: Icons.groups_2_rounded,
        title: 'No cloud groups yet',
        message: 'Create or join a group to start communicating.',
      );
    }

    return Column(
      key: const ValueKey('cloud-groups'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupsState.isLatestKnown || groupsState.errorMessage != null) ...[
          const CompactStatusChip(
            label: 'Latest known data',
            color: AppColors.skyBlue,
            icon: Icons.history_rounded,
          ),
          const SizedBox(height: 12),
        ],
        ...groupsState.groups.map(
          (group) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CloudGroupTile(group: group),
          ),
        ),
      ],
    );
  }
}

class _CloudGroupTile extends StatelessWidget {
  const _CloudGroupTile({required this.group});

  final GroupModel group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.deepForest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      color: AppColors.deepForest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          group.groupCode,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.deepForest,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CompactStatusChip(
                    label: group.memberRole ?? 'member',
                    color: AppColors.skyBlue,
                    dense: true,
                  ),
                  CompactStatusChip(
                    label: '${group.memberCount} members',
                    color: AppColors.deepForest,
                    dense: true,
                  ),
                  if (group.joinedAt != null)
                    const CompactStatusChip(
                      label: 'Active',
                      color: AppColors.success,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Last: latest known group activity',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineChannelsPane extends StatelessWidget {
  const _OfflineChannelsPane({required this.channelsValue});

  final AsyncValue<List<OfflineChannelModel>> channelsValue;

  @override
  Widget build(BuildContext context) {
    return channelsValue.when(
      data: (channels) {
        if (channels.isEmpty) {
          return const _EmptyMessagesState(
            key: ValueKey('offline-empty'),
            icon: Icons.hub_rounded,
            title: 'No offline channels yet',
            message: 'Create or join a channel before entering remote areas.',
          );
        }
        return Column(
          key: const ValueKey('offline-channels'),
          children: channels
              .map(
                (channel) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfflineChannelTile(channel: channel),
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(
        key: ValueKey('offline-loading'),
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => _EmptyMessagesState(
        key: const ValueKey('offline-error'),
        icon: Icons.error_outline_rounded,
        title: 'Offline channels unavailable',
        message: error.toString(),
      ),
    );
  }
}

class _OfflineChannelTile extends StatelessWidget {
  const _OfflineChannelTile({required this.channel});

  final OfflineChannelModel channel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/offline-channel/${channel.channelId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.offlinePurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: AppColors.offlinePurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.channelCode,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.offlinePurple,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CompactStatusChip(
                          label: channel.isActive ? 'Active' : 'Saved',
                          color: channel.isActive
                              ? AppColors.success
                              : AppColors.muted,
                          dense: true,
                        ),
                        const CompactStatusChip(
                          label: 'Nearby ready',
                          color: AppColors.offlinePurple,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPane extends StatelessWidget {
  const _RecentPane();

  @override
  Widget build(BuildContext context) {
    return const _EmptyMessagesState(
      key: ValueKey('recent-empty'),
      icon: Icons.history_rounded,
      title: 'No recent chats yet',
      message: 'Recent cloud and offline conversations will appear here.',
    );
  }
}

class _EmptyMessagesState extends StatelessWidget {
  const _EmptyMessagesState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.deepForest.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: AppColors.deepForest, size: 34),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
