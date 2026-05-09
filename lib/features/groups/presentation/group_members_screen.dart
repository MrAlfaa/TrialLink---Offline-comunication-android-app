import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_controller.dart';
import 'widgets/member_tile.dart';

class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({
    required this.groupId,
    super.key,
  });

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersValue = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('Group Members')),
      body: SafeArea(
        child: membersValue.when(
          data: (members) => RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(groupMembersProvider(groupId).future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: members
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MemberTile(member: member),
                    ),
                  )
                  .toList(),
            ),
          ),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
