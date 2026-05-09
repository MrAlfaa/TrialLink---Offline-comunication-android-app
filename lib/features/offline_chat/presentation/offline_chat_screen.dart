import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/identity/auth_access_controller.dart';
import '../../../core/identity/current_user_actor.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/presentation/chat_mode_label.dart';
import '../../chat/presentation/widgets/chat_app_bar.dart';
import '../../offline_channel/presentation/offline_channel_controller.dart';
import 'offline_chat_controller.dart';
import 'widgets/offline_chat_input_bar.dart';
import 'widgets/offline_message_bubble.dart';

class OfflineChatScreen extends ConsumerStatefulWidget {
  const OfflineChatScreen({
    required this.channelId,
    super.key,
  });

  final String channelId;

  @override
  ConsumerState<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends ConsumerState<OfflineChatScreen> {
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
    final authAccess = ref.watch(authAccessControllerProvider);
    final channelValue =
        ref.watch(offlineChannelDetailsProvider(widget.channelId));

    return channelValue.when(
      data: (channel) {
        final actor = _actorFor(user, authAccess);
        if (actor == null) {
          return const Scaffold(
            body: Center(
              child: Text('Create your TrailLink profile before chatting.'),
            ),
          );
        }
        if (channel == null) {
          return const Scaffold(
            body: Center(child: Text('Offline channel not found.')),
          );
        }

        final args = OfflineChatArgs(channel: channel, actor: actor);
        final state = ref.watch(offlineChatControllerProvider(args));
        final controller =
            ref.read(offlineChatControllerProvider(args).notifier);
        _scrollToBottom();
        final connectedCount = state.connectedPeers.length;
        final isReadOnly = channel.isEnded;

        return Scaffold(
          appBar: ChatAppBar(
            title: channel.channelName,
            subtitle: isReadOnly
                ? 'Offline Chat - Read-only'
                : ChatModeLabel.offlineChatSubtitle(connectedCount),
            chips: [
              ChatHeaderChip(
                label: channel.channelCode,
                color: AppColors.offlinePurple,
                icon: Icons.hub_rounded,
              ),
              ChatHeaderChip(
                label: connectedCount > 0 ? 'Nearby connected' : 'Queued',
                color:
                    connectedCount > 0 ? AppColors.success : AppColors.warning,
                icon: connectedCount > 0
                    ? Icons.bluetooth_connected_rounded
                    : Icons.schedule_rounded,
              ),
            ],
            onDetailsPressed: () =>
                context.go('/offline-channel/${channel.channelId}'),
            detailsTooltip: 'Channel details',
          ),
          body: Column(
            children: [
              if (state.infoMessage != null)
                _MessageStrip(
                  message: state.infoMessage!,
                  color: AppColors.success,
                ),
              if (state.errorMessage != null)
                _MessageStrip(
                  message: state.errorMessage!,
                  color: AppColors.danger,
                ),
              if (isReadOnly)
                const _MessageStrip(
                  message:
                      'This channel was ended by the owner. Chat history is read-only.',
                  color: AppColors.warning,
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
                                  SliverFillRemaining(
                                    child: _EmptyOfflineChat(),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(0, 12, 0, 18),
                                itemCount: state.messages.length,
                                itemBuilder: (context, index) {
                                  final message = state.messages[index];
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(
                                      milliseconds: 160 + (index % 4) * 35,
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) => Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 10 * (1 - value)),
                                        child: child,
                                      ),
                                    ),
                                    child: OfflineMessageBubble(
                                      message: message,
                                      onRetry: () =>
                                          controller.retryMessage(message),
                                    ),
                                  );
                                },
                              ),
                      ),
              ),
              OfflineChatInputBar(
                isSending: state.isSending,
                enabled: !isReadOnly,
                disabledMessage:
                    'This channel was ended by the owner. Chat history is read-only.',
                onSend: controller.sendText,
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text(error.toString())),
      ),
    );
  }
}

CurrentUserActor? _actorFor(
  UserModel? user,
  AuthAccessStatus authAccess,
) {
  try {
    return CurrentUserActor.fromAuthAccess(authAccess);
  } catch (_) {
    return user == null ? null : CurrentUserActor.fromUserModel(user);
  }
}

class _MessageStrip extends StatelessWidget {
  const _MessageStrip({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyOfflineChat extends StatelessWidget {
  const _EmptyOfflineChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 54, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(
              'No offline messages yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Messages are saved locally first and sent when a nearby peer is connected.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
