import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../trip_context/data/trip_context_service.dart';
import '../data/models/offline_channel_member_model.dart';
import '../data/models/offline_channel_model.dart';
import 'offline_channel_controller.dart';
import 'widgets/channel_code_box.dart';
import 'widgets/local_member_tile.dart';

class OfflineChannelDetailsScreen extends ConsumerWidget {
  const OfflineChannelDetailsScreen({
    required this.channelId,
    super.key,
  });

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelValue = ref.watch(offlineChannelDetailsProvider(channelId));
    final membersValue = ref.watch(offlineChannelMembersProvider(channelId));
    final mutation = ref.watch(offlineChannelControllerProvider);
    final controller = ref.read(offlineChannelControllerProvider.notifier);
    final user = ref.watch(authControllerProvider).user;
    final actor = _actorFor(user, ref.watch(authAccessControllerProvider));
    final activeContext = ref.watch(activeTripContextProvider).asData?.value;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offline Channel'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Nearby Members'),
              Tab(text: 'Channel Info'),
              Tab(text: 'Queue / Packets'),
            ],
          ),
        ),
        body: SafeArea(
          child: channelValue.when(
            data: (channel) {
              if (channel == null) {
                return const Center(child: Text('Offline channel not found.'));
              }
              return membersValue.when(
                data: (members) {
                  final connected = members
                      .where((member) => member.presenceStatus == 'connected')
                      .length;
                  final lastActivity = members
                      .map((member) => member.lastSeenAt)
                      .whereType<DateTime>()
                      .fold<DateTime?>(null, (latest, item) {
                    if (latest == null || item.isAfter(latest)) return item;
                    return latest;
                  });
                  return TabBarView(
                    children: [
                      _OverviewTab(
                        channelId: channel.channelId,
                        channelName: channel.channelName,
                        channelCode: channel.channelCode,
                        isActive: channel.isActive,
                        isEnded: channel.isEnded,
                        connectedCount: connected,
                        lastActivity: lastActivity ?? channel.lastOpenedAt,
                        isOwner: actor != null &&
                            _isChannelOwner(channel.createdByUserId, actor),
                        onSetActive: channel.isActive
                            ? null
                            : () async {
                                await controller
                                    .setActiveChannel(channel.channelId);
                                ref
                                  ..invalidate(offlineChannelListProvider)
                                  ..invalidate(activeOfflineChannelProvider)
                                  ..invalidate(
                                      activeUsableOfflineChannelProvider)
                                  ..invalidate(activeTripChannelProvider)
                                  ..invalidate(activeTripContextProvider)
                                  ..invalidate(
                                    offlineChannelDetailsProvider(channelId),
                                  );
                              },
                        onSetInactive: channel.isEnded
                            ? null
                            : () async {
                                await controller
                                    .setInactiveChannel(channel.channelId);
                                ref
                                  ..invalidate(offlineChannelListProvider)
                                  ..invalidate(activeOfflineChannelProvider)
                                  ..invalidate(
                                      activeUsableOfflineChannelProvider)
                                  ..invalidate(activeTripChannelProvider)
                                  ..invalidate(activeTripContextProvider)
                                  ..invalidate(
                                    offlineChannelDetailsProvider(channelId),
                                  );
                              },
                        onEnd: actor == null || channel.isEnded
                            ? null
                            : () => _confirmEndChannel(context, ref, channel),
                        activeTripId: activeContext?.activeChannel?.channelId ==
                                channel.channelId
                            ? activeContext?.trip.tripId
                            : null,
                        activeChatId: activeContext?.activeChannel?.channelId ==
                                channel.channelId
                            ? activeContext?.activeChat?.chatId
                            : null,
                      ),
                      _MembersTab(members: members),
                      _InfoTab(
                        channelName: channel.channelName,
                        channelCode: channel.channelCode,
                        createdByName: channel.createdByName,
                        description: channel.description,
                        isBusy: mutation.isLoading,
                        onLeave: () => _confirmLeaveChannel(context, ref),
                      ),
                      _PacketsTab(
                        mutation: mutation,
                        onRunPacketFilter: () => controller.runPacketFilterTest(
                          channel: channel,
                          user: user,
                        ),
                      ),
                    ],
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
      ),
    );
  }

  Future<void> _confirmEndChannel(
    BuildContext context,
    WidgetRef ref,
    OfflineChannelModel channel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End offline channel?'),
        content: const Text(
          'Connected teammates will see this channel as ended and read-only. Chat history stays on each device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Channel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final user = ref.read(authControllerProvider).user;
    await ref.read(offlineChannelControllerProvider.notifier).endChannel(
          channel: channel,
          user: user,
          reason: 'Channel ended by owner.',
        );
    ref
      ..invalidate(offlineChannelListProvider)
      ..invalidate(activeOfflineChannelProvider)
      ..invalidate(activeUsableOfflineChannelProvider)
      ..invalidate(activeTripChannelProvider)
      ..invalidate(activeTripContextProvider)
      ..invalidate(offlineChannelDetailsProvider(channelId));
  }

  Future<void> _confirmLeaveChannel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave offline channel?'),
        content: const Text(
          'Your membership will be marked left and the active channel will be cleared. Historical messages stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave Channel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(offlineChannelControllerProvider.notifier)
        .leaveChannel(channelId);
    ref
      ..invalidate(offlineChannelListProvider)
      ..invalidate(activeOfflineChannelProvider)
      ..invalidate(activeUsableOfflineChannelProvider)
      ..invalidate(activeTripChannelProvider)
      ..invalidate(activeTripContextProvider)
      ..invalidate(offlineChannelMembersProvider(channelId));
    if (context.mounted) context.go('/offline-channel');
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.channelId,
    required this.channelName,
    required this.channelCode,
    required this.isActive,
    required this.isEnded,
    required this.connectedCount,
    required this.lastActivity,
    required this.isOwner,
    required this.onSetActive,
    required this.onSetInactive,
    required this.onEnd,
    this.activeTripId,
    this.activeChatId,
  });

  final String channelId;
  final String channelName;
  final String channelCode;
  final bool isActive;
  final bool isEnded;
  final int connectedCount;
  final DateTime? lastActivity;
  final bool isOwner;
  final VoidCallback? onSetActive;
  final VoidCallback? onSetInactive;
  final VoidCallback? onEnd;
  final String? activeTripId;
  final String? activeChatId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        channelName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    CompactStatusChip(
                      label: isEnded
                          ? 'Ended'
                          : isActive
                              ? 'Active'
                              : 'Inactive',
                      color: isEnded
                          ? AppColors.danger
                          : isActive
                              ? AppColors.success
                              : AppColors.mutedText,
                      icon: isEnded
                          ? Icons.lock_clock_rounded
                          : isActive
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ChannelCodeBox(channelCode: channelCode),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CompactStatusChip(
                      label: '$connectedCount connected',
                      color: AppColors.offlinePurple,
                      icon: Icons.bluetooth_connected_rounded,
                    ),
                    CompactStatusChip(
                      label: _activityLabel(lastActivity),
                      color: AppColors.skyBlue,
                      icon: Icons.history_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isEnded) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: const Text(
                      'This channel has ended. Chat history is read-only and sending is disabled.',
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                FilledButton.icon(
                  onPressed: isEnded ? null : () => _openChat(context),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Open Offline Chat'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isEnded ? null : onSetActive,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Set as Active Channel'),
                ),
                if (isOwner) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: isEnded ? null : onSetInactive,
                    icon: const Icon(Icons.pause_circle_rounded),
                    label: const Text('Set Inactive'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: onEnd,
                    icon: const Icon(Icons.archive_rounded),
                    label: const Text('End Channel'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isEnded ? null : () => context.go('/nearby-peers'),
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Start / Stop Discovery'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _activityLabel(DateTime? lastActivity) {
    if (lastActivity == null) return 'No activity';
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  void _openChat(BuildContext context) {
    if (activeTripId != null &&
        activeTripId!.isNotEmpty &&
        activeChatId != null &&
        activeChatId!.isNotEmpty) {
      context.go(
        '/trips/$activeTripId/channels/$channelId/chats/$activeChatId',
      );
      return;
    }
    context.go('/offline-channel/$channelId/chat');
  }
}

CurrentUserActor? _actorFor(user, AuthAccessStatus access) {
  try {
    return CurrentUserActor.fromAuthAccess(access);
  } catch (_) {
    return user == null ? null : CurrentUserActor.fromUserModel(user);
  }
}

bool _isChannelOwner(String createdByUserId, CurrentUserActor actor) {
  return createdByUserId == actor.localUserId ||
      createdByUserId == actor.backendUserId ||
      createdByUserId == actor.id;
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.members});

  final List<OfflineChannelMemberModel> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No local channel members yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: LocalMemberTile(member: members[index]),
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.channelName,
    required this.channelCode,
    required this.createdByName,
    required this.description,
    required this.isBusy,
    required this.onLeave,
  });

  final String channelName;
  final String channelCode;
  final String? createdByName;
  final String? description;
  final bool isBusy;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channelName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description?.isNotEmpty == true
                    ? description!
                    : 'Local offline channel for nearby communication.'),
                const SizedBox(height: 14),
                ChannelCodeBox(channelCode: channelCode),
                const SizedBox(height: 14),
                Text('Creator: ${createdByName ?? 'Unknown'}'),
                const SizedBox(height: 8),
                const Text(
                  'Offline membership is local and presence is best-effort. Disconnected members stay listed with their last-seen state.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: isBusy ? null : onLeave,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Leave Channel'),
        ),
      ],
    );
  }
}

class _PacketsTab extends StatelessWidget {
  const _PacketsTab({
    required this.mutation,
    required this.onRunPacketFilter,
  });

  final OfflineChannelMutationState mutation;
  final VoidCallback onRunPacketFilter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Packet Filtering',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'TrailLink processes offline packets only when they match this channel code and pass TTL, hop count, and duplicate checks.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: mutation.isLoading ? null : onRunPacketFilter,
                  icon: const Icon(Icons.science_rounded),
                  label: const Text('Run Packet Filter Test'),
                ),
                if (mutation.packetFilterResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...mutation.packetFilterResults.map(
                    (result) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(result),
                    ),
                  ),
                ],
                if (mutation.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    mutation.errorMessage!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
