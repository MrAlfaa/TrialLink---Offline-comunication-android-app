import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/offline_text_message_model.dart';
import 'offline_delivery_status.dart';

class OfflineMessageBubble extends StatelessWidget {
  const OfflineMessageBubble({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final OfflineTextMessageModel message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleColor = isMine ? AppColors.deepForest : AppColors.surface;
    final textColor = isMine ? Colors.white : AppColors.charcoal;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: EdgeInsets.fromLTRB(isMine ? 52 : 12, 5, isMine ? 12 : 52, 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Text(
                  message.senderName,
                  style: const TextStyle(
                    color: AppColors.signalOrange,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              Text(
                message.content,
                style: TextStyle(color: textColor, height: 1.35),
              ),
              if (message.sourcePath == 'bridge' ||
                  message.bridgedByName != null ||
                  message.originIdentityType != null) ...[
                const SizedBox(height: 7),
                _BridgeChip(
                  label: _bridgeLabel(message),
                  color: isMine ? Colors.white : AppColors.offlinePurple,
                ),
              ],
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  if (message.hopCount > 0)
                    Text(
                      'via relay',
                      style: TextStyle(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.75)
                            : AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (isMine)
                    OfflineDeliveryStatus(
                      status: message.deliveryStatus,
                      ackStatus: message.ackStatus,
                    ),
                  if (message.deliveryStatus == 'failed')
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _bridgeLabel(OfflineTextMessageModel message) {
  final identity = switch (message.originIdentityType) {
    'guest' => 'Offline Guest',
    'authenticated_cached' => 'Cached User',
    'verified' => 'Verified',
    _ => null,
  };
  final via = message.bridgedByName == null
      ? message.sourcePath == 'bridge'
          ? 'Delivered via bridge'
          : null
      : 'Bridged via ${message.bridgedByName}';
  return [via, identity].whereType<String>().join(' · ');
}

class _BridgeChip extends StatelessWidget {
  const _BridgeChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
