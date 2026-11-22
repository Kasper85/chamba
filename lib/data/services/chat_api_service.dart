import 'api_client.dart';
import '../models/chat_message.dart';

class ChatSnapshot {
  final bool closed;
  final List<ChatMessage> messages;
  final List<String> receivedIds;
  const ChatSnapshot(this.closed, this.messages, this.receivedIds);
}

class ChatApiService {
  final ApiClient api;
  ChatApiService({ApiClient? apiClient}) : api = apiClient ?? ApiClient();
  Future<ChatSnapshot> load(String jobId, String token) async {
    final response = await api.get(
      '/api/v1/jobs/$jobId/messages',
      token: token,
    );
    final body = response.data as Map<String, dynamic>;
    return ChatSnapshot(
      body['closed'] == true,
      (body['messages'] as List).map((raw) {
        final m = raw as Map<String, dynamic>;
        return ChatMessage(
          id: m['clientMessageId'] as String,
          jobId: jobId,
          senderId: m['senderId'] as String,
          senderName: m['senderName'] as String,
          isFromWorker: m['isFromWorker'] == true,
          text: m['text'] as String,
          audioBase64: m['audioBase64'] as String?,
          audioDurationSeconds: m['audioDurationSeconds'] as int?,
          timestamp: DateTime.parse(m['createdAt'] as String).toLocal(),
          deliveryStatus: m['deliveredAt'] == null
              ? MessageDeliveryStatus.sent
              : MessageDeliveryStatus.delivered,
        );
      }).toList(),
      (body['messages'] as List)
          .map((m) => (m as Map)['id'])
          .whereType<String>()
          .toList(),
    );
  }

  Future<void> send(
    String jobId,
    String token,
    String id,
    String text, {
    String? audioBase64,
    int? audioDurationSeconds,
  }) async {
    await api.post(
      '/api/v1/jobs/$jobId/messages',
      token: token,
      body: {
        'clientMessageId': id,
        'text': text,
        'audioBase64': ?audioBase64,
        'audioDurationSeconds': ?audioDurationSeconds,
      },
    );
  }

  Future<void> delivered(String jobId, String token, List<String> ids) async {
    for (var offset = 0; offset < ids.length; offset += 500) {
      await api.post(
        '/api/v1/jobs/$jobId/messages/delivered',
        token: token,
        body: {'messageIds': ids.skip(offset).take(500).toList()},
      );
    }
  }
}
