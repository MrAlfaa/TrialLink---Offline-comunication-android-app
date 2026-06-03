class ChatModeLabel {
  const ChatModeLabel._();

  static String cloudChatSubtitle({
    required bool isOnline,
    required String socketState,
  }) {
    if (!isOnline) return 'Offline Chat';
    return switch (socketState) {
      'connected' => 'Online Chat',
      'connecting' => 'Online Chat - connecting',
      'reconnecting' => 'Online Chat - connecting',
      'error' => 'Online Chat - waiting for connection',
      'disconnected' => 'Online Chat - waiting for connection',
      _ => 'Online Chat - waiting for connection',
    };
  }

  static String offlineChatSubtitle(int connectedPeerCount) {
    final peers = connectedPeerCount == 1
        ? '1 phone nearby'
        : '$connectedPeerCount phones nearby';
    return 'Offline Chat - $peers';
  }
}
