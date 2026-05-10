import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class OfflineChatInputBar extends StatefulWidget {
  const OfflineChatInputBar({
    required this.onSend,
    required this.isSending,
    this.enabled = true,
    this.disabledMessage,
    this.queueHint,
    this.bottomPadding = 12,
    super.key,
  });

  final ValueChanged<String> onSend;
  final bool isSending;
  final bool enabled;
  final String? disabledMessage;
  final String? queueHint;
  final double bottomPadding;

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
    return Semantics(
      label: 'offline-chat-composer',
      container: true,
      child: SafeArea(
        key: const ValueKey('offline-chat-composer'),
        top: false,
        bottom: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          padding: EdgeInsets.fromLTRB(12, 10, 12, widget.bottomPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.offlinePurple.withValues(alpha: 0.18),
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.enabled
                    ? widget.queueHint ??
                        'Media is online-only. Offline mode supports text and voice-note PTT.'
                    : widget.disabledMessage ?? 'This chat is read-only.',
                key: widget.queueHint == null
                    ? null
                    : const ValueKey('offline-chat-no-peers-hint'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.offlinePurple,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'offline-chat-message-field',
                      textField: true,
                      child: TextField(
                        key: const ValueKey('offline-chat-input'),
                        controller: _controller,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 1000,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: widget.enabled
                              ? 'Message offline channel'
                              : 'Read-only chat',
                          counterText: '',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('offline-chat-send-button'),
                      onPressed:
                          widget.isSending || !widget.enabled ? null : _send,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.signalOrange,
                        minimumSize: const Size.square(48),
                      ),
                      child: widget.isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
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
