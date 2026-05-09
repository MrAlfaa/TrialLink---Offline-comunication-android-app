import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_service.dart';

final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService(ref.read(settingsServiceProvider));
});

final featureFlagProvider = FutureProvider.family<bool, String>((ref, key) {
  return ref.read(featureFlagServiceProvider).isFeatureEnabled(key);
});

class FeatureFlagService {
  FeatureFlagService(this._settings);

  final SettingsService _settings;

  static const featureToSettingKey = <String, String>{
    'cloud_chat': 'enable_cloud_chat',
    'online_location_sync': 'enable_online_location_sync',
    'cloud_sos': 'enable_cloud_sos',
    'bridge_mode': 'enable_bridge_mode',
    'offline_channel': 'enable_offline_channel',
    'nearby_discovery': 'enable_nearby_discovery',
    'offline_chat': 'enable_offline_chat',
    'offline_sos': 'enable_offline_sos',
    'offline_location_share': 'enable_offline_location_share',
    'voice_note_ptt': 'voice_note_ptt_enabled',
    'live_radio': 'live_radio_enabled',
    'connectivity_compass': 'enable_connectivity_compass',
    'app_lock': 'app_lock_enabled',
    'quick_sos_from_lock': 'quick_sos_from_lock_enabled',
  };

  Future<bool> isFeatureEnabled(String featureKey) async {
    final settingKey = featureToSettingKey[featureKey];
    if (settingKey == null) return true;
    final enabled = await _settings.getBool(settingKey, true);
    if (featureKey == 'offline_sos') {
      return enabled && await _settings.getBool('offline_sos_enabled', true);
    }
    if (featureKey == 'offline_location_share') {
      return enabled &&
          await _settings.getBool('offline_location_share_enabled', true);
    }
    return enabled;
  }
}
