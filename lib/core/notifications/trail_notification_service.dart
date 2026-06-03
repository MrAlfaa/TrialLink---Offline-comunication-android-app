import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/local_database.dart';
import '../settings/settings_service.dart';

class TrailNotificationRequest {
  const TrailNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String? payload;
}

typedef TrailNotificationShow = Future<void> Function(
  TrailNotificationRequest request,
);

class TrailNotificationService {
  TrailNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    SettingsService? settings,
    TrailNotificationShow? showOverride,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _settings = settings ?? SettingsService(LocalDatabase.instance),
        _showOverride = showOverride;

  static final TrailNotificationService instance = TrailNotificationService();

  static const _channelId = 'traillink_updates';
  static const _channelName = 'TrailLink updates';
  static const _notificationsEnabledSetting = 'notifications_enabled';
  static const _messagePreviewSetting = 'notification_message_previews';

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsService _settings;
  final TrailNotificationShow? _showOverride;
  bool _initialized = false;
  bool _pluginFailureLogged = false;
  String? _activeOnlineGroupId;
  String? _activeOfflineChannelId;

  Future<void> initialize({bool requestPermission = true}) async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings);
    if (requestPermission) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  void setActiveOnlineChat(String? groupId) {
    _activeOnlineGroupId = groupId;
  }

  void clearActiveOnlineChat(String groupId) {
    if (_activeOnlineGroupId == groupId) {
      _activeOnlineGroupId = null;
    }
  }

  void setActiveOfflineChannel(String? channelId) {
    _activeOfflineChannelId = channelId;
  }

  void clearActiveOfflineChannel(String channelId) {
    if (_activeOfflineChannelId == channelId) {
      _activeOfflineChannelId = null;
    }
  }

  Future<void> notifyOnlineChatMessage({
    required String groupId,
    String? senderName,
    String? preview,
  }) async {
    if (_activeOnlineGroupId == groupId) return;
    await _show(
      TrailNotificationRequest(
        id: _stableId('online:$groupId'),
        title: 'New online message',
        body: await _messageBody(
          generic: 'You have a new online message.',
          senderName: senderName,
          preview: preview,
        ),
        payload: 'online_chat',
      ),
    );
  }

  Future<void> notifyOfflineChatMessage({
    required String channelId,
    String? senderName,
    String? preview,
  }) async {
    if (_activeOfflineChannelId == channelId) return;
    await _show(
      TrailNotificationRequest(
        id: _stableId('offline:$channelId'),
        title: 'New nearby message',
        body: await _messageBody(
          generic: 'You have a new nearby message.',
          senderName: senderName,
          preview: preview,
        ),
        payload: 'offline_chat',
      ),
    );
  }

  Future<void> notifyOfflineVoiceNote({
    required String channelId,
    String? senderName,
  }) async {
    if (_activeOfflineChannelId == channelId) return;
    await _show(
      TrailNotificationRequest(
        id: _stableId('voice:$channelId'),
        title: 'New voice note',
        body: await _messageBody(
          generic: 'A teammate sent a nearby voice note.',
          senderName: senderName,
        ),
        payload: 'offline_voice',
      ),
    );
  }

  Future<void> notifyOfflineSos({
    required String channelId,
    String? senderName,
  }) async {
    await _show(
      TrailNotificationRequest(
        id: _stableId('sos:$channelId:${DateTime.now().minute}'),
        title: 'Emergency alert',
        body: await _messageBody(
          generic: 'A teammate sent an emergency alert.',
          senderName: senderName,
        ),
        payload: 'offline_sos',
      ),
    );
  }

  Future<void> notifyInternetAvailable({required bool cloudPaused}) async {
    await _show(
      TrailNotificationRequest(
        id: _stableId('internet_available'),
        title: 'Internet available',
        body: cloudPaused
            ? 'Online service is available. TrailLink is still in Offline Mode.'
            : 'TrailLink can use online services again.',
        payload: 'internet_available',
      ),
    );
  }

  Future<String> _messageBody({
    required String generic,
    String? senderName,
    String? preview,
  }) async {
    final previewsEnabled = await _settingBool(_messagePreviewSetting, false);
    if (!previewsEnabled) return generic;
    final sender = _clean(senderName);
    final text = _clean(preview);
    if (sender == null && text == null) return generic;
    if (text == null) return '$sender sent a message.';
    if (sender == null) return text;
    return '$sender: $text';
  }

  String? _clean(String? value) {
    final trimmed = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 77)}...';
  }

  Future<void> _show(TrailNotificationRequest request) async {
    final override = _showOverride;
    if (override == null && !_hasServicesBinding()) return;
    final enabled = await _settingBool(_notificationsEnabledSetting, true);
    if (!enabled) return;
    if (override != null) {
      await override(request);
      return;
    }
    try {
      await initialize(requestPermission: false);
      const android = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Chat, safety, and connection updates',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: android);
      await _plugin.show(
        request.id,
        request.title,
        request.body,
        details,
        payload: request.payload,
      );
    } catch (error) {
      if (kDebugMode && !_pluginFailureLogged && !_isTestPluginError(error)) {
        _pluginFailureLogged = true;
        debugPrint('[TrailLink][Notification] failed: $error');
      }
    }
  }

  int _stableId(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x3fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  bool _isTestPluginError(Object error) {
    return _isRuntimeUnavailableError(error);
  }

  Future<bool> _settingBool(String key, bool fallback) async {
    try {
      return await _settings.getBool(key, fallback);
    } catch (error) {
      if (kDebugMode && !_isRuntimeUnavailableError(error)) {
        debugPrint('[TrailLink][Notification] setting read failed: $error');
      }
      return fallback;
    }
  }

  bool _hasServicesBinding() {
    try {
      ServicesBinding.instance.defaultBinaryMessenger;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isRuntimeUnavailableError(Object error) {
    final message = error.toString();
    return message.contains('LateInitializationError') ||
        message.contains('Binding has not yet been initialized') ||
        message.contains('MissingPluginException');
  }
}
