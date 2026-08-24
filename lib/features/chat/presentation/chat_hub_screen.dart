import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
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
  late _MessageTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = _tabFromInitial(widget.initialTab);
  }

  @override
  void didUpdateWidget(covariant ChatHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab == widget.initialTab) return;
    setState(() {
      _selectedTab = _tabFromInitial(widget.initialTab);
    });
  }

  @override
  Widget build(BuildContext context) {
    final modeState = ref.watch(modeStateProvider);
    final scope = _scopeForMode(modeState.effectiveMode);
    final tabs = _tabsForScope(scope);
    final selectedTab = tabs.contains(_selectedTab) ? _selectedTab : tabs.first;
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
                          scope: scope,
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
                                onPressed: () => _openCreateForScope(scope),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openJoinForScope(scope),
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Join'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SegmentedTabs(
                          tabs: tabs,
                          selectedTab: selectedTab,
                          onChanged: (tab) =>
                              setState(() => _selectedTab = tab),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: switch (selectedTab) {
                            _MessageTab.cloud =>
                              _CloudGroupsPane(groupsState: groupsState),
                            _MessageTab.offline => _OfflineChannelsPane(
                                channelsValue: channelsValue,
                                activeTrip: trip,
                              ),
                            _MessageTab.recent => const _RecentPane(),
                          },
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _openCreateForScope(_MessageScope scope) {
    if (scope == _MessageScope.offline) {
      context.go('/offline-channel/create');
      return;
    }
    context.go('/groups/create');
  }

  void _openJoinForScope(_MessageScope scope) {
    if (scope == _MessageScope.offline) {
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

enum _MessageScope { online, offline }

enum _MessageTab { cloud, offline, recent }

_MessageScope _scopeForMode(EffectiveMode mode) {
  return mode == EffectiveMode.online
      ? _MessageScope.online
      : _MessageScope.offline;
}

_MessageTab _tabFromInitial(String? value) {
  return switch (value) {
    'offline' => _MessageTab.offline,
    'recent' => _MessageTab.recent,
    _ => _MessageTab.cloud,
  };
}

List<_MessageTab> _tabsForScope(_MessageScope scope) {
  return scope == _MessageScope.online
      ? const [_MessageTab.cloud, _MessageTab.recent]
      : const [_MessageTab.offline, _MessageTab.recent];
}

String _labelForTab(_MessageTab tab) {
  return switch (tab) {
    _MessageTab.cloud => 'Online Groups',
    _MessageTab.offline => 'Offline Chats',
    _MessageTab.recent => 'Recent',
  };
}

class _TripMessageShortcuts extends StatelessWidget {
  const _TripMessageShortcuts({
    required this.trip,
    required this.channel,
    required this.scope,
    this.chatId,
  });

  final TripSessionModel trip;
  final OfflineChannelModel? channel;
  final _MessageScope scope;
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
              trip.isOffline ? 'Offline trip' : 'Online trip',
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
            if (scope == _MessageScope.online && trip.cloudGroupId != null)
              _ShortcutButton(
                label: 'Online Chat',
                icon: Icons.cloud_done_rounded,
                onTap: () => context.go('/groups/${trip.cloudGroupId}/chat'),
              ),
            if (scope == _MessageScope.offline && offline && channel != null)
              _ShortcutButton(
                label: 'Nearby Chat',
                icon: Icons.hub_rounded,
                onTap: () => _openOfflineChat(context, trip, channel!, chatId),
              ),
            if (scope == _MessageScope.offline &&
                trip.isOffline &&
                channel != null) ...[
              _ShortcutButton(
                label: 'Connect Phones',
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
    required this.tabs,
    required this.selectedTab,
    required this.onChanged,
  });

  final List<_MessageTab> tabs;
  final _MessageTab selectedTab;
  final ValueChanged<_MessageTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          for (final tab in tabs)
            Expanded(
              child: _SegmentButton(
                label: _labelForTab(tab),
                selected: selectedTab == tab,
                onTap: () => onChanged(tab),
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
  const _OfflineChannelsPane({
    required this.channelsValue,
    required this.activeTrip,
  });

  final AsyncValue<List<OfflineChannelModel>> channelsValue;
  final TripSessionModel? activeTrip;

  @override
  Widget build(BuildContext context) {
    return channelsValue.when(
      data: (channels) {
        final visibleChannels = _channelsForActiveOfflineTrip(channels);
        if (visibleChannels.isEmpty) {
          return const _EmptyMessagesState(
            key: ValueKey('offline-empty'),
            icon: Icons.hub_rounded,
            title: 'No offline chat ready',
            message: 'Create or join an offline trip before entering remote areas.',
          );
        }
        return Column(
          key: const ValueKey('offline-channels'),
          children: visibleChannels
              .map(
                (channel) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfflineChannelTile(
                    channel: channel,
                    activeTrip: activeTrip,
                  ),
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

  List<OfflineChannelModel> _channelsForActiveOfflineTrip(
    List<OfflineChannelModel> channels,
  ) {
    final trip = activeTrip;
    if (trip == null || trip.mode != 'offline') return const [];
    final activeChannelId = trip.activeChannelId ?? trip.offlineChannelId;
    return channels.where((channel) {
      final matchesTrip = channel.tripId == trip.tripId;
      final matchesChannel =
          activeChannelId != null && channel.channelId == activeChannelId;
      final matchesCode = channel.channelCode == trip.channelCode;
      return matchesTrip || matchesChannel || matchesCode;
    }).toList();
  }
}

class _OfflineChannelTile extends StatelessWidget {
  const _OfflineChannelTile({
    required this.channel,
    required this.activeTrip,
  });

  final OfflineChannelModel channel;
  final TripSessionModel? activeTrip;

  @override
  Widget build(BuildContext context) {
    final title = _displayTitle;
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
                      title,
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

  String get _displayTitle {
    final trip = activeTrip;
    if (trip == null || trip.mode != 'offline') return channel.channelName;
    final activeChannelId = trip.activeChannelId ?? trip.offlineChannelId;
    final isActiveTripChannel = channel.tripId == trip.tripId ||
        (activeChannelId != null && channel.channelId == activeChannelId) ||
        channel.channelCode == trip.channelCode;
    if (!isActiveTripChannel || trip.tripName.trim().isEmpty) {
      return channel.channelName;
    }
    return trip.tripName;
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
