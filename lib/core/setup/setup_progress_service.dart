import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings_defaults.dart';
import '../settings/settings_service.dart';

final setupProgressServiceProvider = Provider<SetupProgressService>((ref) {
  return SetupProgressService(ref.read(settingsServiceProvider));
});

class SetupProgressService {
  SetupProgressService(this._settings);

  final SettingsService _settings;

  Future<bool> isSetupCompleted() async {
    final setupCompleted = await _settings.getBool(
      AppSettingsDefaults.setupCompleted,
      false,
    );
    if (setupCompleted) return true;
    return _settings.getBool(AppSettingsDefaults.onboardingComplete, false);
  }

  Future<String> getNextSetupRoute() async {
    if (!await _settings.getBool('agreement_accepted', false)) {
      return '/setup/agreement';
    }
    if (!await _settings.getBool('identity_configured', false)) {
      return '/setup/identity';
    }
    if (!await _settings.getBool('default_mode_configured', false)) {
      return '/setup/mode';
    }
    if (!await _settings.getBool('feature_preferences_configured', false)) {
      return '/setup/features';
    }
    if (!await _settings.getBool('security_preferences_configured', false)) {
      return '/setup/security';
    }
    if (!await _settings.getBool('trip_configured', false)) {
      return '/setup/trip';
    }
    if (!await _settings.getBool('permissions_configured', false)) {
      return '/setup/permissions';
    }
    await completeSetup();
    return '/home';
  }

  Future<void> markAgreementAccepted() async {
    await _settings.setBool('agreement_accepted', true);
    await _settings.setString(
      'agreement_accepted_at',
      DateTime.now().toIso8601String(),
    );
    await _settings.setString('setup_step', 'identity');
  }

  Future<void> markIdentityConfigured() async {
    await _mark('identity_configured', 'mode');
  }

  Future<void> markModeConfigured() async {
    await _mark('default_mode_configured', 'features');
  }

  Future<void> markFeaturePreferencesConfigured() async {
    await _mark('feature_preferences_configured', 'security');
  }

  Future<void> markSecurityPreferencesConfigured() async {
    await _mark('security_preferences_configured', 'trip');
  }

  Future<void> markTripConfigured() async {
    await _mark('trip_configured', 'permissions');
  }

  Future<void> markPermissionsConfigured() async {
    await _mark('permissions_configured', 'complete');
  }

  Future<void> completeSetup() async {
    await _settings.setBool(AppSettingsDefaults.setupCompleted, true);
    await _settings.setBool(AppSettingsDefaults.onboardingComplete, true);
    await _settings.setString('setup_step', 'complete');
  }

  Future<void> resetSetupForTesting() async {
    for (final key in [
      AppSettingsDefaults.setupCompleted,
      AppSettingsDefaults.onboardingComplete,
      'agreement_accepted',
      'identity_configured',
      'default_mode_configured',
      'feature_preferences_configured',
      'security_preferences_configured',
      'trip_configured',
      'permissions_configured',
    ]) {
      await _settings.setBool(key, false);
    }
    await _settings.setString('setup_step', 'welcome');
  }

  Future<void> _mark(String key, String nextStep) async {
    await _settings.setBool(key, true);
    await _settings.setString('setup_step', nextStep);
  }
}
