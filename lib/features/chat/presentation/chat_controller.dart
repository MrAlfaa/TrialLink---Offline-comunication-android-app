import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/app_connection_mode.dart';
import '../../../core/connectivity/send_path_decider.dart';
import '../../../core/mode/mode_controller.dart';
import '../../../core/mode/mode_models.dart';
import '../../auth/data/models/user_model.dart';
import '../../bridge/data/bridge_engine.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/presentation/group_controller.dart';
import '../data/chat_repository.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/send_message_request.dart';
import '../data/socket_service.dart';

class ChatSessionArgs {
  const ChatSessionArgs({
    required this.groupId,
    required this.groupName,
    required this.currentUser,
    this.tripId,
    this.channelId,
    this.chatId,
  });

  final String groupId;
  final String groupName;
  final UserModel currentUser;
  final String? tripId;
  final String? channelId;
  final String? chatId;

  @override
  bool operator ==(Object other) {
    return other is ChatSessionArgs &&
        other.groupId == groupId &&
        other.tripId == tripId &&
        other.channelId == channelId &&
        other.chatId == chatId &&
        other.currentUser.id == currentUser.id;
  }

  @override
  int get hashCode =>
      Object.hash(groupId, currentUser.id, tripId, channelId, chatId);
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.socketStatus = ChatSocketStatus.disconnected,
    this.connectionMode = AppConnectionMode.reconnecting,
    this.isLoading = true,
    this.isOnline = true,
    this.errorMessage,
  });

  final List<ChatMessageModel> messages;
  final ChatSocketStatus socketStatus;
  final AppConnectionMode connectionMode;
  final bool isLoading;
  final bool isOnline;
  final String? errorMessage;

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    ChatSocketStatus? socketStatus,
    AppConnectionMode? connectionMode,
    bool? isLoading,
    bool? isOnline,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      socketStatus: socketStatus ?? this.socketStatus,
      connectionMode: connectionMode ?? this.connectionMode,
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    required this.args,
    required ChatRepository repository,
    required SocketService socketService,
    required ModeState initialModeState,
    required BridgeEngine bridgeEngine,
    required GroupRepository groupRepository,
  })  : _repository = repository,
        _socketService = socketService,
        _bridgeEngine = bridgeEngine,
        _groupRepository = groupRepository,
        _modeState = initialModeState,
        super(
          ChatState(
            connectionMode: initialModeState.compatibilityConnectionMode,
            isOnline: initialModeState.effectiveMode == EffectiveMode.online,
          ),
        ) {
    _init();
  }

  final ChatSessionArgs args;
  final ChatRepository _repository;
  final SocketService _socketService;
  final BridgeEngine _bridgeEngine;
  final GroupRepository _groupRepository;
  ModeState _modeState;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Future<void> _init() async {
    _subscriptions
      ..add(_socketService.statusStream.listen(_onSocketStatus))
      ..add(_socketService.messageStream.listen(_onIncomingMessage))
      ..add(_socketService.ackStream.listen(_onAck))
      ..add(_socketService.errorStream.listen(_onSocketError))
      ..add(_socketService.groupArchivedStream.listen(_onGroupArchived));

    final localMessages = await _repository.loadLocalMessages(args.groupId);
    if (!mounted) return;
    state = state.copyWith(messages: localMessages, isLoading: false);

    await _refreshHistory();
    if (state.connectionMode == AppConnectionMode.online) {
      await _connectSocketAndSync();
    }
  }

  Future<void> refresh() async {
    await _refreshHistory();
    await _syncPending();
  }

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final message = await _repository.createLocalOutgoingMessage(
      groupId: args.groupId,
      tripId: args.tripId,
      channelId: args.channelId,
      chatId: args.chatId,
      currentUser: args.currentUser,
      content: trimmed,
    );
    _replaceMessages([...state.messages, message]);
    unawaited(_bridgeEngine.bridgeOnlineMessageToOffline(message));

    final sendPath = SendPathDecider.decideForMode(
      modeState: _modeState,
      socketConnected: _socketService.isConnected,
    );
    if (sendPath == SendPath.localQueueOnly ||
        sendPath == SendPath.offlineNearby ||
        sendPath == SendPath.hybridQueue) {
      return;
    }

    try {
      if (!_socketService.isConnected) {
        await _socketService.connect();
        _socketService.joinGroup(args.groupId);
      }
      if (!_socketService.isConnected) return;
      await _repository.markSending(message.clientMessageId);
      _updateLocalStatus(message.clientMessageId, 'sending');
      _socketService.sendGroupMessage(
        SendMessageRequest(
          clientMessageId: message.clientMessageId,
          groupId: args.groupId,
          tripId: args.tripId,
          channelId: args.channelId,
          chatId: args.chatId,
          content: message.content,
          createdAt: message.createdAt,
        ),
      );
    } catch (error) {
      await _repository.markFailed(message.clientMessageId, error.toString());
      _updateLocalStatus(message.clientMessageId, 'failed');
    }
  }

  Future<void> retryMessage(ChatMessageModel message) async {
    if (message.isMedia) {
      await _uploadMediaAndRefresh(message);
      return;
    }
    final sendPath = SendPathDecider.decideForMode(
      modeState: _modeState,
      socketConnected: _socketService.isConnected,
    );
    if (sendPath == SendPath.localQueueOnly ||
        sendPath == SendPath.offlineNearby ||
        sendPath == SendPath.hybridQueue) {
      return;
    }
    await _repository.markSending(message.clientMessageId);
    _updateLocalStatus(message.clientMessageId, 'sending');
    if (_socketService.isConnected) {
      _socketService.sendGroupMessage(
        SendMessageRequest(
          clientMessageId: message.clientMessageId,
          groupId: message.groupId,
          tripId: message.tripId,
          channelId: message.channelId,
          chatId: message.chatId,
          content: message.content,
          createdAt: message.createdAt,
        ),
      );
    } else {
      await _syncPending();
    }
  }

  Future<void> sendImageFromGallery() async {
    if (!_canSendMedia) {
      state = state.copyWith(
        errorMessage:
            'Media sharing is online-only to avoid heavy offline transfer.',
      );
      return;
    }
    try {
      final message = await _repository.createLocalImageMessage(
        groupId: args.groupId,
        tripId: args.tripId,
        channelId: args.channelId,
        chatId: args.chatId,
        currentUser: args.currentUser,
      );
      if (message == null) return;
      _replaceMessages([...state.messages, message]);
      await _uploadMediaAndRefresh(message);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> startVoiceRecording() async {
    if (!_canSendMedia) {
      state = state.copyWith(
        errorMessage:
            'Media sharing is online-only to avoid heavy offline transfer.',
      );
      return;
    }
    await _repository.startVoiceRecording();
  }

  Future<void> cancelVoiceRecording() {
    return _repository.cancelVoiceRecording();
  }

  Future<void> stopAndSendVoiceNote() async {
    if (!_canSendMedia) return;
    try {
      final message = await _repository.stopAndCreateLocalVoiceMessage(
        groupId: args.groupId,
        tripId: args.tripId,
        channelId: args.channelId,
        chatId: args.chatId,
        currentUser: args.currentUser,
      );
      if (message == null) return;
      _replaceMessages([...state.messages, message]);
      await _uploadMediaAndRefresh(message);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> playMedia(ChatMessageModel message) async {
    try {
      await _repository.playMedia(message);
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  Future<void> _refreshHistory() async {
    try {
      final messages = await _repository.refreshHistory(
        groupId: args.groupId,
        currentUser: args.currentUser,
      );
      if (!mounted) return;
      _replaceMessages(messages);
    } catch (error) {
      if (!mounted) return;
      state =
          state.copyWith(errorMessage: 'Chat history is using local messages.');
    }
  }

  Future<void> _syncPending() async {
    try {
      await _repository.syncPendingMessages();
      final messages = await _repository.loadLocalMessages(args.groupId);
      if (!mounted) return;
      _replaceMessages(messages);
    } catch (_) {
      // Pending messages remain in SQLite and will be retried later.
    }
  }

  Future<void> _uploadMediaAndRefresh(ChatMessageModel message) async {
    if (!_canSendMedia) return;
    _updateLocalStatus(message.clientMessageId, 'sending');
    try {
      await _repository.uploadMediaMessage(message);
      final messages = await _repository.loadLocalMessages(args.groupId);
      if (!mounted) return;
      _replaceMessages(messages);
    } catch (error) {
      await _repository.markFailed(message.clientMessageId, error.toString());
      if (!mounted) return;
      _updateLocalStatus(message.clientMessageId, 'failed');
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  void _onSocketStatus(ChatSocketStatus status) {
    if (!mounted) return;
    state = state.copyWith(socketStatus: status);
    if (status == ChatSocketStatus.connected) {
      _socketService.joinGroup(args.groupId);
      unawaited(_syncPending());
    }
  }

  Future<void> _onIncomingMessage(Map<String, dynamic> data) async {
    final message = ChatMessageModel.fromApiJson(
      data,
      currentUserId: args.currentUser.id,
    );
    if (message.groupId != args.groupId) return;
    await _repository.upsertIncoming(message);
    unawaited(_bridgeEngine.bridgeOnlineMessageToOffline(message));
    final messages = await _repository.loadLocalMessages(args.groupId);
    if (!mounted) return;
    _replaceMessages(messages);
  }

  Future<void> _onAck(Map<String, dynamic> data) async {
    final clientMessageId = data['clientMessageId']?.toString();
    if (clientMessageId == null) return;
    await _repository.markAck(
      clientMessageId: clientMessageId,
      serverId: data['serverMessageId']?.toString(),
    );
    final messages = await _repository.loadLocalMessages(args.groupId);
    if (!mounted) return;
    _replaceMessages(messages);
  }

  void _onSocketError(Map<String, dynamic> data) {
    if (!mounted) return;
    state = state.copyWith(
        errorMessage: data['message']?.toString() ?? 'Socket error');
  }

  Future<void> _onGroupArchived(Map<String, dynamic> data) async {
    final groupId = data['groupId']?.toString();
    if (groupId == null || groupId != args.groupId) return;
    await _groupRepository.markGroupArchivedFromSocket(groupId);
    if (!mounted) return;
    state = state.copyWith(
      errorMessage: 'This group was ended by the owner. Chat is read-only.',
    );
  }

  void onModeChanged(ModeState modeState) {
    if (!mounted) return;
    _modeState = modeState;
    state = state.copyWith(
      connectionMode: modeState.compatibilityConnectionMode,
      isOnline: modeState.effectiveMode == EffectiveMode.online,
    );
    if (modeState.effectiveMode == EffectiveMode.online &&
        modeState.backendReachable) {
      unawaited(_connectSocketAndSync());
    }
  }

  Future<void> _connectSocketAndSync() async {
    await _socketService.connect();
    _socketService.joinGroup(args.groupId);
    await _syncPending();
  }

  void _replaceMessages(List<ChatMessageModel> messages) {
    final sorted = [...messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: sorted, clearError: true);
  }

  void _updateLocalStatus(String clientMessageId, String status) {
    final updated = state.messages.map((message) {
      if (message.clientMessageId != clientMessageId) return message;
      return message.copyWith(deliveryStatus: status);
    }).toList();
    _replaceMessages(updated);
  }

  bool get _canSendMedia =>
      _modeState.effectiveMode == EffectiveMode.online &&
      _modeState.backendReachable &&
      state.isOnline;

  @override
  void dispose() {
    _socketService.leaveGroup(args.groupId);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, ChatState, ChatSessionArgs>(
  (ref, args) {
    final controller = ChatController(
      args: args,
      repository: ref.read(chatRepositoryProvider),
      socketService: ref.read(socketServiceProvider),
      initialModeState: ref.read(modeControllerProvider),
      bridgeEngine: ref.read(bridgeEngineProvider),
      groupRepository: ref.read(groupRepositoryProvider),
    );
    ref.listen(modeControllerProvider, (_, next) {
      controller.onModeChanged(next);
    });
    return controller;
  },
);
