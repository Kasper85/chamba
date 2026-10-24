import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chamba/data/services/api_client.dart';

void main() {
  group('ApiClient Tests', () {
    test('resolves default base URL when not provided', () {
      final client = ApiClient();
      expect(client.baseUrl, isNotEmpty);
      expect(client.baseUrl.startsWith('http'), isTrue);
    });

    test('uses custom base URL when provided', () {
      final client = ApiClient(baseUrl: 'http://192.168.1.50:3000/');
      // Trailing slash should be stripped
      expect(client.baseUrl, equals('http://192.168.1.50:3000'));
    });

    test('injects Bearer token into headers when token is provided', () async {
      String? authHeader;
      final mockHttpClient = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
        tokenProvider: () async => 'test-jwt-token-123',
      );

      final response = await client.get('/api/v1/test');
      expect(response.statusCode, equals(200));
      expect(authHeader, equals('Bearer test-jwt-token-123'));
    });

    test('explicit token in request overrides tokenProvider', () async {
      String? authHeader;
      final mockHttpClient = MockClient((request) async {
        authHeader = request.headers['Authorization'];
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
        tokenProvider: () async => 'default-token',
      );

      await client.get('/api/v1/test', token: 'override-token');
      expect(authHeader, equals('Bearer override-token'));
    });

    test('handles successful POST with JSON body', () async {
      Map<String, dynamic>? receivedBody;
      final mockHttpClient = MockClient((request) async {
        receivedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'id': '123', 'status': 'created'}), 201);
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
      );

      final response = await client.post('/api/v1/items', body: {'name': 'Chamba'});
      expect(response.statusCode, equals(201));
      expect(response.data['id'], equals('123'));
      expect(receivedBody?['name'], equals('Chamba'));
    });

    test('handles 401 Unauthorized by invoking onUnauthorized callback and throwing ApiException', () async {
      bool unauthorizedCalled = false;
      final mockHttpClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Token expirado'}), 401);
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
        onUnauthorized: () {
          unauthorizedCalled = true;
        },
      );

      expect(
        () => client.get('/api/v1/protected'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue)
            .having((e) => e.message, 'message', contains('Token expirado'))),
      );

      await pumpEventQueue();
      expect(unauthorizedCalled, isTrue);
    });

    test('correctly classifies 400 BadRequest, 404 NotFound and 409 Conflict', () async {
      final mockHttpClient = MockClient((request) async {
        final path = request.url.path;
        if (path.contains('bad')) {
          return http.Response(jsonEncode({'message': 'Datos inválidos'}), 400);
        } else if (path.contains('notfound')) {
          return http.Response(jsonEncode({'message': 'Recurso no encontrado'}), 404);
        } else {
          return http.Response(jsonEncode({'message': 'Conflicto de recurso'}), 409);
        }
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
      );

      // 400
      try {
        await client.get('/bad');
        fail('Should throw');
      } on ApiException catch (e) {
        expect(e.isBadRequest, isTrue);
        expect(e.statusCode, equals(400));
      }

      // 404
      try {
        await client.get('/notfound');
        fail('Should throw');
      } on ApiException catch (e) {
        expect(e.isNotFound, isTrue);
        expect(e.statusCode, equals(404));
      }

      // 409
      try {
        await client.get('/conflict');
        fail('Should throw');
      } on ApiException catch (e) {
        expect(e.isConflict, isTrue);
        expect(e.statusCode, equals(409));
      }
    });

    test('handles SocketException as network error', () async {
      final mockHttpClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
      );

      try {
        await client.get('/test');
        fail('Should throw');
      } on ApiException catch (e) {
        expect(e.isNetworkError, isTrue);
        expect(e.statusCode, isNull);
        expect(e.message, contains('No se pudo conectar'));
      }
    });

    test('handles TimeoutException as network error', () async {
      final mockHttpClient = MockClient((request) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response('{}', 200);
      });

      final client = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
        defaultTimeout: const Duration(milliseconds: 20),
      );

      try {
        await client.get('/timeout');
        fail('Should throw');
      } on ApiException catch (e) {
        expect(e.isNetworkError, isTrue);
        expect(e.message, contains('Tiempo de espera agotado'));
      }
    });
  });
}
