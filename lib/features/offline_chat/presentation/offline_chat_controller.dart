import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/current_user_actor.dart';
import '../../nearby/data/models/nearby_peer_model.dart';
import '../../nearby/presentation/nearby_controller.dart';
import '../../offline_channel/data/models/offline_channel_model.dart';
import '../data/models/offline_text_message_model.dart';
import '../data/offline_chat_repository.dart';

class OfflineChatArgs {
  const OfflineChatArgs({
    required this.channel,
    required this.actor,
    this.chatId,
  });

  final OfflineChannelModel channel;
  final CurrentUserActor actor;
  final String? chatId;
  CurrentUserActor get user => actor;

  @override
  bool operator ==(Object other) {
    return other is OfflineChatArgs &&
        other.channel.channelId == channel.channelId &&
        other.chatId == chatId &&
        other.actor.localUserId == actor.localUserId;
  }

  @override
  int get hashCode => Object.hash(channel.channelId, actor.localUserId, chatId);
}

class OfflineChatState {
  const OfflineChatState({
    this.messages = const [],
    this.connectedPeers = const [],
    this.isLoading = true,
    this.isSending = false,
    this.infoMessage,
    this.errorMessage,
  });

  final List<OfflineTextMessageModel> messages;
  final List<NearbyPeerModel> connectedPeers;
  final bool isLoading;
  final bool isSending;
  final String? infoMessage;
  final String? errorMessage;

  OfflineChatState copyWith({
    List<OfflineTextMessageModel>? messages,
    List<NearbyPeerModel>? connectedPeers,
    bool? isLoading,
    bool? isSending,
    String? infoMessage,
    String? errorMessage,
    bool clearMessages = false,
  }) {
    return OfflineChatState(
      messages: messages ?? this.messages,
      connectedPeers: connectedPeers ?? this.connectedPeers,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      infoMessage: clearMessages ? null : infoMessage ?? this.infoMessage,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OfflineChatController extends StateNotifier<OfflineChatState> {
  OfflineChatController({
    required this.args,
    required OfflineChatRepository repository,
  })  : _repository = repository,
        super(const OfflineChatState()) {
    _init();
  }

  final OfflineChatArgs args;
  final OfflineChatRepository _repository;
  Timer? _peerRefreshTimer;
  final Map<String, Timer> _ackTimers = {};

  Future<void> _init() async {
    _peerRefreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refresh(),
    );
    await refresh();
    await flushQueuedPackets();
  }

  Future<void> refresh() async {
    final messages = await _repository.loadMessages(args.channel.channelId);
    final peers = await _repository.connectedPeers(args.channel.channelCode);
    if (!mounted) return;
    state = state.copyWith(
      messages: messages,
      connectedPeers: peers,
      isLoading: false,
      clearMessages: true,
    );
  }

  Future<void> refreshPeers() async {
    final peers = await _repository.connectedPeers(args.channel.channelCode);
    if (!mounted) return;
    state = state.copyWith(connectedPeers: peers);
  }

  Future<void> sendText(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 1000) {
      state = state.copyWith(
        errorMessage: 'Offline messages must be 1000 characters or less.',
      );
      return;
    }

    state = state.copyWith(isSending: true, clearMessages: true);
    try {
      final message = await _repository.createOutgoing(
        channel: args.channel,
        actor: args.actor,
        content: trimmed,
        chatId: args.chatId,
      );
      state = state.copyWith(messages: [...state.messages, message]);
      await _repository.sendMessagePacket(
        message: message,
        channel: args.channel,
      );
      _scheduleAckTimeout(message.messageId);
      await refresh();
      final hasPeers = state.connectedPeers.isNotEmpty;
      state = state.copyWith(
        isSending: false,
        infoMessage: hasPeers
            ? 'Message sent to nearby peers.'
            : 'Message saved. It will be sent when a peer connects.',
      );
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> retryMessage(OfflineTextMessageModel message) async {
    await _repository.sendMessagePacket(
      message: message,
      channel: args.channel,
    );
    await refresh();
  }

  Future<void> flushQueuedPackets() async {
    await refreshPeers();
    await _repository.sendQueuedPackets(channel: args.channel);
    await refresh();
  }

  void _scheduleAckTimeout(String messageId) {
    _ackTimers[messageId]?.cancel();
    _ackTimers[messageId] = Timer(const Duration(seconds: 15), () async {
      await _repository.markAckTimeoutIfStillWaiting(messageId);
      await refresh();
    });
  }

  @override
  void dispose() {
    _peerRefreshTimer?.cancel();
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

final offlineChatRepositoryProvider = Provider<OfflineChatRepository>((ref) {
  return OfflineChatRepository(
    nearbyRepository: ref.watch(nearbyRepositoryProvider),
  );
});

final offlineChatControllerProvider = StateNotifierProvider.autoDispose
    .family<OfflineChatController, OfflineChatState, OfflineChatArgs>(
  (ref, args) {
    return OfflineChatController(
      args: args,
      repository: ref.watch(offlineChatRepositoryProvider),
    );
  },
);
