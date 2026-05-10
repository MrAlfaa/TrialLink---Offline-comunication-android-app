class SendMessageRequest {
  const SendMessageRequest({
    required this.clientMessageId,
    required this.groupId,
    required this.content,
    required this.createdAt,
    this.tripId,
    this.channelId,
    this.chatId,
    this.messageType = 'text',
  });

  final String clientMessageId;
  final String groupId;
  final String content;
  final DateTime createdAt;
  final String? tripId;
  final String? channelId;
  final String? chatId;
  final String messageType;

  Map<String, dynamic> toJson() {
    return {
      'clientMessageId': clientMessageId,
      'groupId': groupId,
      if (tripId != null) 'tripId': tripId,
      if (channelId != null) 'channelId': channelId,
      if (chatId != null) 'chatId': chatId,
      'content': content,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
