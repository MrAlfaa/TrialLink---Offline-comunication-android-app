import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:traillink/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart';
import 'package:traillink/features/offline_channel/data/active_offline_channel_resolver.dart';
import 'package:traillink/shared/widgets/trail_bottom_nav.dart';

void main() {
  group('Phase 14B active offline channel source of truth', () {
    test('resolver exposes the required active-channel API', () {
      final source = File(
        'lib/features/offline_channel/data/active_offline_channel_resolver.dart',
      ).readAsStringSync();

      expect(source, contains('class ActiveOfflineChannelResolver'));
      expect(source, contains('getActiveOfflineChannel()'));
      expect(source, contains('getActiveOfflineChannelForActiveTrip()'));
      expect(source, contains('getActiveUsableOfflineChannel()'));
      expect(source, contains('hasActiveUsableOfflineChannel()'));
      expect(source, contains('setActiveChannel(String channelId)'));
      expect(source, contains('repairActiveChannelFromActiveTripIfNeeded()'));
      expect(source, contains('trip_sessions'));
      expect(source, contains('offline_channels'));
      expect(source, contains('active_offline_channel_id'));
      expect(source, contains('_ensureCurrentUserMembershipIfNeeded'));
      expect(source, contains('memberRole'));
    });

    test('providers centralize active channel resolution through trip context',
        () {
      final source = File(
        'lib/features/offline_channel/presentation/offline_channel_controller.dart',
      ).readAsStringSync();

      expect(source, contains('activeOfflineChannelResolverProvider'));
      expect(source, contains('activeUsableOfflineChannelProvider'));
      expect(source, contains('activeTripChannelProvider'));
      expect(source, contains('repairActiveChannelFromActiveTripIfNeeded'));
      expect(source, contains('activeTripContextProvider.future'));
      expect(source, contains('TripContextService'));
      expect(source, contains('joinOfflineChannelAsActiveTrip'));
      expect(source, isNot(contains('TripSessionRepository')));
      expect(source, isNot(contains('activateOfflineChannelTrip')));
    });

    test('offline feature screens use resolver-backed active channel provider',
        () {
      final nearby =
          File('lib/features/nearby/presentation/nearby_peers_screen.dart')
              .readAsStringSync();
      final connectivity = File(
        'lib/features/connectivity_intelligence/presentation/connectivity_guidance_screen.dart',
      ).readAsStringSync();
      final connectivityController = File(
        'lib/features/connectivity_intelligence/presentation/connectivity_controller.dart',
      ).readAsStringSync();
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();
      final chatHub =
          File('lib/features/chat/presentation/chat_hub_screen.dart')
              .readAsStringSync();

      expect(nearby, contains('activeUsableOfflineChannelProvider'));
      expect(connectivity, contains('activeUsableOfflineChannelProvider'));
      expect(
        connectivityController,
        contains('activeUsableOfflineChannelProvider'),
      );
      expect(dashboard, contains('activeUsableOfflineChannelProvider'));
      expect(dashboard, contains('activeTripChannelProvider'));
      expect(dashboard, contains('/offline-channel/\${channel.channelId}/ptt'));
      expect(chatHub, contains('activeTripChannelProvider'));
      expect(chatHub, contains('activeUsableOfflineChannelProvider'));
      expect(chatHub, contains('/trips/\${trip.tripId}/channels/'));
    });

    test('join flow activates the joined channel as the active trip', () {
      final joinScreen = File(
        'lib/features/offline_channel/presentation/join_offline_channel_screen.dart',
      ).readAsStringSync();
      final repository =
          File('lib/features/trip/data/trip_session_repository.dart')
              .readAsStringSync();

      expect(repository, contains('activateOfflineChannelTrip'));
      expect(joinScreen, contains('activeTripContextProvider'));
      expect(joinScreen, contains('activeTripProvider'));
      expect(joinScreen, contains('activeUsableOfflineChannelProvider'));
      expect(joinScreen, contains('activeTripChannelProvider'));
    });

    test(
        'offline chat resolves context instead of falling back to stale channels',
        () {
      final source = File(
              'lib/features/offline_chat/presentation/offline_chat_screen.dart')
          .readAsStringSync();

      expect(source, contains('OfflineChatRouteResolverScreen'));
      expect(source, contains('resolveOfflineChatContext'));
      expect(source, contains('resolveDefaultOfflineChatRoute'));
      expect(source, contains('No peers connected. Messages will be queued.'));
      expect(source, contains('offline-chat-context-error'));
    });

    test('offline chat route is shell-owned with bottom nav available', () {
      final source = File(
              'lib/features/offline_chat/presentation/offline_chat_screen.dart')
          .readAsStringSync();
      final cloudSource =
          File('lib/features/chat/presentation/chat_screen.dart')
              .readAsStringSync();
      final routerSource = File('lib/app/router.dart').readAsStringSync();
      final shellSource =
          File('lib/shared/widgets/trail_scaffold.dart').readAsStringSync();
      final shell = routerSource.indexOf('ShellRoute(');
      final canonical = routerSource.indexOf(
        "path: '/trips/:tripId/channels/:channelId/chats/:chatId'",
      );
      final legacy = routerSource.indexOf(
        "path: '/offline-channel/:channelId/chat'",
      );

      expect(source, contains('appBar: ChatAppBar('));
      expect(source, contains('body: SafeArea('));
      expect(source, contains('bottom: false'));
      expect(source, contains('child: Column('));
      expect(source, contains('OfflineChatInputBar('));
      expect(source, isNot(contains('floatingActionButton')));
      expect(
          source, isNot(contains('bottomNavigationBar: OfflineChatInputBar')));
      expect(source, isNot(contains('View.of(context)')));
      expect(source, isNot(contains('composerHeight')));
      expect(source, isNot(contains('Positioned.fill')));
      expect(cloudSource, contains('ChatInputBar('));
      expect(cloudSource, isNot(contains('bottomNavigationBar: ChatInputBar')));
      expect(cloudSource, isNot(contains('View.of(context)')));
      expect(routerSource, isNot(contains('_constrainedPageChild')));
      expect(routerSource,
          contains("path: '/trips/:tripId/channels/:channelId/chats/:chatId'"));
      expect(
          routerSource, contains("path: '/offline-channel/:channelId/chat'"));
      expect(
          routerSource, contains("path: '/offline-channels/:channelId/chat'"));
      expect(canonical, greaterThan(shell));
      expect(legacy, greaterThan(shell));
      expect(shellSource, contains('body: widget.child'));
      expect(shellSource, isNot(contains('TrailBottomNav.bodyInset')));
      expect(shellSource, isNot(contains('hideBottomNav')));
      expect(shellSource, isNot(contains('_isFullscreenChatRoute')));
    });

    test('trip readiness reads actual nearby permission status', () {
      final wizard = File(
        'lib/features/trip/presentation/trip_setup_wizard_screen.dart',
      ).readAsStringSync();
      final permissionService =
          File('lib/features/nearby/data/nearby_permission_service.dart')
              .readAsStringSync();

      expect(
          permissionService, contains('Future<NearbyPermissionState> check()'));
      expect(wizard, contains('NearbyPermissionService().check()'));
      expect(wizard, contains('nearbyPermission.granted'));
      expect(
        wizard,
        isNot(
          contains(
            "label: 'Nearby permission',\n"
            '          state: _ReadinessState.missing,',
          ),
        ),
      );
    });

    test(
        'debug route exposes active channel diagnostics only outside production',
        () {
      final router = File('lib/app/router.dart').readAsStringSync();
      final screen = File(
        'lib/features/offline_channel/presentation/active_channel_debug_screen.dart',
      ).readAsStringSync();

      expect(router, contains("path: '/debug/active-channel'"));
      expect(router, contains('EnvConfig.appEnv'));
      expect(screen, contains('Active Channel Diagnostics'));
      expect(screen, contains('Resolver result'));
      expect(screen, contains('trip offline_channel_id'));
    });
  });

  group('Phase 14B offline chat composer', () {
    testWidgets('offline shell chat shows composer above bottom nav',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Scaffold(
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const Expanded(
                      child: Center(child: Text('No offline messages yet.')),
                    ),
                    OfflineChatInputBar(
                      onSend: (_) {},
                      isSending: false,
                      queueHint: 'No peers connected. Messages will be queued.',
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: TrailBottomNav(
              location: '/trips/trip-1/channels/channel-1/chats/chat-1',
              mode: UserMode.offline,
              modeButtonEnabled: true,
              onModePressed: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TrailBottomNav), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('offline-chat-composer')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-input')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('offline-chat-send-button')),
          findsOneWidget);

      expect(find.byKey(const ValueKey('offline-chat-send-button')),
          findsOneWidget);
      final composerBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('offline-chat-composer')))
          .dy;
      final navTop = tester.getTopLeft(find.byType(TrailBottomNav)).dy;
      expect(composerBottom, lessThanOrEqualTo(navTop + 1));
    });

    testWidgets('offline composer stays visible with no connected peers',
        (tester) async {
      var sentText = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineChatInputBar(
              onSend: (value) => sentText = value,
              isSending: false,
              queueHint: 'No peers connected. Messages will be queued.',
            ),
          ),
        ),
      );

      expect(
        find.text('No peers connected. Messages will be queued.'),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('offline-chat-composer')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-input')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('offline-chat-input')),
        'Offline hello',
      );
      await tester.tap(find.byKey(const ValueKey('offline-chat-send-button')));
      await tester.pump();

      expect(sentText, 'Offline hello');
    });

    testWidgets('offline input can expose disabled read-only state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineChatInputBar(
              onSend: (_) {},
              isSending: false,
              enabled: false,
              disabledMessage:
                  'This channel was ended by the owner. Chat history is read-only.',
            ),
          ),
        ),
      );

      expect(
        find.text(
          'This channel was ended by the owner. Chat history is read-only.',
        ),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('offline-chat-input')),
      );
      final sendButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('offline-chat-send-button')),
      );

      expect(field.enabled, isFalse);
      expect(sendButton.onPressed, isNull);
    });

    testWidgets('cloud chat composer exposes stable input and send controls',
        (tester) async {
      var sentText = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(onSend: (value) => sentText = value),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('cloud-chat-composer')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cloud-chat-message-field')),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('cloud-chat-send-button')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('cloud-chat-message-field')),
        'Cloud hello',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cloud-chat-send-button')));
      await tester.pump();

      expect(sentText, 'Cloud hello');
    });
  });

  group('Phase 14B cloud chat composer', () {
    testWidgets('cloud chat shell shows composer above bottom nav',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Scaffold(
              body: Column(
                children: [
                  const Expanded(
                    child: Center(child: Text('No cloud messages yet.')),
                  ),
                  ChatInputBar(onSend: (_) {}),
                ],
              ),
            ),
            bottomNavigationBar: TrailBottomNav(
              location: '/groups/group-1/chat',
              mode: UserMode.online,
              modeButtonEnabled: true,
              onModePressed: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TrailBottomNav), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.byKey(const ValueKey('cloud-chat-composer')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cloud-chat-message-field')),
        findsOneWidget,
      );
      expect(
          find.byKey(const ValueKey('cloud-chat-send-button')), findsOneWidget);

      final composerBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('cloud-chat-composer')))
          .dy;
      final navTop = tester.getTopLeft(find.byType(TrailBottomNav)).dy;
      expect(composerBottom, lessThanOrEqualTo(navTop + 1));
    });
  });

  test('resolver type is importable for implementation tests', () {
    expect(ActiveOfflineChannelResolver, isNotNull);
  });
}
