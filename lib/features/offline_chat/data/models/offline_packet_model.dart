import 'dart:convert';

class OfflinePacketModel {
  const OfflinePacketModel({
    required this.packetId,
    required this.packetType,
    required this.channelId,
    required this.channelCode,
    required this.senderId,
    required this.senderName,
    required this.targetType,
    required this.targetId,
    required this.payload,
    required this.createdAt,
    this.tripId,
    this.chatId,
    this.senderLocalId,
    this.senderBackendId,
    this.identityType = 'authenticated_cached',
    this.sourcePath = 'offline',
    this.priority = 'normal',
    this.ttl = 5,
    this.hopCount = 0,
    this.requiresAck = true,
  });

  final String packetId;
  final String packetType;
  final String channelId;
  final String channelCode;
  final String senderId;
  final String? tripId;
  final String? chatId;
  final String? senderLocalId;
  final String? senderBackendId;
  final String senderName;
  final String identityType;
  final String sourcePath;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> payload;
  final String priority;
  final int ttl;
  final int hopCount;
  final DateTime createdAt;
  final bool requiresAck;

  String? get messageId => payload['messageId']?.toString();
  String? get content => payload['content']?.toString();
  String? get ackForPacketId => payload['ackForPacketId']?.toString();
  String? get ackForMessageId => payload['ackForMessageId']?.toString();
  String get originLocalId =>
      payload['originLocalId']?.toString() ?? senderLocalId ?? senderId;
  String get originDisplayName =>
      payload['originDisplayName']?.toString() ?? senderName;
  String? get clientMessageId =>
      payload['clientMessageId']?.toString() ?? messageId;
  String? get localEventId => payload['localEventId']?.toString();
  String? get localLocationId => payload['localLocationId']?.toString();
  String? get localVoiceId => payload['localVoiceId']?.toString();

  factory OfflinePacketModel.fromJsonString(String value) {
    final data = jsonDecode(value) as Map<String, dynamic>;
    return OfflinePacketModel.fromJson(data);
  }

  factory OfflinePacketModel.fromJson(Map<String, dynamic> data) {
    return OfflinePacketModel(
      packetId: data['packetId'].toString(),
      packetType: data['packetType']?.toString() ?? 'text',
      channelId: data['channelId'].toString(),
      channelCode: data['channelCode'].toString(),
      senderId:
          (data['senderBackendId'] ?? data['senderId'] ?? data['senderLocalId'])
              .toString(),
      senderName: data['senderName']?.toString() ?? 'TrailLink User',
      tripId: data['tripId']?.toString(),
      chatId:
          data['chatId']?.toString() ?? data['payload']?['chatId']?.toString(),
      senderLocalId:
          data['senderLocalId']?.toString() ?? data['senderId']?.toString(),
      senderBackendId: data['senderBackendId']?.toString(),
      identityType: data['identityType']?.toString() ?? 'authenticated_cached',
      sourcePath: data['sourcePath']?.toString() ?? 'offline',
      targetType: data['targetType']?.toString() ?? 'channel',
      targetId: data['targetId']?.toString() ?? data['channelId'].toString(),
      payload: Map<String, dynamic>.from(data['payload'] as Map? ?? {}),
      priority: data['priority']?.toString() ?? 'normal',
      ttl: int.tryParse(data['ttl']?.toString() ?? '') ?? 5,
      hopCount: int.tryParse(data['hopCount']?.toString() ?? '') ?? 0,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      requiresAck: data['requiresAck'] != false,
    );
  }

  OfflinePacketModel relayCopy() {
    return OfflinePacketModel(
      packetId: packetId,
      packetType: packetType,
      channelId: channelId,
      channelCode: channelCode,
      senderId: senderId,
      senderName: senderName,
      tripId: tripId,
      chatId: chatId,
      senderLocalId: senderLocalId,
      senderBackendId: senderBackendId,
      identityType: identityType,
      sourcePath: sourcePath,
      targetType: targetType,
      targetId: targetId,
      payload: payload,
      priority: priority,
      ttl: ttl - 1,
      hopCount: hopCount + 1,
      createdAt: createdAt,
      requiresAck: requiresAck,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packetId': packetId,
      'packetType': packetType,
      'channelId': channelId,
      'channelCode': channelCode,
      'senderId': senderId,
      'tripId': tripId,
      'chatId': chatId,
      'senderLocalId': senderLocalId ?? senderId,
      if (senderBackendId != null) 'senderBackendId': senderBackendId,
      'senderName': senderName,
      'identityType': identityType,
      'sourcePath': sourcePath,
      'targetType': targetType,
      'targetId': targetId,
      'payload': payload,
      'priority': priority,
      'ttl': ttl,
      'hopCount': hopCount,
      'createdAt': createdAt.toIso8601String(),
      'requiresAck': requiresAck,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}
