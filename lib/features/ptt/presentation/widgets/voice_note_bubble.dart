import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/voice_note_model.dart';

class VoiceNoteBubble extends StatelessWidget {
  const VoiceNoteBubble({
    required this.note,
    required this.onPlay,
    super.key,
  });

  final VoiceNoteModel note;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final color = note.isMine ? AppColors.deepForest : AppColors.surface;
    final foreground = note.isMine ? Colors.white : AppColors.charcoal;
    return Align(
      alignment: note.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Card(
          color: color,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.isMine ? 'You' : note.senderName,
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${((note.durationMs ?? 0) / 1000).toStringAsFixed(1)}s - ${note.deliveryStatus}',
                        style: TextStyle(
                            color: foreground.withValues(alpha: 0.78)),
                      ),
                      Text(
                        DateFormat.jm().format(note.createdAt),
                        style: TextStyle(
                            color: foreground.withValues(alpha: 0.68)),
                      ),
                    ],
                  ),
                ),
                if (note.ackStatus == 'acknowledged')
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child:
                        Icon(Icons.done_all_rounded, color: AppColors.success),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
