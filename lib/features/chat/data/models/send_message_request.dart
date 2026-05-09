class SendMessageRequest {
  const SendMessageRequest({
    required this.clientMessageId,
    required this.groupId,
    required this.content,
    required this.createdAt,
    this.messageType = 'text',
  });

  final String clientMessageId;
  final String groupId;
  final String content;
  final DateTime createdAt;
  final String messageType;

  Map<String, dynamic> toJson() {
    return {
      'clientMessageId': clientMessageId,
      'groupId': groupId,
      'content': content,
      'messageType': messageType,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
