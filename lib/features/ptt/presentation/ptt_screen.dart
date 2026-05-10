import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/offline/offline_packet_router.dart';
import '../../../shared/widgets/compact_status_chip.dart';
import '../../../shared/widgets/mode_status_widgets.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import 'ptt_controller.dart';
import 'widgets/push_to_talk_button.dart';
import 'widgets/speaker_lock_banner.dart';
import 'widgets/voice_note_bubble.dart';

class PttScreen extends ConsumerWidget {
  const PttScreen({
    this.groupId,
    this.offlineChannelId,
    super.key,
  });

  final String? groupId;
  final String? offlineChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final effectiveUser = user ?? _localUser(ref);
    if (effectiveUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Create your TrailLink profile before using PTT.'),
        ),
      );
    }

    if (offlineChannelId != null) {
      final channelValue =
          ref.watch(offlineChannelDetailsProvider(offlineChannelId!));
      return channelValue.when(
        data: (channel) {
          if (channel == null) {
            return const Scaffold(
              body: Center(child: Text('Offline channel not found.')),
            );
          }
          return _PttBody(
            args: PttSessionArgs(
              currentUser: effectiveUser,
              offlineChannel: channel,
            ),
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          body: Center(child: Text(error.toString())),
        ),
      );
    }

    return _PttBody(
      args: PttSessionArgs(currentUser: effectiveUser, groupId: groupId),
    );
  }

  UserModel? _localUser(WidgetRef ref) {
    try {
      return CurrentUserActor.fromAuthAccess(
        ref.read(authAccessControllerProvider),
      ).toUserModel();
    } catch (_) {
      return null;
    }
  }
}

class _PttBody extends ConsumerWidget {
  const _PttBody({required this.args});

