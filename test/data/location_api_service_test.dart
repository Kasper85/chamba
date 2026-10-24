import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/services/location_api_service.dart';

void main() {
  group('LocationApiService Tests', () {
    test('fetches and parses nearby workers correctly', () async {
      final mockResponse = {
        'searchCenter': {
          'latitude': -6.7824,
          'longitude': -79.8415,
          'radiusKm': 10,
          'specialty': null,
        },
        'count': 1,
        'workers': [
          {
            'workerProfileId': 'wp-101',
            'userId': 'usr-202',
            'fullName': 'Ana García',
            'email': 'ana@chamba.pe',
            'phone': '+51 974 555 101',
            'userDistrict': 'Santa Victoria, Chiclayo',
            'workerDistrict': 'Santa Victoria, Chiclayo',
            'specialty': 'Electricidad',
            'bio': 'Técnica electricista profesional',
            'rating': 4.9,
            'completedJobs': 28,
            'isAvailable': true,
            'latitude': -6.7725,
            'longitude': -79.8398,
            'distanceMeters': 1110.9,
            'distanceKm': 1.11,
          }
        ]
      };

      final mockHttpClient = MockClient((request) async {
        expect(request.url.path, equals('/api/v1/location/nearby'));
        expect(request.url.queryParameters['lat'], equals('-6.7824'));
        expect(request.url.queryParameters['lng'], equals('-79.8415'));
        expect(request.url.queryParameters['radiusKm'], equals('10.0'));
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
      );

      final service = LocationApiService(apiClient: apiClient);
      final workers = await service.getNearbyWorkers(
        lat: -6.7824,
        lng: -79.8415,
        radiusKm: 10.0,
      );

      expect(workers.length, equals(1));
      final worker = workers.first;
      expect(worker.id, equals('wp-101'));
      expect(worker.name, equals('Ana García'));
      expect(worker.avatarInitials, equals('AG'));
      expect(worker.rating, equals(4.9));
      expect(worker.completedJobs, equals(28));
      expect(worker.skills, contains('Electricidad'));
      expect(worker.district, equals('Santa Victoria, Chiclayo'));
      expect(worker.distanceKm, equals(1.11));
      expect(worker.latitude, equals(-6.7725));
      expect(worker.longitude, equals(-79.8398));
      expect(worker.isRealBackendWorker, isTrue);

      // Reglas estrictas de veracidad: No inventar datos
      expect(worker.baseRate, equals(0.0)); // 0.0 activa "Tarifa a convenir"
      expect(worker.isVerified, isFalse);
      expect(worker.isIdVerified, isFalse);
      expect(worker.hasCleanRecord, isFalse);
      expect(worker.offersWarranty, isFalse);
      expect(worker.experienceYears, equals(0));
      expect(worker.reviews, isEmpty);
      expect(worker.portfolioCases, isEmpty);
    });

    test('updates worker location successfully with PUT /api/v1/location/worker', () async {
      final mockHttpClient = MockClient((request) async {
        expect(request.method, equals('PUT'));
        expect(request.url.path, equals('/api/v1/location/worker'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['latitude'], equals(-6.7725));
        expect(body['longitude'], equals(-79.8398));
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Ubicación geoespacial del trabajador actualizada con éxito en PostGIS',
            'workerProfileId': 'wp-101',
            'userId': 'usr-202',
            'latitude': -6.7725,
            'longitude': -79.8398,
            'updatedAt': '2026-10-24T05:00:00Z',
          }),
          200,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockHttpClient,
      );

      final service = LocationApiService(apiClient: apiClient);
      final result = await service.updateWorkerLocation(
        latitude: -6.7725,
        longitude: -79.8398,
        token: 'valid-jwt',
      );

      expect(result['success'], isTrue);
      expect(result['workerProfileId'], equals('wp-101'));
    });
  });
}
