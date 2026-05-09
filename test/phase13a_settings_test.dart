import 'package:flutter_test/flutter_test.dart';
import 'package:traillink/core/settings/app_settings_defaults.dart';
import 'package:traillink/core/settings/feature_flag_service.dart';
import 'package:traillink/core/settings/trail_communication_mode.dart';

void main() {
  test('Phase 13A default settings catalog includes required keys', () {
    final keys = AppSettingsDefaults.byKey.keys;

    expect(keys, contains(AppSettingsDefaults.selectedMode));
    expect(keys, contains(AppSettingsDefaults.onboardingComplete));
    expect(keys, contains(AppSettingsDefaults.agreementAccepted));
    expect(keys, contains('enable_offline_sos'));
    expect(keys, contains('enable_voice_note_ptt'));
    expect(keys, contains('voice_note_ptt_enabled'));
    expect(keys, contains('live_radio_enabled'));
    expect(keys, contains('app_lock_enabled'));
    expect(keys, contains('sos_fullscreen_alert_enabled'));
  });

  test('feature flags map dashboard feature keys to stored settings', () {
    expect(
      FeatureFlagService.featureToSettingKey['cloud_chat'],
      'enable_cloud_chat',
    );
    expect(
      FeatureFlagService.featureToSettingKey['offline_sos'],
      'enable_offline_sos',
    );
    expect(
      FeatureFlagService.featureToSettingKey['voice_note_ptt'],
      'voice_note_ptt_enabled',
    );
    expect(
      FeatureFlagService.featureToSettingKey['live_radio'],
      'live_radio_enabled',
    );
    expect(
      FeatureFlagService.featureToSettingKey['quick_sos_from_lock'],
      'quick_sos_from_lock_enabled',
    );
  });

  test('communication modes expose stable names for persistence', () {
    expect(TrailCommunicationMode.auto.name, 'auto');
    expect(TrailCommunicationMode.online.name, 'online');
    expect(TrailCommunicationMode.offline.name, 'offline');
  });
}
