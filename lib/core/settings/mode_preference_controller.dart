import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_defaults.dart';
import 'settings_service.dart';
import 'trail_communication_mode.dart';

final modePreferenceProvider =
    StateNotifierProvider<ModePreferenceController, TrailCommunicationMode>(
        (ref) {
  return ModePreferenceController(ref.read(settingsServiceProvider));
});

class ModePreferenceController extends StateNotifier<TrailCommunicationMode> {
  ModePreferenceController(this._settings)
      : super(TrailCommunicationMode.auto) {
    _load();
  }

  final SettingsService _settings;

  Future<void> _load() async {
    final modeName = await _settings.getString(
      AppSettingsDefaults.selectedMode,
      TrailCommunicationMode.auto.name,
    );
    state = TrailCommunicationMode.values.firstWhere(
      (mode) => mode.name == modeName,
      orElse: () => TrailCommunicationMode.auto,
    );
  }

  Future<void> setMode(TrailCommunicationMode mode) async {
    state = mode;
    await _settings.setString(AppSettingsDefaults.selectedMode, mode.name);
  }
}
