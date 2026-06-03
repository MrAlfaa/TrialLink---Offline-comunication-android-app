import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/voice_note_model.dart';
import '../ptt_controller.dart';

class VoiceNoteBubble extends StatelessWidget {
  const VoiceNoteBubble({
    required this.note,
    required this.onPlay,
    this.playbackState,
    super.key,
  });

  final VoiceNoteModel note;
  final VoidCallback onPlay;
  final VoiceNotePlaybackState? playbackState;

  @override
  Widget build(BuildContext context) {
    final color = note.isMine ? AppColors.deepForest : AppColors.surface;
    final foreground = note.isMine ? Colors.white : AppColors.charcoal;
    final durationMs = note.durationMs ?? 0;
    final state = playbackState ??
        VoiceNotePlaybackState.idle(note.localVoiceId, durationMs);
    final progress = state.progress.clamp(0.0, 1.0);
    final icon = state.isPlaying
        ? Icons.pause_rounded
        : state.isLoading
            ? Icons.hourglass_empty_rounded
            : Icons.play_arrow_rounded;
    return Align(
      alignment: note.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340, minWidth: 250),
        child: Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filled(
                      onPressed: state.isLoading ? null : onPlay,
                      icon: Icon(icon),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note.isMine ? 'You' : note.senderName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (note.ackStatus == 'acknowledged')
                                const Icon(
                                  Icons.done_all_rounded,
                                  color: AppColors.success,
                                ),
                            ],
                          ),
                          Text(
                            '${_durationLabel(durationMs)} - ${_statusLabel(note.deliveryStatus)}',
                            style: TextStyle(
                              color: foreground.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: foreground.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    note.isMine ? Colors.white : AppColors.deepForest,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.errorMessage ??
                            DateFormat.jm().format(note.createdAt),
                        style: TextStyle(
                          color: state.errorMessage == null
                              ? foreground.withValues(alpha: 0.68)
                              : AppColors.danger,
                        ),
                      ),
                    ),
                    if (state.isPlaying)
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.68),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _durationLabel(int durationMs) {
  if (durationMs <= 0) return '0.0s';
  return '${(durationMs / 1000).toStringAsFixed(1)}s';
}

String _statusLabel(String status) {
  return switch (status) {
    'queued' => 'waiting to send',
    'pending' => 'waiting',
    _ => status,
  };
}
