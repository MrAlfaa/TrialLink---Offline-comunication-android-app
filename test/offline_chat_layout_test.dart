import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/mode/mode_models.dart';
import 'package:traillink/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart';
import 'package:traillink/shared/widgets/trail_bottom_nav.dart';

void main() {
  group('offline chat layout', () {
    test('production offline chat screen exposes required layout keys', () {
      final source = File(
        'lib/features/offline_chat/presentation/offline_chat_screen.dart',
      ).readAsStringSync();
      final inputSource = File(
        'lib/features/offline_chat/presentation/widgets/offline_chat_input_bar.dart',
      ).readAsStringSync();
      final bubbleSource = File(
        'lib/features/offline_chat/presentation/widgets/offline_message_bubble.dart',
      ).readAsStringSync();

      expect(source, contains("ValueKey('offline-chat-screen')"));
      expect(source, contains("ValueKey('offline-chat-message-area')"));
      expect(source, contains("ValueKey('offline-chat-empty-state')"));
      expect(source, contains("ValueKey('offline-chat-readonly-bar')"));
      expect(source, contains('OfflineChatInputBar('));
      expect(source, contains('if (isReadOnly)'));
      expect(inputSource, contains("ValueKey('offline-chat-composer')"));
      expect(inputSource, contains("ValueKey('offline-chat-input')"));
      expect(inputSource, contains("ValueKey('offline-chat-send-button')"));
      expect(inputSource, contains("ValueKey('offline-chat-no-peers-hint')"));
      expect(inputSource, isNot(contains('MediaQuery.sizeOf(context).height')));
      expect(inputSource, isNot(contains('maxComposerHeight')));
      expect(inputSource, isNot(contains('minHeight: 126')));
      expect(inputSource, isNot(contains('maxHeight:')));
      expect(bubbleSource, isNot(contains('Saved profile')));
      expect(bubbleSource, contains("'authenticated_cached' => 'Teammate'"));
    });

    testWidgets('active channel with zero messages keeps composer visible',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _OfflineChatLayoutHarness(
            messages: [],
            peerCount: 0,
          ),
        ),
      );

      expect(find.byKey(const ValueKey('offline-chat-screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-empty-state')),
        findsOneWidget,
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
      expect(find.byKey(const ValueKey('offline-chat-readonly-bar')),
          findsNothing);
    });

    testWidgets('zero-peer send queues message into local list',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _OfflineChatLayoutHarness(
            messages: [],
            peerCount: 0,
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('offline-chat-input')),
        'Hello offline',
      );
      await tester.tap(find.byKey(const ValueKey('offline-chat-send-button')));
      await tester.pump();

      expect(find.text('Hello offline'), findsOneWidget);
      expect(find.text('Waiting to send'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-composer')),
        findsOneWidget,
      );
    });

    testWidgets('ended channel shows read-only bar instead of composer',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _OfflineChatLayoutHarness(
            messages: [],
            peerCount: 0,
            readOnly: true,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('offline-chat-readonly-bar')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('offline-chat-composer')), findsNothing);
      expect(find.byKey(const ValueKey('offline-chat-input')), findsNothing);
    });

    testWidgets('existing messages keep composer visible', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _OfflineChatLayoutHarness(
            messages: ['Existing queued message'],
            peerCount: 0,
          ),
        ),
      );

      expect(find.text('Existing queued message'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('offline-chat-composer')),
        findsOneWidget,
      );
    });

    testWidgets('shell chat layout has composer and global bottom navigation',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: _OfflineChatLayoutHarness(
              messages: [],
              peerCount: 0,
            ),
            bottomNavigationBar: TrailBottomNav(
              location: '/trips/trip-1/channels/channel-1/chats/chat-1',
              mode: UserMode.offline,
              modeButtonEnabled: true,
              onModePressed: _noop,
            ),
          ),
        ),
      );
      await tester.pump();

      final composer = find.byKey(const ValueKey('offline-chat-composer'));
      expect(composer, findsOneWidget);
      expect(find.byType(TrailBottomNav), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(tester.getTopLeft(composer).dy, greaterThan(0));
    });
  });
}

void _noop() {}

class _OfflineChatLayoutHarness extends StatefulWidget {
  const _OfflineChatLayoutHarness({
    required this.messages,
    required this.peerCount,
    this.readOnly = false,
  });

  final List<String> messages;
  final int peerCount;
  final bool readOnly;

  @override
  State<_OfflineChatLayoutHarness> createState() =>
      _OfflineChatLayoutHarnessState();
}

class _OfflineChatLayoutHarnessState extends State<_OfflineChatLayoutHarness> {
  late final List<String> _messages = [...widget.messages];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('offline-chat-screen'),
      appBar: AppBar(title: const Text('test trip')),
      body: Column(
        children: [
          Expanded(
            child: KeyedSubtree(
              key: const ValueKey('offline-chat-message-area'),
              child: _messages.isEmpty
                  ? const Center(
                      key: ValueKey('offline-chat-empty-state'),
                      child: Text(
                        'No messages yet\nMessages will wait to send until a nearby phone connects.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final message in _messages)
                          ListTile(
                            title: Text(message),
                            subtitle: const Text('Waiting to send'),
                          ),
                      ],
                    ),
            ),
          ),
          if (widget.readOnly)
            const _ReadOnlyBar()
          else
            OfflineChatInputBar(
              isSending: false,
              queueHint: widget.peerCount == 0
                  ? 'No phones connected. Messages will wait to send.'
                  : null,
              onSend: (message) {
                setState(() => _messages.add(message));
              },
            ),
        ],
      ),
    );
  }
}

class _ReadOnlyBar extends StatelessWidget {
  const _ReadOnlyBar();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: Padding(
        key: ValueKey('offline-chat-readonly-bar'),
        padding: EdgeInsets.all(16),
        child: Text('This channel has ended. Message history is read-only.'),
      ),
    );
  }
}
