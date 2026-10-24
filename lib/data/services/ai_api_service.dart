import 'api_client.dart';
import '../models/ai_diagnostic_result.dart';

class AiApiService {
  final ApiClient apiClient;

  AiApiService({required this.apiClient});

  /// Ejecuta el diagnóstico multimodal mediante POST /ai/diagnose
  Future<AiDiagnosticResult> diagnose({
    required String imageUrl,
    String? prompt,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'imageUrl': imageUrl,
    };
    if (prompt != null && prompt.isNotEmpty) {
      body['prompt'] = prompt;
    }

    final response = await apiClient.post(
      '/api/v1/ai/diagnose',
      token: token,
      body: body,
    );

    if (response.isSuccess && response.data != null) {
      return AiDiagnosticResult.fromJson(response.data as Map<String, dynamic>);
    }

    final errorMsg = response.data is Map
        ? (response.data['message']?.toString() ?? 'Error al procesar diagnóstico con IA')
        : 'Error al procesar diagnóstico con IA';

    throw ApiException(
      errorMsg,
      response.statusCode,
      response.data,
    );
  }
}
