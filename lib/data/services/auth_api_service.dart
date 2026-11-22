import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_account.dart';
import 'api_client.dart';

/// Excepción de autenticación retrocompatible basada en ApiException.
class AuthApiException extends ApiException {
  const AuthApiException(super.message, [super.statusCode, super.data]);
}

class AuthResponse {
  final UserAccount user;
  final String accessToken;
  final String? message;

  const AuthResponse({
    required this.user,
    required this.accessToken,
    this.message,
  });
}

class AuthApiService {
  static Future<void>? _googleInitialization;
  static const _googleServerClientId =
      '453779337240-oqfhfbhqn8l7l8i05fjc03r41iscn7nh.apps.googleusercontent.com';
  final ApiClient _apiClient;

  String get baseUrl => _apiClient.baseUrl;

  AuthApiService({String? baseUrl, http.Client? client, ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: baseUrl, httpClient: client);

  Future<AuthResponse> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    String? district,
    String? address,
  }) async {
    final payload = {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (district != null && district.trim().isNotEmpty)
        'district': district.trim(),
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
    };

    try {
      final response = await _apiClient.post(
        '/api/v1/auth/register',
        body: payload,
      );
      final body = response.data as Map<String, dynamic>;
      final user = UserAccount.fromJson(body['user'] as Map<String, dynamic>);
      final token = body['accessToken'] as String;

      return AuthResponse(
        user: user,
        accessToken: token,
        message: body['message'] as String?,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw AuthApiException(
          e.data is Map
              ? (e.data['message']?.toString() ??
                    'El correo electrónico ya está registrado')
              : e.message,
          409,
          e.data,
        );
      }
      throw AuthApiException(e.message, e.statusCode, e.data);
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final payload = {'email': email.trim().toLowerCase(), 'password': password};

    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        body: payload,
      );
      final body = response.data as Map<String, dynamic>;
      final user = UserAccount.fromJson(body['user'] as Map<String, dynamic>);
      final token = body['accessToken'] as String;

      return AuthResponse(
        user: user,
        accessToken: token,
        message: body['message'] as String?,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw AuthApiException(e.message, 401, e.data);
      }
      throw AuthApiException(e.message, e.statusCode, e.data);
    }
  }

  Future<AuthResponse> loginWithGoogle({bool register = false}) async {
    try {
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      await _googleInitialization;

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthApiException(
          'Google no devolvió un token de identidad',
        );
      }

      final response = await _apiClient.post(
        register ? '/api/v1/auth/google/register' : '/api/v1/auth/google/login',
        body: {'idToken': idToken},
      );
      final body = response.data as Map<String, dynamic>;
      return AuthResponse(
        user: UserAccount.fromJson(body['user'] as Map<String, dynamic>),
        accessToken: body['accessToken'] as String,
        message: body['message'] as String?,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthApiException('Inicio de sesión con Google cancelado');
      }
      throw AuthApiException(
        'No se pudo iniciar sesión con Google: ${e.description ?? e.code.name}',
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw AuthApiException(e.message, 401);
      }
      throw AuthApiException(e.message, e.statusCode, e.data);
    }
  }

  Future<UserAccount> getMe(String token) async {
    try {
      final response = await _apiClient.get('/api/v1/users/me', token: token);
      return UserAccount.fromJson(response.data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw const AuthApiException('Sesión expirada o no autorizada', 401);
      }
      throw AuthApiException(e.message, e.statusCode, e.data);
    }
  }

  Future<UserAccount> updateMe(
    String token, {
    String? fullName,
    String? phone,
    String? district,
    String? address,
  }) async {
    final payload = {
      if (fullName != null) 'fullName': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (district != null) 'district': district.trim(),
      if (address != null) 'address': address.trim(),
    };

    try {
      final response = await _apiClient.patch(
        '/api/v1/users/me',
        body: payload,
        token: token,
      );
      return UserAccount.fromJson(response.data as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw AuthApiException(e.message, e.statusCode, e.data);
    }
  }

  Future<WorkerProfileData> upsertWorkerProfile(
    String token, {
    required String bio,
    required String specialty,
    String? district,
    bool isAvailable = true,
    String? dni,
    double? baseRate,
    int? serviceRadiusKm,
    int? experienceYears,
    List<String>? skills,
  }) async {
    final payload = {
      'bio': bio.trim(),
      'specialty': specialty.trim(),
      if (district != null) 'district': district.trim(),
      'isAvailable': isAvailable,
      if (dni != null && dni.isNotEmpty) 'dni': dni,
      'baseRate': ?baseRate,
      'serviceRadiusKm': ?serviceRadiusKm,
      'experienceYears': ?experienceYears,
      'skills': ?skills,
    };

    try {
      final response = await _apiClient.put(
        '/api/v1/worker-profile/me',
        body: payload,
        token: token,
      );
      return WorkerProfileData.fromJson(response.data as Map<String, dynamic>);
    } on ApiException catch (e) {
      throw AuthApiException(e.message, e.statusCode, e.data);
    }
  }
}
