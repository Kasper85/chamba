import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/services/chat_api_service.dart';
import 'package:chamba/data/models/chat_message.dart';

void main() {
  test('loads server messages with sender and actual delivery state', () async {
    final api = ChatApiService(
      apiClient: ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          return http.Response(
            jsonEncode({
              'closed': false,
              'messages': [
                {
                  'clientMessageId': 'retry-id',
                  'senderId': 'worker',
                  'senderName': 'Nombre real',
                  'isFromWorker': true,
                  'text': 'Hola',
                  'createdAt': '2026-11-17T12:00:00Z',
                  'deliveredAt': '2026-11-17T12:01:00Z',
                },
              ],
            }),
            200,
          );
        }),
      ),
    );
    final snapshot = await api.load('job', 'token');
    expect(
      snapshot.messages.single.deliveryStatus,
      MessageDeliveryStatus.delivered,
    );
    expect(snapshot.messages.single.id, 'retry-id');
  });
  test('retries preserve the same client message identifier', () async {
    final ids = <String>[];
    final api = ChatApiService(
      apiClient: ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient((request) async {
          ids.add(
            (jsonDecode(request.body) as Map)['clientMessageId'] as String,
          );
          return http.Response('{}', 201);
        }),
      ),
    );
    await api.send('job', 'token', 'same-id', 'Hola');
    await api.send('job', 'token', 'same-id', 'Hola');
    expect(ids, ['same-id', 'same-id']);
  });
  test('server closure has no messages', () async {
    final api = ChatApiService(
      apiClient: ApiClient(
        baseUrl: 'http://example.test',
        httpClient: MockClient(
          (_) async => http.Response('{"closed":true,"messages":[]}', 200),
        ),
      ),
    );
    final snapshot = await api.load('job', 'token');
    expect(snapshot.closed, isTrue);
    expect(snapshot.messages, isEmpty);
  });
}
