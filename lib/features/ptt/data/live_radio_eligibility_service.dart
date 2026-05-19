import '../../../core/mode/mode_models.dart';
import '../../../core/settings/settings_service.dart';
import '../../connectivity_intelligence/data/connectivity_intelligence_repository.dart';
import '../../connectivity_intelligence/data/models/signal_quality_label.dart';
import '../../nearby/data/nearby_repository.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import 'live_radio_audio_service.dart';
import 'ptt_local_data_source.dart';

class LiveRadioEligibilityResult {
  const LiveRadioEligibilityResult({
    required this.allowed,
    required this.reason,
    required this.fallbackToVoiceNote,
    required this.connectedPeerCount,
  });

  final bool allowed;
  final String reason;
  final bool fallbackToVoiceNote;
  final int connectedPeerCount;
}

class LiveRadioEligibilityService {
  LiveRadioEligibilityService({
    required SettingsService settings,
    PttLocalDataSource? local,
    ConnectivityIntelligenceRepository? connectivity,
    LiveRadioAudioService? audio,
    NearbyRepository? nearby,
  })  : _settings = settings,
        _local = local ?? PttLocalDataSource(),
        _connectivity = connectivity ?? ConnectivityIntelligenceRepository(),
        _audio = audio ?? LiveRadioAudioService(),
        _nearby = nearby;

  final SettingsService _settings;
  final PttLocalDataSource _local;
  final ConnectivityIntelligenceRepository _connectivity;
  final LiveRadioAudioService _audio;
  final NearbyRepository? _nearby;

  Future<LiveRadioEligibilityResult> evaluate({
    required EffectiveMode effectiveMode,
    required OfflineChannelModel? channel,
  }) async {
    final fallback = await _settings.getBool(
      'live_radio_fallback_to_voice_note',
      true,
    );
    if (channel == null) {
      return LiveRadioEligibilityResult(
        allowed: false,
        reason: 'Select an offline channel before using Live Radio.',
        fallbackToVoiceNote: fallback,
        connectedPeerCount: 0,
      );
    }
    if (effectiveMode != EffectiveMode.offline) {
      return LiveRadioEligibilityResult(
        allowed: false,
        reason: 'Live Radio is offline-only. Switch to Offline Mode first.',
        fallbackToVoiceNote: fallback,
        connectedPeerCount: 0,
      );
    }
    final enabled = await _settings.getBool('live_radio_enabled', false);
    if (!enabled) {
      return const LiveRadioEligibilityResult(
        allowed: false,
        reason: 'Live Radio is experimental. Enable it in Voice Settings.',
        fallbackToVoiceNote: false,
        connectedPeerCount: 0,
      );
    }
    final peers = _nearby == null
        ? await _local.connectedPeers(channel.channelCode)
        : await _nearby.connectedPeers(channel.channelCode);
    if (peers.isEmpty) {
      return LiveRadioEligibilityResult(
        allowed: false,
        reason: 'Live Radio unavailable. Connect a nearby peer first.',
        fallbackToVoiceNote: fallback,
        connectedPeerCount: 0,
      );
    }
    if (!await _audio.hasPermission()) {
      return LiveRadioEligibilityResult(
        allowed: false,
        reason: 'Microphone permission is required for Live Radio.',
        fallbackToVoiceNote: fallback,
        connectedPeerCount: peers.length,
      );
    }
    final requiresStrong =
        await _settings.getBool('live_radio_requires_strong_connection', true);
    if (requiresStrong) {
      final summary = await _connectivity.summary(channel);
      final hasGoodPeer = summary.qualities.any((quality) {
        final label = quality.qualityLabel;
        final ack = quality.lastAckRttMs;
        return label == SignalQualityLabel.good ||
            label == SignalQualityLabel.excellent ||
            (ack != null && ack < 300);
      });
      if (!hasGoodPeer) {
        return LiveRadioEligibilityResult(
          allowed: false,
          reason:
              'Live Radio unavailable. Use Voice-note PTT for reliable delivery.',
          fallbackToVoiceNote: fallback,
          connectedPeerCount: peers.length,
        );
      }
    }
    return LiveRadioEligibilityResult(
      allowed: true,
      reason: 'Live Radio ready.',
      fallbackToVoiceNote: fallback,
      connectedPeerCount: peers.length,
    );
  }
}
