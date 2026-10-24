import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chamba/data/models/user_account.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/services/location_api_service.dart';
import 'package:chamba/presentation/screens/available_jobs_screen.dart';
import 'package:chamba/presentation/screens/worker_shell.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  group('S2: Worker Location Sync (PUT /location/worker)', () {
    testWidgets('WorkerShell on init triggers worker location update with JWT token', (tester) async {
      int updateCallCount = 0;
      Map<String, dynamic>? lastBody;
      String? authHeader;

      final mockClient = MockClient((request) async {
        if (request.method == 'PUT' && request.url.path == '/api/v1/location/worker') {
          updateCallCount++;
          lastBody = jsonDecode(request.body) as Map<String, dynamic>;
          authHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Ubicación geoespacial del trabajador actualizada con éxito en PostGIS',
              'workerProfileId': 'wp-carlos-1',
              'userId': 'usr-carlos-1',
              'latitude': -6.8372,
              'longitude': -79.9342,
              'updatedAt': '2026-10-24T05:00:00Z',
            }),
            200,
          );
        }
        return http.Response('{"error": "Not Found"}', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:3000', httpClient: mockClient);
      final locationApi = LocationApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, locationApi: locationApi);

      // Set worker session
      final workerUser = UserAccount(
        id: 'usr-carlos-1',
        fullName: 'Carlos Ramírez',
        email: 'carlos@chamba.pe',
        phone: '+51 974 555 102',
        district: 'Pimentel, Lambayeque',

        workerProfile: const WorkerProfileData(
          id: 'wp-carlos-1',
          bio: 'Gasfitero profesional',
          district: 'Pimentel',
          specialty: 'Gasfitería',
          isAvailable: true,
          rating: 4.8,
          completedJobs: 42,
        ),
      );
      await appState.setSession(workerUser, 'carlos-jwt-token');
      appState.switchRole(UserRole.worker);
      appState.setUserCoordinates(-6.8372, -79.9342);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerShell(appState: appState),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(updateCallCount, equals(1));
      expect(lastBody?['latitude'], equals(-6.8372));
      expect(lastBody?['longitude'], equals(-79.9342));
      expect(authHeader, equals('Bearer carlos-jwt-token'));
    });

    testWidgets('Toggling availability switch to active triggers location sync in AvailableJobsScreen', (tester) async {
      int updateCallCount = 0;

      final mockClient = MockClient((request) async {
        if (request.method == 'PUT' && request.url.path == '/api/v1/location/worker') {
          updateCallCount++;
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Ubicación geoespacial del trabajador actualizada con éxito en PostGIS',
              'workerProfileId': 'wp-ana-1',
              'userId': 'usr-ana-1',
              'latitude': -6.7725,
              'longitude': -79.8398,
              'updatedAt': '2026-10-24T05:00:00Z',
            }),
            200,
          );
        }
        return http.Response('{"error": "Not Found"}', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://localhost:3000', httpClient: mockClient);
      final locationApi = LocationApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, locationApi: locationApi);

      final workerUser = UserAccount(
        id: 'usr-ana-1',
        fullName: 'Ana García',
        email: 'ana@chamba.pe',
        phone: '+51 974 555 101',
        district: 'Santa Victoria, Chiclayo',

      );
      await appState.setSession(workerUser, 'ana-jwt-token');
      appState.switchRole(UserRole.worker);
      appState.setUserCoordinates(-6.7725, -79.8398);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvailableJobsScreen(appState: appState),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find availability Switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle off
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Toggling off should NOT update location or can update depending on policy, but activating MUST update
      final countAfterOff = updateCallCount;

      // Toggle on (activarse disponible)
      await tester.tap(switchFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(updateCallCount, greaterThan(countAfterOff));
    });
  });
}
