import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/notifications/trail_notification_service.dart';
import 'package:traillink/core/settings/settings_service.dart';

void main() {
  group('Phase 14V separate chat, notifications, and PTT fixes', () {
    test('primary routes separate cloud chat from nearby chat', () {
      final router = File('lib/app/router.dart').readAsStringSync();
      final chatHub =
          File('lib/features/chat/presentation/chat_hub_screen.dart')
              .readAsStringSync();
      final cloudController =
          File('lib/features/chat/presentation/chat_controller.dart')
              .readAsStringSync();

      expect(router, contains('ChatScreen('));
      expect(router, contains('OfflineChatScreen('));
      expect(router, isNot(contains('UnifiedOrCloudChatScreen(')));
      expect(chatHub, contains("label: 'Online Chat'"));
      expect(chatHub, contains("label: 'Nearby Chat'"));
      expect(cloudController, isNot(contains('bridgeOnlineMessageToOffline')));
    });

    test('mode-specific home copy exposes the right tools', () {
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();

      expect(dashboard, contains("'Online Chat'"));
      expect(dashboard, contains("'Text, photos, and voice notes'"));
      expect(dashboard, contains("'Trip Team'"));
      expect(dashboard, contains("'Connect phones'"));
      expect(dashboard, contains("'Offline Chat'"));
      expect(dashboard, contains("'Send SOS'"));
      expect(dashboard, contains("'Share location'"));
      expect(dashboard, isNot(contains("'Delivery Status'")));
    });

    test('notification service suppresses active chat and hides previews',
        () async {
      final shown = <TrailNotificationRequest>[];
      final service = TrailNotificationService(
        settings: _FakeSettings(previewsEnabled: false),
        showOverride: (request) async => shown.add(request),
      );

      service.setActiveOnlineChat('group-1');
      await service.notifyOnlineChatMessage(
        groupId: 'group-1',
        senderName: 'Alex',
        preview: 'Secret message',
      );
      expect(shown, isEmpty);

      await service.notifyOnlineChatMessage(
        groupId: 'group-2',
        senderName: 'Alex',
        preview: 'Secret message',
      );
      expect(shown.single.title, 'New online message');
      expect(shown.single.body, 'You have a new online message.');
      expect(shown.single.body, isNot(contains('Secret message')));
    });

    test('notification service respects local notification opt-out', () async {
      final shown = <TrailNotificationRequest>[];
      final service = TrailNotificationService(
        settings: _FakeSettings(
          previewsEnabled: true,
          notificationsEnabled: false,
        ),
        showOverride: (request) async => shown.add(request),
      );

      await service.notifyOfflineChatMessage(
        channelId: 'channel-1',
        senderName: 'Sam',
        preview: 'Where are you?',
      );

      expect(shown, isEmpty);
    });

    test('dashboard exposes notification shortcut and settings route', () {
      final dashboard = File('lib/features/dashboard/dashboard_screen.dart')
          .readAsStringSync();
      final settings =
          File('lib/features/settings/presentation/settings_screen.dart')
              .readAsStringSync();
      final router = File('lib/app/router.dart').readAsStringSync();

      expect(dashboard, contains("tooltip: 'Notifications'"));
      expect(dashboard, contains("context.go('/settings/notifications')"));
      expect(settings, contains('class NotificationSettingsScreen'));
      expect(settings, contains("'notifications_enabled'"));
      expect(settings, contains("'notification_message_previews'"));
      expect(router, contains("path: 'notifications'"));
    });

    test('manual mode apply returns to Home and refreshes active providers',
        () {
      final sheet =
          File('lib/shared/widgets/mode_bottom_sheet.dart').readAsStringSync();

      expect(sheet, contains("context.go('/home')"));
      expect(sheet, contains('connectionModeProvider.notifier'));
      expect(sheet, contains('activeTripProvider'));
      expect(sheet, contains('activeTripChannelProvider'));
      expect(sheet, contains('activeUsableOfflineChannelProvider'));
      expect(sheet, contains('myGroupsProvider'));
    });

    test('offline packet router notifies accepted chat, voice, and SOS packets',
        () {
      final router = File('lib/core/offline/offline_packet_router.dart')
          .readAsStringSync();

      expect(router, contains('notifyOfflineChatMessage'));
      expect(router, contains('notifyOfflineVoiceNote'));
      expect(router, contains('notifyOfflineSos'));
      expect(router, contains('_isFromActor'));
    });

    test('voice-note PTT rejects empty clips and prevents duplicate release',
        () {
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();

      expect(controller, contains('_releaseInProgress'));
      expect(controller, contains('Hold to record a voice note.'));
      expect(repository, contains('minVoiceNoteDurationMs'));
      expect(repository, contains('minVoiceNoteFileBytes'));
      expect(repository, contains('clip.durationMs < minVoiceNoteDurationMs'));
      expect(repository, contains('file.deleteSync()'));
      expect(repository.indexOf('if (clip == null) return null;'),
          lessThan(repository.indexOf('final note = VoiceNoteModel(')));
    });

    test('Live Radio release is idempotent and stops all audio paths', () {
      final controller =
          File('lib/features/ptt/presentation/ptt_controller.dart')
              .readAsStringSync();
      final repository =
          File('lib/features/ptt/data/ptt_repository.dart').readAsStringSync();
      final audio = File('lib/features/ptt/data/live_radio_audio_service.dart')
          .readAsStringSync();

      expect(controller, contains('_liveReleaseInProgress'));
      expect(repository, contains('_endingLiveRadio'));
      expect(repository, contains('await _liveAudio.stopAll();'));
      expect(repository, contains('finally'));
      expect(audio, contains('incomingIdleTimeoutMs'));
      expect(audio, contains('_startIncomingCleanupTimer'));
    });
  });
}

class _FakeSettings implements SettingsService {
  _FakeSettings({
    required this.previewsEnabled,
    this.notificationsEnabled = true,
  });

  final bool previewsEnabled;
  final bool notificationsEnabled;

  @override
  Future<bool> getBool(String key, bool defaultValue) async {
    if (key == 'notifications_enabled') return notificationsEnabled;
    if (key == 'notification_message_previews') return previewsEnabled;
    return defaultValue;
  }

  @override
  Future<Map<String, String>> getAllSettings() async => {};

  @override
  Future<int> getInt(String key, int defaultValue) async => defaultValue;

  @override
  Future<String> getString(String key, String defaultValue) async =>
      defaultValue;

  @override
  Future<void> resetToDefaults() async {}

  @override
  Future<void> setBool(String key, bool value) async {}

  @override
  Future<void> setInt(String key, int value) async {}

  @override
  Future<void> setString(String key, String value) async {}
}
