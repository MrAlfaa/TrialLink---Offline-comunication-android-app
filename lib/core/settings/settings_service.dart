import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/local_database.dart';
import 'app_settings_defaults.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(LocalDatabase.instance);
});

class SettingsService {
  SettingsService(this._database);

  final LocalDatabase _database;

  Future<bool> getBool(String key, bool defaultValue) async {
    final value = await _database.readSetting(key);
    if (value == null) {
      final defaultText = _defaultValueFor(key);
      return defaultText == null ? defaultValue : defaultText == 'true';
    }
    return value == 'true';
  }

  Future<void> setBool(String key, bool value) {
    return _database.upsertSetting(
      key,
      value ? 'true' : 'false',
      valueType: AppSettingValueType.bool.name,
    );
  }

  Future<String> getString(String key, String defaultValue) async {
    final value = await _database.readSetting(key);
    return value ?? _defaultValueFor(key) ?? defaultValue;
  }

  Future<void> setString(String key, String value) {
    return _database.upsertSetting(
      key,
      value,
      valueType: AppSettingValueType.string.name,
    );
  }

  Future<int> getInt(String key, int defaultValue) async {
    final value = await _database.readSetting(key);
    return int.tryParse(value ?? _defaultValueFor(key) ?? '') ?? defaultValue;
  }

  Future<void> setInt(String key, int value) {
    return _database.upsertSetting(
      key,
      value.toString(),
      valueType: AppSettingValueType.int.name,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final stored = await _database.readAllSettings();
    return {
      for (final definition in AppSettingsDefaults.definitions)
        definition.key: stored[definition.key] ?? definition.defaultValue,
      ...stored,
    };
  }

  Future<void> resetToDefaults() async {
    for (final definition in AppSettingsDefaults.definitions) {
      await _database.upsertSetting(
        definition.key,
        definition.defaultValue,
        valueType: definition.valueType.name,
      );
    }
  }

  String? _defaultValueFor(String key) {
    return AppSettingsDefaults.byKey[key]?.defaultValue;
  }
}
