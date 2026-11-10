import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/services/jobs_api_service.dart';
import 'package:chamba/data/services/events_socket_service.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/presentation/screens/available_jobs_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loop L2 - Persistencia Backend de Chambas', () {
    test('AppState.fetchJobs actualiza la lista de chambas desde la API REST', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'job-persisted-99',
              'title': 'Reparación de lavadora',
              'description': 'Tambor no gira',
              'category': 'electrodomesticos',
              'budget': 80.0,
              'district': 'Chiclayo',
              'status': 'BUSCANDO',
              'bids': [],
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final jobsApi = JobsApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, jobsApi: jobsApi);

      await appState.fetchJobs();

      expect(appState.jobs.any((j) => j.id == 'job-persisted-99'), isTrue);
      expect(appState.jobsError, isNull);
    });

    test('AppState captura error de red sin caer a mocks en silencio y expone jobsError', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final jobsApi = JobsApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, jobsApi: jobsApi);

      await appState.fetchJobs();

      expect(appState.jobsError, isNotNull);
    });

    testWidgets('AvailableJobsScreen muestra banner de error y botón de reintento si jobsError existe', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final apiClient = ApiClient(httpClient: mockClient);
      final jobsApi = JobsApiService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, jobsApi: jobsApi);

      await appState.fetchJobs();

      await tester.pumpWidget(
        MaterialApp(
          home: AvailableJobsScreen(appState: appState),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Error al conectar con el servidor'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    test('Evento de nueva chamba agrega la solicitud a disponibles en tiempo real', () async {
      final apiClient = ApiClient();
      final eventsSocket = EventsSocketService(apiClient: apiClient);
      final appState = AppState(apiClient: apiClient, eventsSocket: eventsSocket);

      final initialCount = appState.availableWorkerJobs.length;

      appState.createJobRequest(
        title: 'Soldadura de reja exterior',
        categoryId: 'cerrajeria',
        categoryName: 'Cerrajería',
        description: 'Reja rota',
        budget: 95.0,
        district: 'La Victoria',
        address: 'Calle Los Andes 123',
        urgency: 'ALTA',
        isSos: true,
      );

      expect(appState.availableWorkerJobs.length, equals(initialCount + 1));
      expect(appState.availableWorkerJobs.any((j) => j.title == 'Soldadura de reja exterior'), isTrue);
    });
  });
}

