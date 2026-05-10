import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    required this.onSend,
    this.onPickImage,
    this.onStartVoiceRecording,
    this.onStopVoiceRecording,
    this.onCancelVoiceRecording,
    this.isOnlineMediaAvailable = false,
    this.offlineHint,
    super.key,
  });

  final ValueChanged<String> onSend;
  final VoidCallback? onPickImage;
  final Future<void> Function()? onStartVoiceRecording;
  final Future<void> Function()? onStopVoiceRecording;
  final Future<void> Function()? onCancelVoiceRecording;
  final bool isOnlineMediaAvailable;
  final String? offlineHint;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'cloud-chat-composer',
      container: true,
      child: SafeArea(
        key: const ValueKey('cloud-chat-composer'),
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.offlineHint != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 7),
                    child: Text(
                      widget.offlineHint!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.offlinePurple,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.isOnlineMediaAvailable) ...[
                    IconButton(
                      tooltip: 'Attach media',
                      onPressed: _showAttachmentSheet,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Semantics(
                      label: 'cloud-chat-message-field',
                      textField: true,
                      child: TextField(
                        key: const ValueKey('cloud-chat-message-field'),
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Message your group...',
                          counterText: '',
                          prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 140),
                    scale: _controller.text.trim().isEmpty ? 0.92 : 1,
                    child: IconButton.filled(
                      key: const ValueKey('cloud-chat-send-button'),
                      tooltip: 'Send',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.signalOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(50, 50),
                      ),
                      onPressed: _controller.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send_rounded),
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

  void _showAttachmentSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Media',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _AttachmentTile(
                    icon: Icons.image_rounded,
                    title: 'Image from gallery',
                    subtitle: 'Send a compressed cloud image',
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onPickImage?.call();
                    },
                  ),
                  _AttachmentTile(
                    icon: Icons.camera_alt_rounded,
                    title: 'Camera photo',
                    subtitle: 'Coming in a later media pass',
                    enabled: false,
                    onTap: () {},
                  ),
                  _AttachmentTile(
                    icon: Icons.mic_rounded,
                    title: 'Voice note',
                    subtitle: 'Record a short online chat clip',
                    onTap: () {
                      Navigator.of(context).pop();
                      _showVoiceDialog();
                    },
                  ),
                  _AttachmentTile(
                    icon: Icons.attach_file_rounded,
                    title: 'File attachment',
                    subtitle: 'Online-only placeholder',
                    enabled: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVoiceDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VoiceNoteDialog(
        onStart: widget.onStartVoiceRecording,
        onStopAndSend: widget.onStopVoiceRecording,
        onCancel: widget.onCancelVoiceRecording,
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.deepForest : AppColors.mutedText;
    return ListTile(
      enabled: enabled,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: enabled ? onTap : null,
    );
  }
}

class _VoiceNoteDialog extends StatefulWidget {
  const _VoiceNoteDialog({
    required this.onStart,
    required this.onStopAndSend,
    required this.onCancel,
  });

  final Future<void> Function()? onStart;
  final Future<void> Function()? onStopAndSend;
  final Future<void> Function()? onCancel;

  @override
  State<_VoiceNoteDialog> createState() => _VoiceNoteDialogState();
}

class _VoiceNoteDialogState extends State<_VoiceNoteDialog> {
  bool _isRecording = false;
  bool _isBusy = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await widget.onStart?.call();
      if (!mounted) return;
      setState(() => _isRecording = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _send() async {
    setState(() => _isBusy = true);
    try {
      await widget.onStopAndSend?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isBusy = false;
      });
    }
  }

  Future<void> _cancel() async {
    await widget.onCancel?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Voice note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isRecording ? Icons.fiber_manual_record_rounded : Icons.mic_none,
            size: 54,
            color: _isRecording ? AppColors.danger : AppColors.deepForest,
          ),
          const SizedBox(height: 10),
          Text(
            _isRecording
                ? 'Recording... tap Send when finished.'
                : 'Record a short online chat voice note.',
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : _cancel,
          child: const Text('Cancel'),
        ),
        if (!_isRecording)
          FilledButton.icon(
            onPressed: _isBusy ? null : _start,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Record'),
          )
        else
          FilledButton.icon(
            onPressed: _isBusy ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
      ],
    );
  }
}
