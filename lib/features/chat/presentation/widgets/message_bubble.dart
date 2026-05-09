import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/chat_message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.onRetry,
    this.onPlayMedia,
    super.key,
  });

  final ChatMessageModel message;
  final VoidCallback onRetry;
  final VoidCallback? onPlayMedia;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    final bubbleColor = mine ? AppColors.deepForest : Colors.white;
    final textColor = mine ? Colors.white : AppColors.charcoal;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!mine)
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 3),
                  child: Text(
                    message.senderName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.skyBlue,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 6),
                    bottomRight: Radius.circular(mine ? 6 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessageContent(
                      message: message,
                      textColor: textColor,
                      onPlayMedia: onPlayMedia,
                    ),
                    if (message.sourcePath == 'bridge' ||
                        message.bridgedByName != null ||
                        message.originIdentityType != null) ...[
                      const SizedBox(height: 6),
                      _BridgeChip(
                        label: _bridgeLabel(message),
                        color: mine ? Colors.white : AppColors.offlinePurple,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('h:mm a').format(message.createdAt),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: textColor.withValues(alpha: 0.72),
                                  ),
                        ),
                        if (mine) ...[
                          const SizedBox(width: 8),
                          _DeliveryStatus(
                            status: message.deliveryStatus,
                            color: textColor.withValues(alpha: 0.86),
                            onRetry: onRetry,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.textColor,
    required this.onPlayMedia,
  });

  final ChatMessageModel message;
  final Color textColor;
  final VoidCallback? onPlayMedia;

  @override
  Widget build(BuildContext context) {
    return switch (message.messageType) {
      'image' => _ImageMessageContent(message: message),
      'voice' => _VoiceMessageContent(
          message: message,
          textColor: textColor,
          onPlayMedia: onPlayMedia,
        ),
      'file' => _FileMessageContent(message: message, textColor: textColor),
      _ => Text(
          message.content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: textColor,
                height: 1.28,
              ),
        ),
    };
  }
}

class _ImageMessageContent extends StatelessWidget {
  const _ImageMessageContent({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final localPath = message.localFilePath;
    final remoteUrl = _absoluteMediaUrl(message.remoteUrl);
    final image = localPath != null && File(localPath).existsSync()
        ? Image.file(File(localPath), fit: BoxFit.cover)
        : remoteUrl == null
            ? const Center(child: Icon(Icons.broken_image_rounded))
            : Image.network(remoteUrl, fit: BoxFit.cover);
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 190,
              maxWidth: 260,
              minHeight: 150,
              maxHeight: 260,
            ),
            child: image,
          ),
        ),
        if (message.uploadStatus == 'uploading' ||
            message.uploadStatus == 'pending')
          const _MediaOverlay(
            icon: Icons.cloud_upload_rounded,
            label: 'Uploading',
          )
        else if (message.uploadStatus == 'failed')
          const _MediaOverlay(
            icon: Icons.error_outline_rounded,
            label: 'Upload failed',
          ),
      ],
    );
  }
}

class _VoiceMessageContent extends StatelessWidget {
  const _VoiceMessageContent({
    required this.message,
    required this.textColor,
    required this.onPlayMedia,
  });

  final ChatMessageModel message;
  final Color textColor;
  final VoidCallback? onPlayMedia;

  @override
  Widget build(BuildContext context) {
    final seconds = ((message.durationMs ?? 0) / 1000).toStringAsFixed(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPlayMedia,
          icon: const Icon(Icons.play_arrow_rounded),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice note',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                '$seconds s - ${message.uploadStatus}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor.withValues(alpha: 0.76),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FileMessageContent extends StatelessWidget {
  const _FileMessageContent({required this.message, required this.textColor});

  final ChatMessageModel message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file_rounded, color: textColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message.fileName ?? 'File attachment',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _MediaOverlay extends StatelessWidget {
  const _MediaOverlay({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String? _absoluteMediaUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) return value;
  final baseUrl = EnvConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$baseUrl$value';
}

String _bridgeLabel(ChatMessageModel message) {
  final identity = switch (message.originIdentityType) {
    'guest' => 'Offline Guest',
    'authenticated_cached' => 'Cached User',
    'verified' => 'Verified',
    _ => null,
  };
  final via = message.bridgedByName == null
      ? null
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

class _DeliveryStatus extends StatelessWidget {
  const _DeliveryStatus({
    required this.status,
    required this.color,
    required this.onRetry,
  });

  final String status;
  final Color color;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (status == 'sending') {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    if (status == 'failed') {
      return InkWell(
        onTap: onRetry,
        child: const Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: AppColors.warning,
        ),
      );
    }

    final icon = switch (status) {
      'pending' => Icons.schedule_rounded,
      'synced' => Icons.done_all_rounded,
      _ => Icons.check_rounded,
    };

    return Icon(icon, size: 15, color: color);
  }
}
