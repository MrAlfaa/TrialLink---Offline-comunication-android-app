class ChatModeLabel {
  const ChatModeLabel._();

  static String cloudChatSubtitle({
    required bool isOnline,
    required String socketState,
  }) {
    if (!isOnline) return 'Offline Chat';
    return switch (socketState) {
      'connected' => 'Online Chat',
      'connecting' => 'Online Chat',
      'reconnecting' => 'Offline Chat - Saved locally',
      'error' => 'Offline Chat - Saved locally',
      'disconnected' => 'Offline Chat - Saved locally',
      _ => 'Offline Chat - Saved locally',
    };
  }

  static String offlineChatSubtitle(int connectedPeerCount) {
    final peers = connectedPeerCount == 1
        ? '1 peer nearby'
        : '$connectedPeerCount peers nearby';
    return 'Offline Chat - $peers';
  }
}
