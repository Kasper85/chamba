import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Excepción tipada para errores de la API HTTP de CHAMBA.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException(this.message, [this.statusCode, this.data]);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isBadRequest => statusCode == 400;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

/// Respuesta tipada de la API HTTP.
class ApiResponse {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;

  const ApiResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Cliente HTTP centralizado para la comunicación con el Backend NestJS.
/// 
/// Características:
/// - Base URL configurable por `--dart-define=API_BASE_URL=...`
/// - Interruptor `--dart-define=USE_MOCKS=true|false`
/// - Inyección automática de token Bearer
/// - Timeouts estructurados
/// - Errores tipados con detección de 401 (cierre de sesión)
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Future<String?> Function()? tokenProvider;
  final void Function()? onUnauthorized;
  final Duration defaultTimeout;

  /// Interruptor global configurable en tiempo de compilación.
  /// Si es false, cualquier fallo de API se reporta con opción de reintentar (nunca cae a mocks en silencio).
  static const bool useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.tokenProvider,
    this.onUnauthorized,
    Duration? defaultTimeout,
  })  : baseUrl = _normalizeBaseUrl(baseUrl ?? _resolveDefaultBaseUrl()),
        _httpClient = httpClient ?? http.Client(),
        defaultTimeout = defaultTimeout ?? const Duration(seconds: 10);

  static String _normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String _resolveDefaultBaseUrl() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    try {
      if (Platform.isAndroid) {
        // En emulador Android oficial, 10.0.2.2 apunta al localhost de la PC anfitriona
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {
      // Platform no disponible en ciertas plataformas
    }
    return 'http://localhost:3000';
  }

  Future<Map<String, String>> _buildHeaders({
    String? token,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final effectiveToken = token ?? await tokenProvider?.call();
    if (effectiveToken != null && effectiveToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${effectiveToken.trim()}';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$baseUrl$cleanPath';

    if (queryParams == null || queryParams.isEmpty) {
      return Uri.parse(fullUrl);
    }

    final queryMap = <String, String>{};
    queryParams.forEach((key, value) {
      if (value != null) {
        queryMap[key] = value.toString();
      }
    });

    return Uri.parse(fullUrl).replace(queryParameters: queryMap);
  }

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    return _sendRequest(
      () async => _httpClient.get(uri, headers: await _buildHeaders(token: token, extraHeaders: headers)),
      timeout: timeout,
    );
  }

  Future<ApiResponse> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
    return _sendRequest(
      () async => _httpClient.post(
        uri,
        headers: await _buildHeaders(token: token, extraHeaders: headers),
        body: encodedBody,
      ),
      timeout: timeout,
    );
  }

  Future<ApiResponse> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
    return _sendRequest(
      () async => _httpClient.put(
        uri,
        headers: await _buildHeaders(token: token, extraHeaders: headers),
        body: encodedBody,
      ),
      timeout: timeout,
    );
  }

  Future<ApiResponse> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
    return _sendRequest(
      () async => _httpClient.patch(
        uri,
        headers: await _buildHeaders(token: token, extraHeaders: headers),
        body: encodedBody,
      ),
      timeout: timeout,
    );
  }

  Future<ApiResponse> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? token,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final encodedBody = body is String ? body : (body != null ? jsonEncode(body) : null);
    return _sendRequest(
      () async => _httpClient.delete(
        uri,
        headers: await _buildHeaders(token: token, extraHeaders: headers),
        body: encodedBody,
      ),
      timeout: timeout,
    );
  }

  Future<ApiResponse> _sendRequest(
    Future<http.Response> Function() execute, {
    Duration? timeout,
  }) async {
    try {
      final response = await execute().timeout(timeout ?? defaultTimeout);
      final parsedBody = _parseBody(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          data: parsedBody,
          headers: response.headers,
        );
      }

      final errorMessage = _extractErrorMessage(parsedBody, 'Error en la petición HTTP (${response.statusCode})');

      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }

      throw ApiException(errorMessage, response.statusCode, parsedBody);
    } on TimeoutException {
      throw const ApiException('Tiempo de espera agotado. Verifica tu conexión a internet.');
    } on SocketException {
      throw ApiException(
        'No se pudo conectar con el servidor backend CHAMBA ($baseUrl). Verifica que esté en ejecución.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión inesperado: $e');
    }
  }

  dynamic _parseBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String _extractErrorMessage(dynamic body, String fallback) {
    if (body is Map) {
      final msg = body['message'];
      if (msg is List) {
        return msg.join(', ');
      } else if (msg is String && msg.isNotEmpty) {
        return msg;
      }
      final error = body['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    return fallback;
  }
}
