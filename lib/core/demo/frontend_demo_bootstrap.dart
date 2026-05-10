import '../database/local_database.dart';
import '../identity/local_identity_repository.dart';
import '../settings/settings_service.dart';
import '../../features/offline_chat/data/models/offline_text_message_model.dart';
import '../../features/offline_chat/data/offline_message_local_data_source.dart';
import '../../features/trip_context/data/trip_context_service.dart';

class FrontendDemoBootstrap {
  const FrontendDemoBootstrap._();

  static Future<void> ensureReady() async {
    await LocalDatabase.instance.initialize();

    final settings = SettingsService(LocalDatabase.instance);
    final identityRepository = LocalIdentityRepository();
    var identity = await identityRepository.getCurrentIdentity();
    identity ??= await identityRepository.createLocalIdentity(
      displayName: 'TrailLink Demo User',
      email: 'demo@traillink.local',
      phoneNumber: '+94000000000',
      emergencyNote: 'Frontend-only demo profile.',
    );

    await _configureFrontendOnlySettings(settings);

    final tripContext = TripContextService(
      identityRepository: identityRepository,
    );
    var context = await tripContext.getActiveTripContext();
    context ??= await tripContext.createTripWithPrimaryChannel(
      tripName: 'Demo Ridge Hike',
      mode: 'offline',
      description: 'Local frontend-only demo trip.',
      customChannelCode: 'TL-OFF-DEMO',
    );

    final channel = context.activeChannel;
    if (channel != null) {
      await _seedOfflineChat(
        channelId: channel.channelId,
        channelCode: channel.channelCode,
        chatId: context.activeChat?.chatId,
        userId: identity.localUserId,
        userName: identity.displayName,
      );
    }
  }

  static Future<void> _configureFrontendOnlySettings(
    SettingsService settings,
  ) async {
    for (final key in [
      'agreement_accepted',
      'identity_configured',
      'default_mode_configured',
      'feature_preferences_configured',
      'security_preferences_configured',
      'trip_configured',
      'permissions_configured',
      'setup_completed',
      'onboarding_complete',
      'enable_offline_chat',
      'enable_nearby',
      'enable_offline_sos',
      'enable_offline_location_share',
      'offline_sos_enabled',
      'offline_location_share_enabled',
      'ptt_enabled',
      'voice_note_ptt_enabled',
    ]) {
      await settings.setBool(key, true);
    }

    await settings.setString('setup_step', 'complete');
    await settings.setString('mode_control_type', 'manual');
    await settings.setString('manual_communication_mode', 'offline');
    await settings.setString('user_mode', 'offline');
    await settings.setString('selected_mode', 'offline');
    await settings.setBool('auto_sync_when_online', false);
    await settings.setBool('sync_offline_messages', false);
    await settings.setBool('sync_sos_history', false);
    await settings.setBool('sync_location_history', false);
    await settings.setBool('frontend_demo_seeded', true);
  }

  static Future<void> _seedOfflineChat({
    required String channelId,
    required String channelCode,
    required String? chatId,
    required String userId,
    required String userName,
  }) async {
    final local = OfflineMessageLocalDataSource();
    final existing = await local.getMessages(channelId);
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    await local.upsertMessage(
      OfflineTextMessageModel(
        messageId: 'demo-message-welcome',
        packetId: 'demo-packet-welcome',
        channelId: channelId,
        channelCode: channelCode,
        chatId: chatId,
        senderId: 'demo-guide',
        senderName: 'TrailLink Guide',
        content:
            'Demo channel ready. You can explore chat, Nearby, PTT, SOS, and map screens without a backend.',
        isMine: false,
        deliveryStatus: 'received',
        ackStatus: 'none',
        ttl: 5,
        hopCount: 0,
        createdAt: now.subtract(const Duration(minutes: 4)),
      ),
    );
    await local.upsertMessage(
      OfflineTextMessageModel(
        messageId: 'demo-message-local',
        packetId: 'demo-packet-local',
        channelId: channelId,
        channelCode: channelCode,
        chatId: chatId,
        senderId: userId,
        senderName: userName,
        content: 'Frontend-only demo is running in Manual Offline Mode.',
        isMine: true,
        deliveryStatus: 'queued',
        ackStatus: 'waiting',
        ttl: 5,
        hopCount: 0,
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
    );
  }
}
