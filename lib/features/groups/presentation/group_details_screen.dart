import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/models/group_member_model.dart';
import 'create_group_screen.dart';
import 'group_controller.dart';
import 'group_member_permissions.dart';

class GroupDetailsScreen extends ConsumerWidget {
  const GroupDetailsScreen({
    required this.groupId,
    super.key,
  });

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupValue = ref.watch(groupDetailsProvider(groupId));
    final membersValue = ref.watch(groupMembersProvider(groupId));
    final mutation = ref.watch(groupMutationControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final mode = ref.watch(modeStateProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Group Details'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Members'),
              Tab(text: 'Media'),
              Tab(text: 'Info'),
            ],
          ),
        ),
        body: SafeArea(
          child: groupValue.when(
            data: (group) => TabBarView(
              children: [
                _OverviewTab(
                  groupId: groupId,
                  groupName: group.groupName,
                  groupCode: group.groupCode,
                  memberCount: group.memberCount,
                  memberRole: group.memberRole ?? 'member',
                  description: group.description,
                  status: group.status,
                  mode: mode.effectiveMode,
                ),
                membersValue.when(
                  data: (members) => _MembersTab(
                    members: members,
                    requesterRole: group.memberRole,
                    requesterUserId: user?.id,
                    isBusy: mutation.isLoading,
                    onRemove: (member) =>
                        _confirmRemoveMember(context, ref, member),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => _ErrorState(error: error),
                ),
                _MediaTab(mode: mode.effectiveMode),
                _InfoTab(
                  groupId: groupId,
                  groupName: group.groupName,
                  groupCode: group.groupCode,
                  description: group.description,
                  memberRole: group.memberRole ?? 'member',
                  status: group.status,
                  isBusy: mutation.isLoading,
                  onLeave: () => _confirmLeaveGroup(context, ref),
                  onArchive: () => _confirmArchiveGroup(context, ref),
                ),
              ],
            ),
            error: (error, stackTrace) => _ErrorState(error: error),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchiveGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End cloud group?'),
        content: const Text(
          'Members will lose cloud access to this group. Cached chat history remains read-only on devices that already have it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Group'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(groupMutationControllerProvider.notifier)
        .archiveGroup(groupId);
    ref
      ..invalidate(myGroupsControllerProvider)
      ..invalidate(groupDetailsProvider(groupId))
      ..invalidate(groupMembersProvider(groupId));
    if (!context.mounted) return;
    if (ok) {
      context.go('/chat?tab=cloud');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(groupMutationControllerProvider).errorMessage ??
                'Could not end group.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref,
    GroupMemberModel member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          '${member.fullName} will lose access to this cloud group and its chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok =
        await ref.read(groupMutationControllerProvider.notifier).removeMember(
              groupId: groupId,
              member: member,
            );
    ref.invalidate(groupMembersProvider(groupId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '${member.fullName} removed from group.'
              : ref.read(groupMutationControllerProvider).errorMessage ??
                  'Could not remove member.',
        ),
      ),
    );
  }

  Future<void> _confirmLeaveGroup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
          'You will lose cloud chat access for this group. Cached latest-known data remains on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave Group'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref
        .read(groupMutationControllerProvider.notifier)
        .leaveGroup(groupId);
    ref
      ..invalidate(myGroupsControllerProvider)
      ..invalidate(groupDetailsProvider(groupId))
      ..invalidate(groupMembersProvider(groupId));
    if (!context.mounted) return;
    if (ok) {
      context.go('/chat?tab=cloud');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(groupMutationControllerProvider).errorMessage ??
                'Could not leave group.',
          ),
        ),
      );
    }
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.memberCount,
    required this.memberRole,
    required this.description,
    required this.status,
    required this.mode,
  });

  final String groupId;
  final String groupName;
  final String groupCode;
  final int memberCount;
  final String memberRole;
  final String description;
  final String status;
  final EffectiveMode mode;

  @override
  Widget build(BuildContext context) {
    final isArchived = status == 'archived';
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(groupName,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CompactStatusChip(
                      label: groupCode,
                      color: AppColors.deepForest,
                      icon: Icons.tag_rounded,
                    ),
                    CompactStatusChip(
                      label: '$memberCount members',
                      color: AppColors.skyBlue,
                      icon: Icons.people_alt_rounded,
                    ),
                    CompactStatusChip(
                      label: memberRole,
                      color: AppColors.success,
                      icon: Icons.verified_user_rounded,
                    ),
                    CompactStatusChip(
                      label: isArchived ? 'Ended' : 'Active',
                      color: isArchived ? AppColors.danger : AppColors.success,
                      icon: isArchived
                          ? Icons.archive_rounded
                          : Icons.check_circle_rounded,
                    ),
                    CompactStatusChip(
                      label: mode == EffectiveMode.online
                          ? 'Online'
                          : 'Latest known',
                      color: mode == EffectiveMode.online
                          ? AppColors.success
                          : AppColors.offlinePurple,
                      icon: mode == EffectiveMode.online
                          ? Icons.cloud_done_rounded
                          : Icons.save_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isArchived) ...[
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: const Text(
                      'This group has ended. Cached chat history is read-only.',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  description.isEmpty
                      ? 'No description provided.'
                      : description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.deepForest.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          groupCode,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: AppColors.deepForest),
                        ),
                      ),
                      GroupCodeCopyButton(groupCode: groupCode),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: isArchived
                      ? null
                      : () => context.go(
                            '/groups/$groupId/chat',
                            extra: {'groupName': groupName},
                          ),
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('Open Chat'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SectionHeader(
          title: 'Group Tools',
          subtitle: 'Cloud tools use latest-known cached data while offline.',
        ),
        const SizedBox(height: 12),
        _DetailsActionTile(
          title: 'Map / Locations',
          subtitle: 'Open group map and teammate locations',
          icon: Icons.map_rounded,
          color: AppColors.success,
          onTap: () => context.go('/groups/$groupId/map'),
        ),
        _DetailsActionTile(
          title: 'Emergency SOS',
          subtitle: 'Send or review group emergency actions',
          icon: Icons.emergency_share_rounded,
          color: AppColors.danger,
          onTap: () => context.go('/groups/$groupId/sos'),
        ),
        _DetailsActionTile(
          title: 'Walkie-Talkie / PTT',
          subtitle: 'Voice-note push-to-talk clips',
          icon: Icons.record_voice_over_rounded,
          color: AppColors.signalOrange,
          onTap: () => context.go('/groups/$groupId/ptt'),
        ),
      ],
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.members,
    required this.requesterRole,
    required this.requesterUserId,
    required this.isBusy,
    required this.onRemove,
  });

  final List<GroupMemberModel> members;
  final String? requesterRole;
  final String? requesterUserId;
  final bool isBusy;
  final ValueChanged<GroupMemberModel> onRemove;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(child: Text('No cached group members yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final member = members[index];
        final canRemove = GroupMemberPermissions.canRemoveMember(
          requesterRole: requesterRole,
          requesterUserId: requesterUserId,
          member: member,
        );
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.skyBlue.withValues(alpha: 0.14),
              child: Text(
                _initials(member.fullName),
                style: const TextStyle(
                  color: AppColors.skyBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            title: Text(
                member.fullName.isEmpty ? 'TrailLink User' : member.fullName),
            subtitle: Text(_memberSubtitle(member)),
            trailing: canRemove
                ? PopupMenuButton<String>(
                    enabled: !isBusy,
                    onSelected: (value) {
                      if (value == 'remove') onRemove(member);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove member'),
                      ),
                    ],
                  )
                : CompactStatusChip(
                    label: member.memberRole,
                    color: _roleColor(member.memberRole),
                    dense: true,
                  ),
          ),
        );
      },
    );
  }

  String _memberSubtitle(GroupMemberModel member) {
    final presence = switch (member.presenceStatus) {
      'online' => 'Online',
      'nearby' => 'Nearby',
      'disconnected' => 'Disconnected',
      'offline' => 'Offline',
      _ => 'Unknown presence',
    };
    return '${member.memberRole} - ${member.membershipStatus} - $presence';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'TL';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Color _roleColor(String role) {
    return switch (role) {
      'owner' => AppColors.signalOrange,
      'admin' => AppColors.skyBlue,
      _ => AppColors.deepForest,
    };
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.mode});

  final EffectiveMode mode;

  @override
  Widget build(BuildContext context) {
    final isOnline = mode == EffectiveMode.online;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isOnline
                      ? Icons.photo_library_rounded
                      : Icons.cloud_off_rounded,
                  color: isOnline ? AppColors.success : AppColors.offlinePurple,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  isOnline ? 'Media' : 'Media is online-only',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  isOnline
                      ? 'Media sharing will appear here when group uploads are available.'
                      : 'Media sharing is online-only to avoid heavy offline transfer. Use text, SOS, location, or voice-note PTT while offline.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({
    required this.groupId,
    required this.groupName,
    required this.groupCode,
    required this.description,
    required this.memberRole,
    required this.status,
    required this.isBusy,
    required this.onLeave,
    required this.onArchive,
  });

  final String groupId;
  final String groupName;
  final String groupCode;
  final String description;
  final String memberRole;
  final String status;
  final bool isBusy;
  final VoidCallback onLeave;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final isOwner = memberRole == 'owner';
    final isArchived = status == 'archived';
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 112),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(groupName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(description.isEmpty
                    ? 'No description provided.'
                    : description),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text('Code: $groupCode')),
                    GroupCodeCopyButton(groupCode: groupCode),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Your role: $memberRole'),
                const SizedBox(height: 8),
                Text(isArchived
                    ? 'Status: Ended. Cached data is read-only.'
                    : 'Status: Latest known data is available offline.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (isOwner && !isArchived) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: isBusy ? null : onArchive,
            icon: const Icon(Icons.archive_rounded),
            label: const Text('End Group'),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: isBusy ? null : onLeave,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Leave Group'),
        ),
      ],
    );
  }
}

class _DetailsActionTile extends StatelessWidget {
  const _DetailsActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(error.toString()));
  }
}
