import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/settings/settings_service.dart';
import '../../../shared/widgets/settings_info_box.dart';
import '../../../shared/widgets/settings_section_card.dart';
import '../../../shared/widgets/settings_toggle_tile.dart';
import '../data/bridge_repository.dart';
import '../data/models/bridge_settings_model.dart';

class BridgeSettingsScreen extends ConsumerStatefulWidget {
  const BridgeSettingsScreen({super.key});

  @override
  ConsumerState<BridgeSettingsScreen> createState() =>
      _BridgeSettingsScreenState();
}

class _BridgeSettingsScreenState extends ConsumerState<BridgeSettingsScreen> {
  BridgeSettingsModel _settings = BridgeSettingsModel.defaults();
  bool _featureEnabled = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(bridgeRepositoryProvider);
    final settings = await repository.getSettings();
    final featureEnabled = await ref
        .read(settingsServiceProvider)
        .getBool('enable_bridge_mode', true);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _featureEnabled = featureEnabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bridge Mode')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const SettingsInfoBox(
                    icon: Icons.cable_rounded,
                    color: AppColors.offlinePurple,
                    message:
                        'Help nearby offline teammates reach the online group using your phone as a bridge. Bridge Mode may use battery and mobile data.',
                  ),
                  const SizedBox(height: 14),
                  SettingsSectionCard(
                    title: 'Bridge Mode',
                    icon: Icons.cable_rounded,
                    children: [
                      SettingsToggleTile(
                        title: 'Enable Bridge Mode',
                        value: _featureEnabled && _settings.bridgeEnabled,
                        onChanged: (value) => _save(
                          _settings.copyWith(bridgeEnabled: value),
                          featureEnabled: value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SettingsSectionCard(
                    title: 'Bridge Data Types',
                    icon: Icons.sync_alt_rounded,
                    children: [
                      _toggle('Text messages', _settings.bridgeText,
                          (v) => _settings.copyWith(bridgeText: v)),
                      _toggle('SOS alerts', _settings.bridgeSos,
                          (v) => _settings.copyWith(bridgeSos: v)),
                      _toggle('Location updates', _settings.bridgeLocation,
                          (v) => _settings.copyWith(bridgeLocation: v)),
                      _toggle('Normal voice notes', _settings.bridgeNormalVoice,
                          (v) => _settings.copyWith(bridgeNormalVoice: v)),
                      _toggle(
                        'Emergency voice notes',
                        _settings.bridgeEmergencyVoice,
                        (v) => _settings.copyWith(bridgeEmergencyVoice: v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SettingsSectionCard(
                    title: 'Safety Rules',
                    icon: Icons.verified_user_rounded,
                    children: [
                      _toggle(
                        'Same trip/channel only',
                        _settings.bridgeOnlySameTrip,
                        (v) => _settings.copyWith(bridgeOnlySameTrip: v),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _toggle(
    String title,
    bool value,
    BridgeSettingsModel Function(bool value) update,
  ) {
    return SettingsToggleTile(
      title: title,
      value: value,
      onChanged: (next) => _save(update(next)),
    );
  }

  Future<void> _save(
    BridgeSettingsModel settings, {
    bool? featureEnabled,
  }) async {
    final nextFeatureEnabled = featureEnabled ?? _featureEnabled;
    final updated = settings.copyWith();
    setState(() {
      _settings = updated;
      _featureEnabled = nextFeatureEnabled;
    });
    await ref.read(bridgeRepositoryProvider).saveSettings(updated);
    await ref
        .read(settingsServiceProvider)
        .setBool('enable_bridge_mode', nextFeatureEnabled);
  }
}
