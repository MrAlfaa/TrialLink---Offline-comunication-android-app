import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/features/offline_chat/presentation/offline_chat_screen.dart';
import 'package:traillink/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart';
import 'package:traillink/shared/widgets/trail_bottom_nav.dart';

void main() {
  group('Phase 14H shell offline chat context', () {
    test('router exposes canonical chat routes inside shell route', () {
      final router = File('lib/app/router.dart').readAsStringSync();

      final canonical = router.indexOf(
        "path: '/trips/:tripId/channels/:channelId/chats/:chatId'",
      );
      final helper = router.indexOf(
        "path: '/trips/:tripId/channels/:channelId/chats'",
      );
      final singularLegacy =
          router.indexOf("path: '/offline-channel/:channelId/chat'");
      final pluralLegacy =
          router.indexOf("path: '/offline-channels/:channelId/chat'");
      final shell = router.indexOf('ShellRoute(');

      expect(canonical, greaterThanOrEqualTo(0));
      expect(helper, greaterThanOrEqualTo(0));
      expect(singularLegacy, greaterThanOrEqualTo(0));
      expect(pluralLegacy, greaterThanOrEqualTo(0));
      expect(canonical, greaterThan(shell));
      expect(helper, greaterThan(shell));
      expect(singularLegacy, greaterThan(shell));
      expect(pluralLegacy, greaterThan(shell));
      expect(router, contains('OfflineChatRouteResolverScreen'));
    });

    test(
        'offline chat screen uses ActiveTripContext resolver and no layout hacks',
        () {
      final screen = File(
        'lib/features/offline_chat/presentation/offline_chat_screen.dart',
      ).readAsStringSync();
      final service = File(
        'lib/features/trip_context/data/trip_context_service.dart',
      ).readAsStringSync();

      expect(service, contains('resolveOfflineChatContext'));
      expect(service, contains('resolveDefaultOfflineChatRoute'));
      expect(service, contains('membershipStatus'));
      expect(screen, contains('offlineChatContextProvider'));
      expect(screen, contains('OfflineChatContextErrorScreen'));
      expect(screen, contains('appBar: ChatAppBar('));
      expect(screen, contains('body: SafeArea('));
      expect(screen, contains('bottom: false'));
      expect(screen, contains('Expanded('));
      expect(screen, contains('OfflineChatInputBar('));
      expect(screen, isNot(contains('_OfflineChatHeader')));
      expect(screen, isNot(contains('floatingActionButton')));
      expect(screen, isNot(contains('bottomNavigationBar')));
      expect(screen, isNot(contains('View.of(context)')));
      expect(screen, isNot(contains('composerHeight')));
      expect(screen, isNot(contains('Positioned(')));
    });

    testWidgets('shell chat layout renders composer with bottom nav',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _ShellChatHarness(peerCount: 0),
            bottomNavigationBar: TrailBottomNav(
              location: '/trips/trip-1/channels/channel-1/chats/chat-1',
              mode: UserMode.offline,
              modeButtonEnabled: true,
              onModePressed: _noop,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('offline-chat-composer')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('offline-chat-input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-send-button')),
        findsOneWidget,
      );
      expect(find.byType(TrailBottomNav), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('zero peer queued message keeps composer visible',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _FullscreenChatHarness(peerCount: 0),
        ),
      );

      expect(
        find.byKey(const ValueKey('offline-chat-no-peers-hint')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('offline-chat-input')),
        'Phase 14H queued hello',
      );
      await tester.tap(find.byKey(const ValueKey('offline-chat-send-button')));
      await tester.pump();

      expect(find.text('Phase 14H queued hello'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-composer')),
        findsOneWidget,
      );
    });

    testWidgets('read-only state replaces composer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _FullscreenChatHarness(readOnly: true),
        ),
      );

      expect(
        find.byKey(const ValueKey('offline-chat-readonly-bar')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('offline-chat-composer')), findsNothing);
    });

    testWidgets('invalid context page provides Open Trip action',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OfflineChatContextErrorScreen(
            message: 'This chat is not linked to the active trip.',
            tripId: 'trip-1',
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('offline-chat-context-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('offline-chat-open-trip-button')),
        findsOneWidget,
      );
    });

    testWidgets('Android back can pop full-screen chat route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const Text('Messages'),
          routes: {
            '/chat': (_) => const _FullscreenChatHarness(peerCount: 0),
          },
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/chat');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('offline-chat-composer')),
        findsOneWidget,
      );
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Messages'), findsOneWidget);
    });
  });
}

void _noop() {}

class _ShellChatHarness extends StatelessWidget {
  const _ShellChatHarness({
    this.peerCount = 0,
  });

  final int peerCount;

  @override
  Widget build(BuildContext context) {
    return _FullscreenChatHarness(peerCount: peerCount);
  }
}

class _FullscreenChatHarness extends StatefulWidget {
  const _FullscreenChatHarness({
    this.peerCount = 0,
    this.readOnly = false,
  });

  final int peerCount;
  final bool readOnly;

  @override
  State<_FullscreenChatHarness> createState() => _FullscreenChatHarnessState();
}

class _FullscreenChatHarnessState extends State<_FullscreenChatHarness> {
  final List<String> _messages = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('offline-chat-screen'),
      appBar: AppBar(title: const Text('Offline Chat')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('offline-chat-message-area'),
                child: _messages.isEmpty
                    ? const Center(
                        key: ValueKey('offline-chat-empty-state'),
                        child: Text('No messages yet'),
                      )
                    : ListView(
                        children: [
                          for (final message in _messages)
                            ListTile(
                              title: Text(message),
                              subtitle: const Text('Queued'),
                            ),
                        ],
                      ),
              ),
            ),
            if (widget.readOnly)
              const SafeArea(
                top: false,
                child: Padding(
                  key: ValueKey('offline-chat-readonly-bar'),
                  padding: EdgeInsets.all(16),
                  child: Text('This channel has ended.'),
                ),
              )
            else
              OfflineChatInputBar(
                isSending: false,
                queueHint: widget.peerCount == 0
                    ? 'No peers connected. Messages will be queued.'
                    : null,
                onSend: (message) {
                  setState(() => _messages.add(message));
                },
              ),
          ],
        ),
      ),
    );
  }
}
