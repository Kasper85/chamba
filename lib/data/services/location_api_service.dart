import 'package:chamba/data/models/worker_profile.dart';
import 'package:chamba/data/services/api_client.dart';

/// Servicio para interacción con los endpoints de geolocalización (PostGIS):
/// - GET /api/v1/location/nearby: Encuentra técnicos disponibles en un radio en km.
/// - PUT /api/v1/location/worker: Actualiza la ubicación geoespacial del técnico.
class LocationApiService {
  final ApiClient apiClient;

  LocationApiService({required this.apiClient});

  /// Consulta técnicos cercanos a una coordenada [lat], [lng] en un radio [radiusKm].
  /// Retorna lista de [WorkerProfile] configurados con honestidad (sin datos inventados).
  Future<List<WorkerProfile>> getNearbyWorkers({
    required double lat,
    required double lng,
    double radiusKm = 15.0,
    String? specialty,
  }) async {
    final queryParams = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radiusKm': radiusKm.toString(),
    };

    if (specialty != null && specialty.trim().isNotEmpty) {
      queryParams['specialty'] = specialty.trim();
    }

    final response = await apiClient.get(
      '/api/v1/location/nearby',
      queryParams: queryParams,
    );

    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    final workersJson = data['workers'] as List? ?? [];

    return workersJson
        .map((w) => WorkerProfile.fromNearbyJson(w as Map<String, dynamic>))
        .toList();
  }

  /// Actualiza la ubicación de un técnico con coordenadas [latitude], [longitude].
  /// Requiere autenticación (JWT).
  Future<Map<String, dynamic>> updateWorkerLocation({
    required double latitude,
    required double longitude,
    String? token,
  }) async {
    final response = await apiClient.put(
      '/api/v1/location/worker',
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
      token: token,
    );

    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }
}
