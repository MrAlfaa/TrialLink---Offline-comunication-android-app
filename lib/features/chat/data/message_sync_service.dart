import 'dart:convert';

import 'chat_api.dart';
import 'message_dao.dart';

class MessageSyncService {
  MessageSyncService({
    ChatApi? api,
    MessageDao? dao,
  })  : _api = api ?? ChatApi(),
        _dao = dao ?? MessageDao();

  final ChatApi _api;
  final MessageDao _dao;

  Future<void> syncPendingMessages() async {
    final rows = await _dao.pendingSyncRows();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final payload =
          jsonDecode(row['payload_json'].toString()) as Map<String, dynamic>;
      final groupId = payload['groupId']?.toString();
      if (groupId == null || groupId.isEmpty) continue;
      grouped.putIfAbsent(groupId, () => []).add(payload);
    }

    for (final entry in grouped.entries) {
      await _syncGroup(entry.key, entry.value);
    }
  }

  Future<void> _syncGroup(
      String groupId, List<Map<String, dynamic>> payloads) async {
    try {
      final messages = payloads
          .map(
            (payload) => {
              'clientMessageId': payload['clientMessageId'],
              'content': payload['content'],
              'messageType': payload['messageType'] ?? 'text',
              'createdAt': payload['createdAt'],
              if (payload['tripId'] != null) 'tripId': payload['tripId'],
              if (payload['channelId'] != null)
                'channelId': payload['channelId'],
              if (payload['chatId'] != null) 'chatId': payload['chatId'],
            },
          )
          .toList();
      final synced =
          await _api.syncPendingMessages(groupId: groupId, messages: messages);

      for (final item in synced) {
        final clientMessageId = item['clientMessageId']?.toString();
        if (clientMessageId == null) continue;
        await _dao.updateDeliveryStatus(
          clientMessageId: clientMessageId,
          serverId: item['serverMessageId']?.toString(),
          deliveryStatus: 'synced',
        );
        await _dao.markQueuesCompleted(clientMessageId);
      }
    } catch (error) {
      for (final payload in payloads) {
        final clientMessageId = payload['clientMessageId']?.toString();
        if (clientMessageId == null) continue;
        await _dao.markQueueFailed(clientMessageId, error.toString());
        await _dao.updateDeliveryStatus(
          clientMessageId: clientMessageId,
          deliveryStatus: 'failed',
          syncState: 'needs_sync',
        );
      }
    }
  }
}
