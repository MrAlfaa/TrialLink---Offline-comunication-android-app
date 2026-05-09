import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OfflineChatInputBar extends StatefulWidget {
  const OfflineChatInputBar({
    required this.onSend,
    required this.isSending,
    this.enabled = true,
    this.disabledMessage,
    super.key,
  });

  final ValueChanged<String> onSend;
  final bool isSending;
  final bool enabled;
  final String? disabledMessage;

  @override
  State<OfflineChatInputBar> createState() => _OfflineChatInputBarState();
}

class _OfflineChatInputBarState extends State<OfflineChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (!widget.enabled) return;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.enabled
                        ? 'Media is online-only. Offline mode supports text and voice-note PTT.'
                        : widget.disabledMessage ?? 'This chat is read-only.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.offlinePurple,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _controller,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: widget.enabled
                          ? 'Message offline channel'
                          : 'Read-only chat',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: widget.isSending || !widget.enabled ? null : _send,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(15),
                backgroundColor: AppColors.signalOrange,
              ),
              child: widget.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
