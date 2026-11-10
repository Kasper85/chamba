import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/data/models/job_state_machine.dart';
import 'package:chamba/data/models/bid.dart';
import 'package:chamba/data/services/api_client.dart';

/// Servicio para interacción con los endpoints REST de Chamba:
/// - POST /api/v1/jobs: Publicar una solicitud de trabajo
/// - GET /api/v1/jobs: Listar solicitudes (filtradas por rol y estado)
/// - GET /api/v1/jobs/:id: Detalle de una solicitud
/// - POST /api/v1/jobs/:id/bids: Enviar oferta de trabajo
/// - POST /api/v1/jobs/:id/bids/:bidId/counter: Contraofertar
/// - POST /api/v1/jobs/:id/bids/:bidId/accept: Aceptar oferta
class JobsApiService {
  final ApiClient apiClient;

  JobsApiService({required this.apiClient});

  /// Publica una nueva chamba en el backend.
  Future<JobRequest> createJob({
    required String title,
    required String description,
    required String category,
    required double budget,
    required String district,
    String? address,
    String? reference,
    double? latitude,
    double? longitude,
    bool isSos = false,
    String urgency = 'MEDIA',
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/jobs',
      body: {
        'title': title,
        'description': description,
        'category': category,
        'budget': budget,
        'district': district,
        'address': ?address,
        'reference': ?reference,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'isSos': isSos,
        'urgency': urgency,
      },
      token: token,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return JobRequest.fromJson(data);
  }

  /// Lista chambas filtradas por rol del usuario ('client' o 'worker') y estado opcional.
  Future<List<JobRequest>> getJobs({
    String? role,
    JobStatus? status,
    String? token,
  }) async {
    final queryParams = <String, String>{};
    if (role != null) queryParams['role'] = role;
    if (status != null) queryParams['status'] = JobStateMachine.toBackendName(status);

    final response = await apiClient.get(
      '/api/v1/jobs',
      queryParams: queryParams,
      token: token,
    );

    final list = response.data is List ? response.data as List : [];
    return list
        .map((j) => JobRequest.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene el detalle de una chamba específica por ID.
  Future<JobRequest> getJobById(String jobId, {String? token}) async {
    final response = await apiClient.get(
      '/api/v1/jobs/$jobId',
      token: token,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return JobRequest.fromJson(data);
  }

  /// Un técnico envía una propuesta económica (oferta) para una chamba.
  Future<Bid> createBid({
    required String jobId,
    required double amount,
    String? message,
    int? etaMinutes,
    String? voiceNoteUrl,
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/jobs/$jobId/bids',
      body: {
        'amount': amount,
        'message': ?message,
        'estimatedEtaMinutes': ?etaMinutes,
        'voiceNoteUrl': ?voiceNoteUrl,
      },
      token: token,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return Bid.fromJson(data);
  }

  /// Contraofertar sobre una propuesta.
  Future<Bid> counterBid({
    required String jobId,
    required String bidId,
    required double counterAmount,
    String? note,
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/jobs/$jobId/bids/$bidId/counter',
      body: {
        'counterAmount': counterAmount,
        'note': ?note,
      },
      token: token,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return Bid.fromJson(data);
  }

  /// El cliente acepta una oferta. La chamba pasa a ACEPTADA.
  Future<JobRequest> acceptBid({
    required String jobId,
    required String bidId,
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/jobs/$jobId/bids/$bidId/accept',
      body: {},
      token: token,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return JobRequest.fromJson(data);
  }

  /// Actualiza la fase de una chamba (PUT /api/v1/jobs/:id/phase) con validaciones de rol y máquina de estados.
  Future<JobRequest> updatePhase({
    required String jobId,
    required JobStatus phase,
    String? pin,
    String? photoBefore,
    String? photoAfter,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'phase': JobStateMachine.toBackendName(phase),
    };
    if (pin != null) body['pin'] = pin;
    if (photoBefore != null) body['photoBefore'] = photoBefore;
    if (photoAfter != null) body['photoAfter'] = photoAfter;

    final response = await apiClient.put(
      '/api/v1/jobs/$jobId/phase',
      body: body,
      token: token,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return JobRequest.fromJson(data);
  }

  /// Cancela una chamba según la matriz de reglas de ALCANCE.md §4.
  Future<Map<String, dynamic>> cancelJob({
    required String jobId,
    required String reason,
    bool isWorkerDelay = false,
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/jobs/$jobId/cancel',
      body: {
        'reason': reason,
        'isWorkerDelay': isWorkerDelay,
      },
      token: token,
    );

    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// Envía la calificación mutua (y propina opcional) para un trabajo terminado (ALCANCE.md §6, §8 L8).
  Future<Map<String, dynamic>> createRating({
    required String jobId,
    required int stars,
    String? comment,
    double? tipAmount,
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/jobs/$jobId/rating',
      body: {
        'stars': stars,
        'comment': ?comment,
        'tipAmount': ?tipAmount,
      },
      token: token,
    );

    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// Obtiene el recibo formal con desglose financiero de un trabajo terminado (ALCANCE.md §6, §8 L8).
  Future<Map<String, dynamic>> getJobReceipt({
    required String jobId,
    String? token,
  }) async {
    final response = await apiClient.get(
      '/api/v1/jobs/$jobId/receipt',
      token: token,
    );

    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }
}

