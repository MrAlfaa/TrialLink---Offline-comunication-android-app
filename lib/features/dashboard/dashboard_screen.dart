import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connection_mode_provider.dart';
import '../../core/config/offline_text_only_flags.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/identity/auth_access_controller.dart';
import '../../core/identity/auth_access_state.dart';
import '../../core/mode/mode_controller.dart';
import '../../core/mode/mode_models.dart';
import '../../core/settings/feature_flag_service.dart';
import '../../core/settings/settings_service.dart';
import '../../shared/widgets/compact_status_chip.dart';
import '../app_lock/presentation/app_lock_controller.dart';
import '../auth/presentation/auth_controller.dart';
import '../groups/data/models/group_model.dart';
import '../groups/presentation/group_controller.dart';
import '../offline_channel/data/models/offline_channel_model.dart';
import '../offline_channel/presentation/offline_channel_controller.dart';
import '../trip/data/trip_session_model.dart';
import '../trip/data/trip_session_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeState = ref.watch(modeControllerProvider);
    final groupsValue = ref.watch(myGroupsProvider);
    final activeChannel = ref.watch(activeUsableOfflineChannelProvider);
    final activeTripChannel = ref.watch(activeTripChannelProvider);
    final authState = ref.watch(authControllerProvider);
    final authAccess = ref.watch(authAccessControllerProvider);
    final activeTrip = ref.watch(activeTripProvider);
    final userName = authAccess.identity?.displayName ??
        authState.user?.fullName ??
        'Explorer';

    final groups = groupsValue.asData?.value ?? const <GroupModel>[];
    final channel =
        activeChannel.asData?.value ?? activeTripChannel.asData?.value;
    final trip = activeTrip.asData?.value;
    final modeColor = _modeColor(modeState);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: CompactStatusChip(
                label: _modeChipLabel(modeState),
                color: modeColor,
                icon: modeState.userMode.icon,
                dense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton(
            tooltip: 'Lock App',
            onPressed: () async {
              final appLockNotifier =
                  ref.read(appLockControllerProvider.notifier);
              if (!ref.read(appLockControllerProvider).isInitialized) {
                await appLockNotifier.initialize();
                if (!context.mounted) return;
              }
              final appLock = ref.read(appLockControllerProvider);
              if (!appLock.appLockEnabled || !appLock.pinConfigured) {
                context.go('/settings/app-lock/setup?next=/home');
                return;
              }
              await appLockNotifier.lockNow(intendedRoute: '/home');
              if (context.mounted) context.go('/unlock?from=/home');
            },
            icon: const Icon(Icons.lock_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myGroupsProvider);
            ref.invalidate(activeOfflineChannelProvider);
            ref.invalidate(activeUsableOfflineChannelProvider);
            ref.invalidate(activeTripChannelProvider);
            await ref.read(connectionModeProvider.notifier).checkNow();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 112),
            children: [
              if (trip == null)
                _NoActiveTripDashboard(userName: userName)
              else ...[
                _DashboardHeroCard(
                  userName: userName,
                  modeState: modeState,
                  trip: trip,
                  activeChannel: channel,
                  groups: groups,
                ),
                const SizedBox(height: 12),
                _StatusChipWrap(
                  modeState: modeState,
                  authState: authAccess.accessState,
                  trip: trip,
                ),
                const SizedBox(height: 22),
                _FeatureSection(
                  title: _dashboardKind(modeState) == _DashboardKind.online
                      ? 'Cloud Tools'
                      : 'Offline Tools',
                  subtitle: _dashboardKind(modeState) == _DashboardKind.online
                      ? 'Online group, map, and safety actions.'
                      : 'Nearby, local, and safety actions.',
                  actions: _actionsFor(
                    context: context,
                    kind: _dashboardKind(modeState),
                    groups: groups,
                    activeChannel: channel,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoActiveTripDashboard extends ConsumerStatefulWidget {
  const _NoActiveTripDashboard({required this.userName});

  final String userName;

  @override
  ConsumerState<_NoActiveTripDashboard> createState() =>
      _NoActiveTripDashboardState();
}

class _NoActiveTripDashboardState
    extends ConsumerState<_NoActiveTripDashboard> {
  bool _showCoachMark = false;

  @override
  void initState() {
    super.initState();
    _loadCoachMark();
  }

  Future<void> _loadCoachMark() async {
    final settings = ref.read(settingsServiceProvider);
    final seen = await settings.getBool('coach_marks_seen', false);
    if (!mounted) return;
    setState(() => _showCoachMark = !seen);
    if (!seen) await settings.setBool('coach_marks_seen', true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.deepForest,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepForest.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Active Trip',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome, ${widget.userName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start or join a trip to enable chat, SOS, map, nearby peers, and walkie-talkie tools.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go('/trip/setup-wizard'),
                      icon: const Icon(Icons.add_road_rounded),
                      label: const Text('Start Trip'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.deepForest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.go('/trip/setup-wizard?intent=join'),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Join Trip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => context.go('/help/how-it-works'),
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('How TrailLink Works'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        if (_showCoachMark) ...[
          const SizedBox(height: 12),
          const _CoachMarkCard(
            message: 'Start here — create or join a trip.',
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Available after a trip',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        const _DisabledTripPreviewGrid(),
      ],
    );
  }
}

class _CoachMarkCard extends StatelessWidget {
  const _CoachMarkCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisabledTripPreviewGrid extends StatelessWidget {
  const _DisabledTripPreviewGrid();

  @override
  Widget build(BuildContext context) {
    const previews = [
      (Icons.chat_bubble_rounded, 'Messages'),
      (Icons.sos_rounded, 'SOS'),
      (Icons.map_rounded, 'Map'),
      (Icons.record_voice_over_rounded, 'Walkie-talkie'),
    ];
    return GridView.builder(
      itemCount: previews.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = previews[index];
        return Opacity(
          opacity: 0.58,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$1, color: AppColors.mutedText),
                  const Spacer(),
                  Text(item.$2, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text('Start a trip first'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _DashboardKind { online, offline }

_DashboardKind _dashboardKind(ModeState state) {
  return state.effectiveMode == EffectiveMode.online
      ? _DashboardKind.online
      : _DashboardKind.offline;
}

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.userName,
    required this.modeState,
    required this.trip,
    required this.activeChannel,
    required this.groups,
  });

  final String userName;
  final ModeState modeState;
  final TripSessionModel? trip;
  final OfflineChannelModel? activeChannel;
  final List<GroupModel> groups;

  @override
  Widget build(BuildContext context) {
    final activeTrip = trip;
    final channelLabel =
        activeTrip?.channelCode ?? activeChannel?.channelCode ?? 'Not selected';
    final syncLabel = modeState.effectiveMode == EffectiveMode.online
        ? modeState.backendReachable
            ? 'Ready'
            : 'Queued'
        : 'Paused';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.deepForest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepForest.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Welcome, $userName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                ),
              ),
              CompactStatusChip(
                label: _modeChipLabel(modeState),
                color: _modeColor(modeState),
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HeroLine(
            label: 'Trip',
            value: activeTrip?.tripName ?? _groupName(groups),
          ),
          if (activeTrip != null)
            _HeroLine(label: 'Mode', value: _tripModeLabel(activeTrip)),
          if (activeTrip != null)
            _HeroLine(
              label: 'Cloud',
              value: activeTrip.cloudGroupId != null
                  ? 'Ready'
                  : activeTrip.mode == 'hybrid'
                      ? 'Pending'
                      : 'Not required',
            ),
          _HeroLine(label: 'Channel', value: channelLabel),
          _HeroLine(label: 'Sync', value: syncLabel),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/trip/create'),
                  icon: const Icon(Icons.add_road_rounded),
                  label: const Text('Create Trip'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.deepForest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/offline-channel/join'),
                  icon: const Icon(Icons.hub_rounded),
                  label: const Text('Join Channel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go('/trips'),
            icon: const Icon(Icons.route_rounded),
            label: const Text('Manage Trips'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChipWrap extends StatelessWidget {
  const _StatusChipWrap({
    required this.modeState,
    required this.authState,
    required this.trip,
  });

  final ModeState modeState;
  final AuthAccessState authState;
  final TripSessionModel? trip;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        CompactStatusChip(
          label: _modeChipLabel(modeState),
          color: _modeColor(modeState),
          icon: modeState.userMode.icon,
        ),
        CompactStatusChip(
          label: _identityLabel(authState),
          color: _identityColor(authState),
          icon: Icons.person_pin_circle_rounded,
        ),
        CompactStatusChip(
          label: trip == null ? 'No Trip' : 'Trip Active',
          color: trip == null ? AppColors.warning : AppColors.success,
          icon: trip == null ? Icons.hiking_rounded : Icons.check_circle,
        ),
        CompactStatusChip(
          label: modeState.effectiveMode == EffectiveMode.online
              ? 'Sync Ready'
              : 'Sync Paused',
          color: modeState.effectiveMode == EffectiveMode.online
              ? AppColors.success
              : AppColors.offlinePurple,
          icon: Icons.cloud_sync_rounded,
        ),
      ],
    );
  }
}

class _FeatureSection extends StatelessWidget {
  const _FeatureSection({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<_ActionSpec> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 680 ? 3 : 2;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions
                  .map(
                    (action) => SizedBox(
                      width: width,
                      child: _ToolCard(action: action),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ToolCard extends ConsumerWidget {
  const _ToolCard({required this.action});

  final _ActionSpec action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = action.featureKey == null
        ? true
        : ref.watch(featureFlagProvider(action.featureKey!)).asData?.value ??
            true;
    final color = enabled ? action.color : AppColors.disabledGrey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled
            ? action.onTap
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This feature is disabled in Settings.'),
                  ),
                );
              },
        child: Ink(
          height: 132,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: AppColors.charcoal.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(action.icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  if (action.badge != null)
                    CompactStatusChip(
                      label: action.badge!,
                      color: color,
                      dense: true,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: enabled ? AppColors.charcoal : AppColors.mutedText,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                maxLines: 2,
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

class _ActionSpec {
  const _ActionSpec(
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.featureKey,
    this.onTap, {
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? featureKey;
  final VoidCallback onTap;
  final String? badge;
}

List<_ActionSpec> _actionsFor({
  required BuildContext context,
  required _DashboardKind kind,
  required List<GroupModel> groups,
  required OfflineChannelModel? activeChannel,
}) {
  if (kind == _DashboardKind.online) {
    return [
      _ActionSpec(
        'Cloud Chat',
        'Group messages and latest known history',
        Icons.forum_rounded,
        AppColors.skyBlue,
        'cloud_chat',
        () => context.go('/chat?tab=cloud'),
      ),
      _ActionSpec(
        'Groups',
        'Trip teams and members',
        Icons.groups_rounded,
        AppColors.deepForest,
        'cloud_chat',
        () => context.go('/groups'),
      ),
      _ActionSpec(
        'Online Map',
        'Locations and teammates',
        Icons.map_rounded,
        AppColors.success,
        'online_location_sync',
        () => context.go('/map'),
      ),
      _ActionSpec(
        'SOS',
        'Emergency alert and history',
        Icons.health_and_safety_rounded,
        AppColors.danger,
        'cloud_sos',
        () => context.go('/sos'),
      ),
      _ActionSpec(
        'Bridge',
        'Hybrid delivery activity',
        Icons.cable_rounded,
        AppColors.offlinePurple,
        'bridge_mode',
        () => context.go('/bridge'),
        badge: 'Hybrid',
      ),
    ];
  }

  final textOnlyActions = [
    _ActionSpec(
      'Channels',
      'Offline channel setup',
      Icons.hub_rounded,
      AppColors.deepForest,
      'offline_chat',
      () => context.go('/offline-channel'),
    ),
    _ActionSpec(
      'Offline Chat',
      'Text over nearby channel',
      Icons.forum_rounded,
      AppColors.skyBlue,
      'offline_chat',
      () => context.go('/chat?tab=offline'),
    ),
    _ActionSpec(
      'Nearby Peers',
      'Discover connected phones',
      Icons.radar_rounded,
      AppColors.signalOrange,
      'nearby_discovery',
      () => context.go('/nearby-peers'),
    ),
  ];

  if (OfflineTextOnlyFlags.enabled) {
    return [
      ...textOnlyActions,
      _ActionSpec(
        'Compass',
        'Connection guidance',
        Icons.explore_rounded,
        AppColors.deepForest,
        'connectivity_compass',
        () => context.go('/connectivity'),
      ),
    ];
  }

  return [
    ...textOnlyActions,
    _ActionSpec(
      'SOS',
      'Broadcast emergency alert',
      Icons.emergency_share_rounded,
      AppColors.danger,
      'offline_sos',
      () => context.go('/sos'),
    ),
    _ActionSpec(
      'Location',
      'Share local position safely',
      Icons.location_on_rounded,
      AppColors.success,
      'offline_location_share',
      () => context.go('/map'),
    ),
    _ActionSpec(
      'PTT',
      'Voice-note and live radio',
      Icons.record_voice_over_rounded,
      AppColors.signalOrange,
      'voice_note_ptt',
      () => _openPtt(context, groups, activeChannel, kind),
    ),
    _ActionSpec(
      'Compass',
      'Connection guidance',
      Icons.explore_rounded,
      AppColors.deepForest,
      'connectivity_compass',
      () => context.go('/connectivity'),
    ),
  ];
}

String _modeChipLabel(ModeState state) {
  if (state.modeControlType == ModeControlType.auto) {
    return switch (state.effectiveMode) {
      EffectiveMode.online => 'Auto - Online',
      EffectiveMode.offline => 'Auto - Offline',
      EffectiveMode.hybridLimited => 'Auto - Reconnecting',
    };
  }
  return state.userMode.label;
}

Color _modeColor(ModeState state) {
  if (state.effectiveMode == EffectiveMode.online) return AppColors.success;
  if (state.effectiveMode == EffectiveMode.offline) {
    return AppColors.offlinePurple;
  }
  return AppColors.skyBlue;
}

String _identityLabel(AuthAccessState state) {
  return switch (state) {
    AuthAccessState.authenticatedOnline => 'Cloud Ready',
    AuthAccessState.authenticatedOfflineCached => 'Cached User',
    AuthAccessState.guestOffline => 'Local Profile',
    AuthAccessState.unauthenticated => 'Identity Needed',
  };
}

Color _identityColor(AuthAccessState state) {
  return switch (state) {
    AuthAccessState.authenticatedOnline => AppColors.success,
    AuthAccessState.authenticatedOfflineCached => AppColors.warning,
    AuthAccessState.guestOffline => AppColors.offlinePurple,
    AuthAccessState.unauthenticated => AppColors.danger,
  };
}

String _groupName(List<GroupModel> groups) {
  return groups.isEmpty ? 'No active trip' : groups.first.groupName;
}

String _tripModeLabel(TripSessionModel trip) {
  return switch (trip.mode) {
    'hybrid' => 'Cloud + Offline Backup',
    'offline' => 'Offline Only',
    'online' => 'Cloud Trip',
    _ => 'Trip',
  };
}

void _openPtt(
  BuildContext context,
  List<GroupModel> groups,
  OfflineChannelModel? channel,
  _DashboardKind kind,
) {
  if (channel != null) {
    context.go('/offline-channel/${channel.channelId}/ptt');
    return;
  }
  if (kind == _DashboardKind.online && groups.isNotEmpty) {
    context.go('/groups/${groups.first.id}/ptt');
    return;
  }
  context.go('/trip/setup-wizard');
}
