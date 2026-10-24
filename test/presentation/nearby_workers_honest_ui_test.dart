import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

import 'package:chamba/data/models/worker_profile.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/services/location_api_service.dart';
import 'package:chamba/presentation/screens/client_home_screen.dart';
import 'package:chamba/presentation/screens/worker_profile_detail_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  group('S1: Nearby Workers & Honest UI Tests', () {
    testWidgets('ClientHomeScreen renders real worker with Tarifa a convenir, distance and no false badges', (tester) async {
      final mockResponse = {
        'searchCenter': {
          'latitude': -6.7824,
          'longitude': -79.8415,
          'radiusKm': 15,
        },
        'count': 1,
        'workers': [
          {
            'workerProfileId': 'wp-real-1',
            'userId': 'usr-real-1',
            'fullName': 'Ana García',
            'email': 'ana@chamba.pe', // Never to be shown in UI
            'phone': '+51 974 555 101',
            'userDistrict': 'Santa Victoria, Chiclayo',
            'workerDistrict': 'Santa Victoria, Chiclayo',
            'specialty': 'Electricidad',
            'bio': 'Especialista en instalaciones domiciliarias',
            'rating': 4.9,
            'completedJobs': 28,
            'isAvailable': true,
            'latitude': -6.7725,
            'longitude': -79.8398,
            'distanceKm': 1.11,
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:3000', httpClient: mockClient);
      final locationApi = LocationApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, locationApi: locationApi);

      // Perform fetch
      await appState.fetchNearbyWorkers(latitude: -6.7824, longitude: -79.8415, radiusKm: 15.0);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientHomeScreen(appState: appState),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify title & subtitle
      expect(find.text('Técnicos Cercanos en Chiclayo'), findsOneWidget);
      expect(find.text('PostGIS en tiempo real • Radio 15 km'), findsOneWidget);

      // Verify worker card details
      expect(find.text('Ana García'), findsOneWidget);
      expect(find.text('1.1 km'), findsOneWidget);
      expect(find.text('Tarifa a convenir'), findsOneWidget);

      // Reglas de veracidad:
      // 1. NO fallback a S/ 40
      expect(find.text('S/. 40/h'), findsNothing);
      expect(find.text('S/. 40'), findsNothing);

      // 2. NO sellos falsos para técnicos reales
      expect(find.text('Escudo de Confianza:'), findsNothing);
      expect(find.text('RENIEC'), findsNothing);
      expect(find.text('Sin Antecedentes'), findsNothing);
      expect(find.text('Garantía 7d'), findsNothing);

      // 3. NO mostrar email
      expect(find.text('ana@chamba.pe'), findsNothing);
    });

    testWidgets('WorkerProfileDetailScreen hides experience, shows Tarifa a convenir and empty reviews for real worker', (tester) async {
      final realWorker = WorkerProfile.fromNearbyJson({
        'workerProfileId': 'wp-real-1',
        'userId': 'usr-real-1',
        'fullName': 'Ana García',
        'email': 'ana@chamba.pe',
        'phone': '+51 974 555 101',
        'userDistrict': 'Santa Victoria, Chiclayo',
        'specialty': 'Electricidad',
        'bio': 'Especialista en instalaciones domiciliarias',
        'rating': 4.9,
        'completedJobs': 28,
        'isAvailable': true,
        'latitude': -6.7725,
        'longitude': -79.8398,
        'distanceKm': 1.11,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerProfileDetailScreen(worker: realWorker),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Name & distance
      expect(find.text('Ana García'), findsOneWidget);
      expect(find.text('Santa Victoria, Chiclayo • 1.1 km de ti'), findsOneWidget);

      // Honest rate: Tarifa a convenir
      expect(find.text('Tarifa a convenir'), findsOneWidget);
      expect(find.textContaining('A convenir según magnitud del trabajo'), findsOneWidget);

      // Hidden experience years (replaced with distance)
      expect(find.text('Experiencia'), findsNothing);
      expect(find.text('Distancia'), findsOneWidget);
      expect(find.text('1.1 km'), findsOneWidget);

      // Empty reviews text
      expect(find.text('Aún sin reseñas'), findsOneWidget);

      // No fake badges
      expect(find.text('Escudo de Confianza:'), findsNothing);
      expect(find.text('RENIEC'), findsNothing);

      // No email exposed
      expect(find.text('ana@chamba.pe'), findsNothing);
    });

    testWidgets('Empty state appears when nearby query returns 0 workers', (tester) async {
      final emptyResponse = {
        'searchCenter': {
          'latitude': -6.7824,
          'longitude': -79.8415,
          'radiusKm': 5,
        },
        'count': 0,
        'workers': []
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(emptyResponse), 200);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:3000', httpClient: mockClient);
      final locationApi = LocationApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, locationApi: locationApi);

      await appState.fetchNearbyWorkers(latitude: -6.7824, longitude: -79.8415, radiusKm: 5.0);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientHomeScreen(appState: appState),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No hay técnicos disponibles en este radio'), findsOneWidget);
      expect(find.text('Ampliar radio a 30 km'), findsOneWidget);
    });
  });
}
