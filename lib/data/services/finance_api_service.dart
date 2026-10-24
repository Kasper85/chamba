import 'api_client.dart';
import '../models/wallet_summary.dart';

class FinanceApiService {
  final ApiClient apiClient;

  FinanceApiService({required this.apiClient});

  /// Consulta el balance de la billetera y el historial inmutable de Ledger del usuario
  Future<WalletSummary> getWallet({required String token}) async {
    final response = await apiClient.get(
      '/api/v1/finance/wallet',
      token: token,
    );

    if (response.isSuccess && response.data != null) {
      final json = response.data as Map<String, dynamic>;
      return WalletSummary.fromJson(json);
    }

    final errorMsg = response.data is Map ? (response.data['message']?.toString() ?? 'Error al obtener resumen de billetera') : 'Error al obtener resumen de billetera';
    throw ApiException(
      errorMsg,
      response.statusCode,
      response.data,
    );
  }

  /// Retiene fondos en custodia (Escrow) al aceptar una propuesta
  Future<Map<String, dynamic>> holdEscrow({
    required String token,
    required String jobRequestId,
    required double amount,
    String? description,
  }) async {
    final body = <String, dynamic>{
      'jobRequestId': jobRequestId,
      'amount': amount,
    };
    if (description != null) {
      body['description'] = description;
    }

    final response = await apiClient.post(
      '/api/v1/finance/escrow/hold',
      token: token,
      body: body,
    );

    if (response.isSuccess && response.data != null) {
      return response.data as Map<String, dynamic>;
    }

    final errorMsg = response.data is Map ? (response.data['message']?.toString() ?? 'Error al retener fondos en custodia (Escrow)') : 'Error al retener fondos en custodia (Escrow)';
    throw ApiException(
      errorMsg,
      response.statusCode,
      response.data,
    );
  }

  /// Libera fondos de Escrow al culminar el trabajo
  Future<Map<String, dynamic>> releaseEscrow({
    required String token,
    required String jobRequestId,
    required String workerUserId,
    required double amount,
  }) async {
    final response = await apiClient.post(
      '/api/v1/finance/escrow/release',
      token: token,
      body: {
        'jobRequestId': jobRequestId,
        'workerUserId': workerUserId,
        'amount': amount,
      },
    );

    if (response.isSuccess && response.data != null) {
      return response.data as Map<String, dynamic>;
    }

    final errorMsg = response.data is Map ? (response.data['message']?.toString() ?? 'Error al liberar fondos de custodia al técnico') : 'Error al liberar fondos de custodia al técnico';
    throw ApiException(
      errorMsg,
      response.statusCode,
      response.data,
    );
  }
}
