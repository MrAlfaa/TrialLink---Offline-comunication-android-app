enum AppSettingValueType {
  bool,
  string,
  int,
  double,
  json,
}

class AppSettingDefinition {
  const AppSettingDefinition({
    required this.key,
    required this.defaultValue,
    required this.valueType,
  });

  final String key;
  final String defaultValue;
  final AppSettingValueType valueType;
}

class AppSettingsDefaults {
  const AppSettingsDefaults._();

  static const selectedMode = 'selected_mode';
  static const userMode = 'user_mode';
  static const onboardingComplete = 'onboarding_complete';
  static const setupCompleted = 'setup_completed';
  static const agreementAccepted = 'agreement_accepted';

  static const definitions = <AppSettingDefinition>[
    AppSettingDefinition(
      key: userMode,
      defaultValue: 'auto',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: selectedMode,
      defaultValue: 'auto',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: onboardingComplete,
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: setupCompleted,
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'setup_step',
      defaultValue: 'welcome',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: agreementAccepted,
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'agreement_accepted_at',
      defaultValue: '',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'allow_location_for_sos',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'understand_offline_limitations',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'understand_live_radio_experimental',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'identity_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'default_mode_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'feature_preferences_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'security_preferences_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'trip_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'permissions_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'default_startup_mode',
      defaultValue: 'auto',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'auto_switch_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'ask_before_auto_switch',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'show_mode_explanations',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'mode_control_type',
      defaultValue: 'auto',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'manual_communication_mode',
      defaultValue: 'offline',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'identity_sync_state',
      defaultValue: 'local_only',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'identity_bootstrap_synced_at',
      defaultValue: '',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'splash_intro_seen',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_cloud_chat',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_online_location_sync',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_cloud_sos',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_bridge_mode',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_offline_channel',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_nearby_discovery',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_offline_chat',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'offline_sos_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_offline_sos',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'offline_location_share_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_offline_location_share',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_voice_note_ptt',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_live_radio',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'enable_connectivity_compass',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'confirm_before_sos',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sos_countdown_seconds',
      defaultValue: '3',
      valueType: AppSettingValueType.int,
    ),
    AppSettingDefinition(
      key: 'attach_location_to_sos',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'use_last_known_location_for_sos',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'retry_sos_until_ack',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sos_retry_interval_seconds',
      defaultValue: '10',
      valueType: AppSettingValueType.int,
    ),
    AppSettingDefinition(
      key: 'sos_vibration_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sos_sound_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sos_fullscreen_alert_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'app_lock_enabled',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'biometric_unlock_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'trail_pin_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'auto_lock_timeout',
      defaultValue: '1 minute',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'quick_sos_from_lock_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'hide_message_preview_when_locked',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'hide_location_when_locked',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'auto_delete_trip_data_after_trip',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'app_lock_configured',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'app_lock_last_unlocked_at',
      defaultValue: '',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'app_lock_last_backgrounded_at',
      defaultValue: '',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'app_lock_failed_pin_attempts',
      defaultValue: '0',
      valueType: AppSettingValueType.int,
    ),
    AppSettingDefinition(
      key: 'app_lock_pin_lockout_until',
      defaultValue: '',
      valueType: AppSettingValueType.string,
    ),
    AppSettingDefinition(
      key: 'voice_note_ptt_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'max_offline_voice_duration_seconds',
      defaultValue: '15',
      valueType: AppSettingValueType.int,
    ),
    AppSettingDefinition(
      key: 'one_speaker_at_a_time',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'speaker_timeout_seconds',
      defaultValue: '35',
      valueType: AppSettingValueType.int,
    ),
    AppSettingDefinition(
      key: 'live_radio_enabled',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'live_radio_requires_strong_connection',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'live_radio_fallback_to_voice_note',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'store_voice_notes_locally',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'auto_delete_voice_after_trip',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'auto_sync_when_online',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sync_offline_messages',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sync_sos_history',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sync_location_history',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'sync_normal_voice_notes',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'clear_completed_queue_after_sync',
      defaultValue: 'false',
      valueType: AppSettingValueType.bool,
    ),
    AppSettingDefinition(
      key: 'export_debug_logs_enabled',
      defaultValue: 'true',
      valueType: AppSettingValueType.bool,
    ),
  ];

  static final Map<String, AppSettingDefinition> byKey = {
    for (final definition in definitions) definition.key: definition,
  };
}
