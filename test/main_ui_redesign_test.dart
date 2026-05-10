import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/features/chat/presentation/chat_hub_screen.dart';
import 'package:traillink/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:traillink/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:traillink/features/groups/data/group_repository.dart';
import 'package:traillink/features/groups/data/models/group_model.dart';
import 'package:traillink/features/groups/presentation/group_controller.dart';
import 'package:traillink/features/offline_channel/data/models/offline_channel_model.dart';
import 'package:traillink/features/offline_channel/presentation/offline_channel_controller.dart';
import 'package:traillink/features/trip/data/trip_session_model.dart';
import 'package:traillink/features/trip/data/trip_session_service.dart';
import 'package:traillink/shared/widgets/mode_status_widgets.dart';
import 'package:traillink/shared/widgets/trail_bottom_nav.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:5000/api');
    }
  });

  testWidgets('bottom nav uses compact integrated dock', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: TrailBottomNav(
            location: '/home',
            mode: UserMode.offline,
            modeButtonEnabled: true,
            onModePressed: () {},
          ),
        ),
      ),
    );

    final navBox = tester.renderObject<RenderBox>(find.byType(TrailBottomNav));
    expect(navBox.size.height, lessThanOrEqualTo(90));
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('messages hub opens offline channels tab from query intent',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myGroupsControllerProvider.overrideWith(
            (ref) => _StaticGroupsController(),
          ),
          offlineChannelListProvider.overrideWith(
            (ref) async => [
              OfflineChannelModel(
                channelId: 'channel-1',
                channelCode: 'TL-OFF-82KD',
                channelName: 'Knuckles Offline',
                createdByUserId: 'local-1',
                createdAt: DateTime(2026),
                isActive: true,
              ),
            ],
          ),
          activeTripProvider.overrideWith(
            (ref) async => TripSessionModel(
              tripId: 'trip-1',
              tripName: 'Knuckles Offline',
              mode: 'offline',
              offlineChannelId: 'channel-1',
              channelCode: 'TL-OFF-82KD',
              channelName: 'Knuckles Offline',
              localIdentityId: 'local-1',
              status: 'active',
              startedAt: DateTime(2026),
              syncState: 'local_only',
              createdAt: DateTime(2026),
            ),
          ),
        ],
        child: const MaterialApp(
          home: ChatHubScreen(initialTab: 'offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Offline Channels'), findsOneWidget);
    expect(find.text('Knuckles Offline'), findsWidgets);
    expect(find.text('TL-OFF-82KD'), findsWidgets);
  });

  testWidgets('chat header uses compact chips instead of a large banner',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: ChatAppBar(
            title: 'Knuckles Hiking Team',
            subtitle: 'Cloud chat - Offline fallback',
            chips: [
              ChatHeaderChip(
                label: 'Saved locally',
                color: Colors.purple,
                icon: Icons.save_rounded,
              ),
              ChatHeaderChip(
                label: '3 pending',
                color: Colors.orange,
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          body: SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Knuckles Hiking Team'), findsOneWidget);
    expect(find.text('Cloud chat - Offline fallback'), findsOneWidget);
    expect(find.text('Saved locally'), findsOneWidget);
    expect(find.text('3 pending'), findsOneWidget);
    expect(find.text('Offline Mode'), findsNothing);
  });

  testWidgets('offline chat input hides normal media attach affordance',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            onSend: (_) {},
            offlineHint: 'Text/voice only in offline mode',
          ),
        ),
      ),
    );

    expect(find.text('Text/voice only in offline mode'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
  });

  testWidgets('mode status widgets render compact labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactStatusRow(
            children: [
              ModeStatusChip(state: _modeState(EffectiveMode.online)),
              ModeStatusChip(state: _modeState(EffectiveMode.offline)),
              ModeStatusChip(
                state: _modeState(
                  EffectiveMode.hybridLimited,
                  connectionState: DetectedConnectionState.unstable,
                ),
              ),
              const SyncStatusChip(status: SyncChipStatus.ready),
              const SyncStatusChip(status: SyncChipStatus.paused),
              const SyncStatusChip(status: SyncChipStatus.queued),
              const PeerStatusChip(count: 0),
              const PeerStatusChip(count: 1),
              const PeerStatusChip(count: 3),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Unstable'), findsOneWidget);
    expect(find.text('Sync ready'), findsOneWidget);
    expect(find.text('Sync paused'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
    expect(find.text('No peers'), findsOneWidget);
    expect(find.text('1 peer'), findsOneWidget);
    expect(find.text('3 peers'), findsOneWidget);
  });

  test('normal feature screens do not render large connection mode banners',
      () {
    const userFacingScreens = [
      'lib/features/connectivity_intelligence/presentation/connectivity_guidance_screen.dart',
      'lib/features/emergency/presentation/sos_screen.dart',
      'lib/features/location/presentation/map_screen.dart',
      'lib/features/nearby/presentation/nearby_peers_screen.dart',
      'lib/features/offline_channel/presentation/offline_channel_list_screen.dart',
      'lib/features/placeholders/connectivity_placeholder_screen.dart',
      'lib/features/ptt/presentation/ptt_screen.dart',
      'lib/features/chat/presentation/chat_screen.dart',
      'lib/features/offline_chat/presentation/offline_chat_screen.dart',
    ];

    for (final path in userFacingScreens) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('ConnectionModeBanner')),
        reason: '$path should use compact status chips, not large banners.',
      );
    }
  });

  test('dashboard does not expose system status entry points', () {
    final source =
        File('lib/features/dashboard/dashboard_screen.dart').readAsStringSync();

    expect(source, isNot(contains("tooltip: 'System Status'")));
    expect(source, isNot(contains("context.go('/home/status')")));
    expect(source, isNot(matches(RegExp(r"_ActionSpec\(\s*'Sync'"))));
    expect(source, isNot(matches(RegExp(r"_ActionSpec\(\s*'Queue'"))));
    expect(source, isNot(contains('Store-and-forward status')));
  });

  test('home status route redirects away from diagnostics screen', () {
    final source = File('lib/app/router.dart').readAsStringSync();

    expect(source, isNot(contains('SystemStatusScreen')));
    expect(source, contains("path: 'status'"));
    expect(source, contains("redirect: (context, state) => '/home'"));
  });
}

ModeState _modeState(
  EffectiveMode effectiveMode, {
  DetectedConnectionState connectionState =
      DetectedConnectionState.backendOnline,
}) {
  return ModeState.initial().copyWith(
    modeControlType: ModeControlType.manual,
    userMode: effectiveMode == EffectiveMode.online
        ? UserMode.online
        : UserMode.offline,
    effectiveMode: effectiveMode,
    connectionState: connectionState,
    backendReachable: effectiveMode == EffectiveMode.online,
  );
}

class _StaticGroupsController extends MyGroupsController {
  _StaticGroupsController() : super(GroupRepository()) {
    state = const MyGroupsState(
      isLoading: false,
      groups: [
        GroupModel(
          id: 'group-1',
          groupName: 'Knuckles Hiking Team',
          groupCode: 'TL-A6BV6',
          createdBy: 'user-1',
          memberRole: 'member',
          memberCount: 2,
          joinedAt: '2026-01-01T00:00:00.000Z',
        ),
      ],
    );
  }

  @override
  Future<void> load() async {}
}
