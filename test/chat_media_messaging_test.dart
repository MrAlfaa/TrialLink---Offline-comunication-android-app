import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/features/chat/data/models/chat_message_model.dart';
import 'package:traillink/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:traillink/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('online cloud chat input shows attachment button',
      (tester) async {
    var imagePicked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            onSend: (_) {},
            isOnlineMediaAvailable: true,
            onPickImage: () => imagePicked = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Send Media'), findsOneWidget);
    expect(find.text('Image from gallery'), findsOneWidget);
    expect(find.text('Voice note'), findsOneWidget);

    await tester.tap(find.text('Image from gallery'));
    await tester.pumpAndSettle();
    expect(imagePicked, isTrue);
  });

  testWidgets('offline chat input hides attachment button and shows hint',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            onSend: (_) {},
            offlineHint:
                'Media is online-only. Offline mode supports text and voice-note PTT.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);
    expect(find.textContaining('Media is online-only'), findsOneWidget);
  });

  test('chat message model maps media metadata from API and DB', () {
    final api = ChatMessageModel.fromApiJson(
      {
        'id': 'server-1',
        'clientMessageId': 'client-1',
        'groupId': 'group-1',
        'sender': {'id': 'user-1', 'fullName': 'Dhana'},
        'messageType': 'image',
        'content': 'Image',
        'mediaUrl': '/uploads/chat-media/image.jpg',
        'fileName': 'image.jpg',
        'fileSizeBytes': 1234,
        'mimeType': 'image/jpeg',
        'createdAt': DateTime(2026).toIso8601String(),
      },
      currentUserId: 'user-1',
    );

    expect(api.messageType, 'image');
    expect(api.remoteUrl, '/uploads/chat-media/image.jpg');
    expect(api.uploadStatus, 'uploaded');
    expect(api.fileSizeBytes, 1234);

    final db = ChatMessageModel.fromDb({
      'local_id': 'local-1',
      'client_message_id': 'client-2',
      'group_id': 'group-1',
      'sender_id': 'user-1',
      'sender_name': 'Dhana',
      'message_type': 'voice',
      'content': 'Voice note',
      'delivery_status': 'pending',
      'is_mine': 1,
      'created_at': DateTime(2026).toIso8601String(),
      'sync_state': 'needs_sync',
      'local_file_path': 'voice.m4a',
      'duration_ms': 1200,
      'mime_type': 'audio/mp4',
      'upload_status': 'pending',
    });

    expect(db.messageType, 'voice');
    expect(db.localFilePath, 'voice.m4a');
    expect(db.durationMs, 1200);
    expect(db.uploadStatus, 'pending');
  });

  testWidgets('voice media bubble renders play action and status',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessageModel(
              localId: 'local-1',
              clientMessageId: 'client-1',
              groupId: 'group-1',
              senderId: 'user-1',
              senderName: 'Dhana',
              messageType: 'voice',
              content: 'Voice note',
              deliveryStatus: 'pending',
              isMine: true,
              createdAt: DateTime(2026),
              durationMs: 1500,
              uploadStatus: 'uploading',
            ),
            onRetry: () {},
            onPlayMedia: () {},
          ),
        ),
      ),
    );

    expect(find.text('Voice note'), findsOneWidget);
    expect(find.textContaining('uploading'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  test('source keeps media cloud-only and local schema through latest schema',
      () {
    final dbSource =
        File('lib/core/database/local_database.dart').readAsStringSync();
    final chatSource = File('lib/features/chat/presentation/chat_screen.dart')
        .readAsStringSync();

    expect(dbSource, contains('version: 20'));
    expect(dbSource, contains('local_file_path'));
    expect(dbSource, contains('upload_status'));
    expect(chatSource, contains('state.isOnline &&'));
    expect(chatSource, contains('ChatInputBar'));
  });

  test('cloud chat screen reserves shell bottom nav space for composer', () {
    final chatSource = File('lib/features/chat/presentation/chat_screen.dart')
        .readAsStringSync();

    expect(chatSource, contains('body: SafeArea('));
    expect(chatSource, contains('bottom: false'));
    expect(chatSource, contains('ChatInputBar('));
    expect(chatSource, isNot(contains('bottomNavigationBar')));
  });
}
