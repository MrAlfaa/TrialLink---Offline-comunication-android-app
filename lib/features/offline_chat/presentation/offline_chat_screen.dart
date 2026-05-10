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
import '../../trip_context/data/trip_context_service.dart';
import 'offline_chat_controller.dart';
import 'widgets/offline_chat_input_bar.dart';
import 'widgets/offline_message_bubble.dart';

final offlineChatContextProvider = FutureProvider.autoDispose
    .family<OfflineChatContext?, OfflineChatRouteArgs>((ref, args) {
  return ref.read(tripContextServiceProvider).resolveOfflineChatContext(
        tripId: args.tripId,
        channelId: args.channelId,
        chatId: args.chatId,
      );
});

final offlineChatRouteTargetProvider = FutureProvider.autoDispose
    .family<OfflineChatRouteTarget?, String>((ref, channelId) {
  return ref
      .read(tripContextServiceProvider)
      .resolveDefaultOfflineChatRoute(channelId);
});

class OfflineChatRouteArgs {
  const OfflineChatRouteArgs({
    required this.tripId,
    required this.channelId,
    this.chatId,
  });

  final String tripId;
  final String channelId;
  final String? chatId;

  @override
  bool operator ==(Object other) {
    return other is OfflineChatRouteArgs &&
        other.tripId == tripId &&
        other.channelId == channelId &&
        other.chatId == chatId;
  }

  @override
  int get hashCode => Object.hash(tripId, channelId, chatId);
}

class OfflineChatScreen extends ConsumerStatefulWidget {
  const OfflineChatScreen({
    required this.tripId,
    required this.channelId,
    this.chatId,
    super.key,
  });

  final String tripId;
  final String channelId;
  final String? chatId;

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
    final actor = _actorFor(user, authAccess);
    if (actor == null) {
      return const Scaffold(
        body: Center(
          child: Text('Create your TrailLink profile before chatting.'),
        ),
      );
    }

    final routeArgs = OfflineChatRouteArgs(
      tripId: widget.tripId,
      channelId: widget.channelId,
      chatId: widget.chatId,
    );
    final chatContextValue = ref.watch(offlineChatContextProvider(routeArgs));
    return chatContextValue.when(
      data: (chatContext) => chatContext == null
          ? OfflineChatContextErrorScreen(
              message:
                  'This chat is not linked to the active trip. Open the trip and try again.',
              tripId: widget.tripId,
            )
          : _buildChatScaffold(context, chatContext, actor),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => OfflineChatContextErrorScreen(
        message: error.toString(),
        tripId: widget.tripId,
      ),
    );
  }

  Widget _buildChatScaffold(
    BuildContext context,
    OfflineChatContext chatContext,
    CurrentUserActor actor,
  ) {
    final resolvedChannel = chatContext.channel;
    final args = OfflineChatArgs(
      channel: resolvedChannel,
      actor: actor,
      chatId: chatContext.chat.chatId,
    );
    final state = ref.watch(offlineChatControllerProvider(args));
    final controller = ref.read(offlineChatControllerProvider(args).notifier);
    _scrollToBottom();
    final connectedCount = state.connectedPeers.length;
    final isReadOnly = chatContext.isReadOnly || !chatContext.canCompose;

    return Scaffold(
      key: const ValueKey('offline-chat-screen'),
      appBar: ChatAppBar(
        title: chatContext.trip.tripName,
        subtitle: isReadOnly
            ? 'Offline Chat - Read-only'
            : ChatModeLabel.offlineChatSubtitle(connectedCount),
        chips: [
          ChatHeaderChip(
            label: resolvedChannel.channelCode,
            color: AppColors.offlinePurple,
            icon: Icons.hub_rounded,
          ),
          ChatHeaderChip(
            label: connectedCount > 0 ? 'Nearby connected' : 'Queued',
            color: connectedCount > 0 ? AppColors.success : AppColors.warning,
            icon: connectedCount > 0
                ? Icons.bluetooth_connected_rounded
                : Icons.schedule_rounded,
          ),
        ],
        detailsTooltip: 'Channel details',
        onDetailsPressed: () =>
            context.go('/offline-channel/${resolvedChannel.channelId}'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
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
                    'This channel was ended or made read-only. Chat history is read-only.',
                color: AppColors.warning,
              ),
            Expanded(
              child: KeyedSubtree(
                key: const ValueKey('offline-chat-message-area'),
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.messages.isEmpty
                        ? const _EmptyOfflineChat()
                        : RefreshIndicator(
                            onRefresh: controller.refresh,
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
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
            ),
            isReadOnly
                ? const _OfflineChatReadOnlyBar()
                : OfflineChatInputBar(
                    isSending: state.isSending,
                    queueHint: connectedCount == 0
                        ? 'No peers connected. Messages will be queued.'
                        : null,
                    onSend: controller.sendText,
                  ),
          ],
        ),
      ),
    );
  }
}

class OfflineChatRouteResolverScreen extends ConsumerWidget {
  const OfflineChatRouteResolverScreen({
    required this.channelId,
    super.key,
  });

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetValue = ref.watch(offlineChatRouteTargetProvider(channelId));
    return targetValue.when(
      data: (target) {
        if (target == null) {
          return const OfflineChatContextErrorScreen(
            message:
                'Offline chat is not linked to an active trip. Open Messages and activate the trip first.',
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.replace(target.location);
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => OfflineChatContextErrorScreen(
        message: error.toString(),
      ),
    );
  }
}

class OfflineChatContextErrorScreen extends StatelessWidget {
  const OfflineChatContextErrorScreen({
    required this.message,
    this.tripId,
    super.key,
  });

  final String message;
  final String? tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('offline-chat-context-error'),
      appBar: AppBar(title: const Text('Offline Chat')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.warning,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('offline-chat-open-trip-button'),
                onPressed: () => context.go('/trips'),
                icon: const Icon(Icons.route_rounded),
                label: const Text('Open Trip'),
              ),
              TextButton(
                onPressed: () => context.go('/chat?tab=offline'),
                child: const Text('Back to Messages'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineChatReadOnlyBar extends StatelessWidget {
  const _OfflineChatReadOnlyBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey('offline-chat-readonly-bar'),
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'This channel has ended. Message history is read-only.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w900,
              ),
        ),
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
      key: const ValueKey('offline-chat-empty-state'),
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
