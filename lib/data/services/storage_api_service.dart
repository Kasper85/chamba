import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class PresignedUploadData {
  final String uploadUrl;
  final String fileKey;
  final String publicUrl;
  final int expiresIn;
  final String contentType;

  const PresignedUploadData({
    required this.uploadUrl,
    required this.fileKey,
    required this.publicUrl,
    required this.expiresIn,
    required this.contentType,
  });

  factory PresignedUploadData.fromJson(Map<String, dynamic> json) {
    return PresignedUploadData(
      uploadUrl: json['uploadUrl'] as String? ?? '',
      fileKey: json['fileKey'] as String? ?? '',
      publicUrl: json['publicUrl'] as String? ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt() ?? 900,
      contentType: json['contentType'] as String? ?? 'image/jpeg',
    );
  }
}

class StorageApiService {
  final ApiClient apiClient;
  final http.Client _httpClient;

  StorageApiService({
    required this.apiClient,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Obtiene URL prefirmada (R2 / S3) desde GET /storage/upload-url
  Future<PresignedUploadData> getPresignedUploadUrl({
    String filename = 'diagnostico.jpg',
    String contentType = 'image/jpeg',
    String folder = 'diagnostics',
    String? token,
  }) async {
    final query = 'filename=$filename&contentType=$contentType&folder=$folder';
    final response = await apiClient.get(
      '/api/v1/storage/upload-url?$query',
      token: token,
    );

    if (response.isSuccess && response.data != null) {
      return PresignedUploadData.fromJson(response.data as Map<String, dynamic>);
    }

    final errorMsg = response.data is Map
        ? (response.data['message']?.toString() ?? 'Error al generar URL de subida a R2')
        : 'Error al generar URL de subida a R2';

    throw ApiException(
      errorMsg,
      response.statusCode,
      response.data,
    );
  }

  /// Realiza el PUT directo hacia Cloudflare R2 con los bytes del archivo
  Future<bool> uploadFileToPresignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final response = await _httpClient.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': contentType,
        },
        body: bytes,
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
