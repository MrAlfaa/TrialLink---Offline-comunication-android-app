import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../trip_context/data/trip_context_service.dart';
import '../data/socket_service.dart';
import 'chat_mode_label.dart';
import 'chat_controller.dart';
import 'widgets/chat_app_bar.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/empty_chat_state.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.groupId,
    required this.groupName,
    super.key,
  });

  final String groupId;
  final String groupName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Cloud chat requires a synced TrailLink profile.'),
        ),
      );
    }

    final activeContext = ref.watch(activeTripContextProvider).asData?.value;
    final activeChat =
        activeContext?.cloudGroupId == widget.groupId ? activeContext : null;
    final args = ChatSessionArgs(
      groupId: widget.groupId,
      groupName: widget.groupName,
      currentUser: user,
      tripId: activeChat?.trip.tripId,
      channelId: activeChat?.activeChannel?.channelId,
      chatId: activeChat?.activeChat?.chatId,
    );
    final state = ref.watch(chatControllerProvider(args));
    final controller = ref.read(chatControllerProvider(args).notifier);
    _scrollToBottom();

    return Scaffold(
      appBar: ChatAppBar(
        title: widget.groupName,
        subtitle: _chatSubtitle(state),
        chips: _chatHeaderChips(state),
        onDetailsPressed: () => context.go('/groups/${widget.groupId}'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (state.errorMessage != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.warning.withValues(alpha: 0.12),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.warning),
                ),
              ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: state.messages.isEmpty
                          ? const CustomScrollView(
                              physics: AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverFillRemaining(child: EmptyChatState()),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) {
                                final message = state.messages[index];
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                      milliseconds: 180 + (index % 4) * 45),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 12 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: MessageBubble(
                                    message: message,
                                    onRetry: () =>
                                        controller.retryMessage(message),
                                    onPlayMedia: () =>
                                        controller.playMedia(message),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
            ChatInputBar(
              onSend: controller.sendMessage,
              onPickImage: controller.sendImageFromGallery,
              onStartVoiceRecording: controller.startVoiceRecording,
              onStopVoiceRecording: controller.stopAndSendVoiceNote,
              onCancelVoiceRecording: controller.cancelVoiceRecording,
              isOnlineMediaAvailable: state.isOnline &&
                  state.socketStatus == ChatSocketStatus.connected,
              offlineHint: state.isOnline
                  ? null
                  : 'Media is online-only. Offline mode supports text and voice-note PTT.',
            ),
          ],
        ),
      ),
    );
  }
}

String _chatSubtitle(ChatState state) {
  return ChatModeLabel.cloudChatSubtitle(
    isOnline: state.isOnline,
    socketState: state.socketStatus.name,
  );
}

List<ChatHeaderChip> _chatHeaderChips(ChatState state) {
  final pending = state.messages
      .where(
        (message) =>
            message.deliveryStatus == 'pending' ||
            message.deliveryStatus == 'sending' ||
            message.deliveryStatus == 'failed' ||
            message.syncState == 'needs_sync',
      )
      .length;
  return [
    if (!state.isOnline ||
        state.socketStatus == ChatSocketStatus.disconnected ||
        state.socketStatus == ChatSocketStatus.error)
      const ChatHeaderChip(
        label: 'Saved locally',
        color: AppColors.offlinePurple,
        icon: Icons.save_rounded,
      )
    else
      const ChatHeaderChip(
        label: 'Online',
        color: AppColors.success,
        icon: Icons.cloud_done_rounded,
      ),
    if (pending > 0)
      ChatHeaderChip(
        label: '$pending pending',
        color: AppColors.warning,
        icon: Icons.schedule_rounded,
      ),
  ];
}
