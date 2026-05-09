import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import 'group_controller.dart';
import 'widgets/group_card.dart';

class GroupsDashboardScreen extends ConsumerWidget {
  const GroupsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(myGroupsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Groups')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(myGroupsControllerProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Hiking and camping groups',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a group for your trip or join a team using a TrailLink group code.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Create',
                      icon: Icons.add_rounded,
                      onPressed: () => context.go('/groups/create'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Join',
                      icon: Icons.login_rounded,
                      onPressed: () => context.go('/groups/join'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (groupsState.isRefreshing && groupsState.groups.isNotEmpty)
                const _LatestKnownBanner(),
              if (groupsState.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (groupsState.groups.isEmpty &&
                  groupsState.errorMessage != null)
                _ErrorState(
                  message: groupsState.errorMessage!,
                  onRetry: () =>
                      ref.read(myGroupsControllerProvider.notifier).load(),
                )
              else if (groupsState.groups.isEmpty)
                const _EmptyGroupsState()
              else
                Column(
                  children: groupsState.groups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GroupCard(
                            group: group,
                            onTap: () => context.go('/groups/${group.id}'),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestKnownBanner extends StatelessWidget {
  const _LatestKnownBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.skyBlueSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.history_rounded, color: AppColors.skyBlue),
          SizedBox(width: 10),
          Expanded(
            child:
                Text('Latest known data. Refreshing when cloud is available.'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.signalOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                color: AppColors.signalOrange,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No groups yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first outdoor group or join one with a group code.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