  final PttSessionArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pttControllerProvider(args));
    final controller = ref.read(pttControllerProvider(args).notifier);
    final modeState = ref.watch(modeControllerProvider);
    ref.listen(offlinePacketRouterProvider, (_, next) {
      final notice = next.lastNotice ?? '';
      if (shouldRefreshPttForOfflineNotice(notice)) {
        controller.refresh();
      }
      if (next.lastEmergencyAlert != null) {
        controller.interruptForEmergency();
      }
    });
    final channelEnded = args.offlineChannel?.isEnded == true;
    final canSpeak =
        !channelEnded && (state.floor?.canCurrentUserSpeak ?? true);

    return Scaffold(
      appBar: AppBar(title: Text(args.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            CompactStatusRow(
              children: [
                ModeStatusChip(state: modeState),
                CompactStatusChip(
                  label: _floorLabel(state),
                  color: _floorColor(state),
                  icon: Icons.record_voice_over_rounded,
                  dense: true,
                ),
                PeerStatusChip(count: modeState.connectedPeerCount),
              ],
            ),
            const SizedBox(height: 12),
            if (channelEnded) ...[
              const InlineInfoNotice(
                message:
                    'This channel has ended. Walkie-talkie is disabled and history is read-only.',
                icon: Icons.lock_clock_rounded,
              ),
              const SizedBox(height: 12),
            ],
            if (!args.isOnlineGroup) ...[
              _VoiceModeSelector(
                selected: state.voiceMode,
                enabled: !channelEnded &&
                    !state.isRecording &&
                    !state.isLiveStreaming &&
                    !state.isWaitingForFloor,
                onChanged: controller.selectVoiceMode,
              ),
              const SizedBox(height: 12),
            ],
            SpeakerLockBanner(
              floor: state.floor,
              isRecording: state.isRecording || state.isLiveStreaming,
              isWaiting: state.isWaitingForFloor,
            ),
            const SizedBox(height: 12),
            InlineInfoNotice(
              message: _modeHint(args, state),
              icon: state.voiceMode == PttVoiceMode.liveRadio
                  ? Icons.radio_rounded
                  : Icons.mic_rounded,
            ),
            const SizedBox(height: 24),
            Center(
              child: PushToTalkButton(
                isRecording: state.isRecording || state.isLiveStreaming,
                isWaiting: state.isWaitingForFloor,
                enabled: canSpeak || state.isRecording || state.isLiveStreaming,
                onPress: controller.pressToTalk,
                onRelease: controller.releaseToSend,
                idleLabel: state.voiceMode == PttVoiceMode.liveRadio
                    ? 'Hold to Stream'
                    : 'Hold to Talk',
                activeLabel: state.voiceMode == PttVoiceMode.liveRadio
                    ? 'Release to Stop'
                    : 'Release to Send',
                waitingLabel: 'Waiting for floor',
                icon: state.voiceMode == PttVoiceMode.liveRadio
                    ? Icons.radio_rounded
                    : Icons.mic_rounded,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                state.isRecording
                    ? '${state.recordingSeconds}s / ${args.isOnlineGroup ? 30 : 15}s'
                    : state.isLiveStreaming
                        ? 'Live ${state.recordingSeconds}s'
                        : _buttonHint(state),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (state.infoMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                state.infoMessage!,
                style: const TextStyle(color: AppColors.success),
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 24),
            Text('Voice Notes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (state.notes.isEmpty)
              const InlineInfoNotice(
                message: 'No voice notes yet.',
                icon: Icons.voice_chat_outlined,
              )
            else
              ...state.notes.map(
                (note) => VoiceNoteBubble(
                  note: note,
                  onPlay: () => controller.play(note),
                ),
              ),
            if (!args.isOnlineGroup) ...[
              const SizedBox(height: 24),
              Text(
                'Live Radio Activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (state.liveSessions.isEmpty)
                const InlineInfoNotice(
                  message: 'No live radio sessions yet.',
                  icon: Icons.radio_outlined,
                )
              else
                ...state.liveSessions.map((session) {
                  final seconds = ((session.durationMs ?? 0) / 1000).round();
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.skyBlue.withValues(alpha: 0.12),
                        foregroundColor: AppColors.skyBlue,
                        child: const Icon(Icons.radio_rounded),
                      ),
                      title: Text(session.senderName),
                      subtitle: Text(
                        session.status == 'started'
                            ? 'Live now'
                            : '${session.status} • ${seconds}s • ${session.chunkCount} chunks',
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

String _floorLabel(PttState state) {
  if (state.isWaitingForFloor) return 'Waiting for floor';
  if (state.isLiveStreaming) return 'Streaming live';
  if (state.isRecording) return 'Recording';
  if (state.floor?.hasSpeaker == true) return 'Speaking';
  return 'Channel free';
}

Color _floorColor(PttState state) {
  if (state.isLiveStreaming) return AppColors.skyBlue;
  if (state.isRecording) return AppColors.danger;
  if (state.isWaitingForFloor) return AppColors.warning;
  if (state.floor?.hasSpeaker == true) return AppColors.signalOrange;
  return AppColors.success;
}

String _modeHint(PttSessionArgs args, PttState state) {
  if (args.isOnlineGroup) {
    return 'Voice-note PTT records and uploads after release. Maximum length is 30 seconds.';
  }
  if (state.voiceMode == PttVoiceMode.liveRadio) {
    return 'Live Radio is experimental and works only with connected nearby peers and a strong connection.';
  }
  return 'Voice-note PTT records and sends after release. Keep offline clips under 15 seconds.';
}

String _buttonHint(PttState state) {
  return state.voiceMode == PttVoiceMode.liveRadio
      ? 'Hold to stream live'
      : 'Press and hold to record';
}

class _VoiceModeSelector extends StatelessWidget {
  const _VoiceModeSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final PttVoiceMode selected;
  final bool enabled;
  final ValueChanged<PttVoiceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PttVoiceMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: PttVoiceMode.voiceNote,
          label: Text('Voice-note PTT'),
          icon: Icon(Icons.mic_rounded),
        ),
        ButtonSegment(
          value: PttVoiceMode.liveRadio,
          label: Text('Live Radio Exp.'),
          icon: Icon(Icons.radio_rounded),
        ),
      ],
      selected: {selected},
      onSelectionChanged: enabled
          ? (selection) {
              onChanged(selection.first);
            }
          : null,
    );
  }
}
