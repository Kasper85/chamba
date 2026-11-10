import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/presentation/screens/client_job_tracking_view.dart';
import 'package:chamba/presentation/screens/worker_job_tracking_view.dart';
import 'package:chamba/presentation/screens/job_tracking_screen.dart';

void main() {
  late AppState appState;

  final sampleJob = JobRequest(
    id: 'test-job-l4',
    title: 'Reparación de Cerradura',
    categoryId: 'cerrajeria',
    categoryName: 'Cerrajería',
    description: 'Chapa trabada en puerta principal',
    budget: 80.0,
    district: 'Chiclayo',
    address: 'Av. Balta 450, Chiclayo',
    distanceKm: 1.2,
    urgency: 'ALTA',
    status: JobStatus.accepted,
    createdAt: DateTime.now(),
    clientId: 'client-1',
    clientName: 'María García',
    confirmationCode: '7412',
    securityPin: '7412',
    workerId: 'worker-1',
    workerName: 'Juan Pérez',
  );

  setUp(() {
    appState = AppState();
  });

  group('Loop L4 - Seguimiento por Rol (Cliente y Chambeador)', () {
    testWidgets('ClientJobTrackingView muestra PIN destacado y no contiene "Simular Técnico"', (tester) async {
      appState.currentRole = UserRole.client;

      await tester.pumpWidget(
        MaterialApp(
          home: ClientJobTrackingView(
            appState: appState,
            job: sampleJob,
          ),
        ),
      );
      await tester.pump();

      // Debe mostrar el PIN presencial de 4 dígitos para dictar al técnico
      expect(find.text('Tu PIN de Seguridad Presencial'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // NO debe existir "Simular Técnico"
      expect(find.text('Simular Técnico'), findsNothing);
      expect(find.text('Vista Técnico: Validación PIN'), findsNothing);
    });

    testWidgets('WorkerJobTrackingView muestra botón "Estoy en camino" en ACEPTADA', (tester) async {
      appState.currentRole = UserRole.worker;

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerJobTrackingView(
            appState: appState,
            job: sampleJob,
          ),
        ),
      );
      await tester.pump();

      // Debe mostrar botón "Estoy en camino"
      expect(find.text('Estoy en camino'), findsOneWidget);
      // NO debe mostrar el cartel de dictar PIN del cliente
      expect(find.text('Tu PIN de Seguridad Presencial'), findsNothing);
      expect(find.text('Simular Técnico'), findsNothing);
    });

    testWidgets('WorkerJobTrackingView muestra validación de PIN en estado EN_SITIO', (tester) async {
      appState.currentRole = UserRole.worker;
      final onSiteJob = sampleJob.copyWith(status: JobStatus.onSite);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerJobTrackingView(
            appState: appState,
            job: onSiteJob,
          ),
        ),
      );
      await tester.pump();

      // Debe solicitar el PIN de 4 dígitos al chambeador
      expect(find.textContaining('Validar PIN'), findsWidgets);
      expect(find.text('Simular Técnico'), findsNothing);
    });

    testWidgets('JobTrackingScreen despacha a la vista correspondiente según el rol activo', (tester) async {
      appState.currentRole = UserRole.client;

      await tester.pumpWidget(
        MaterialApp(
          home: JobTrackingScreen(
            appState: appState,
            job: sampleJob,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ClientJobTrackingView), findsOneWidget);
      expect(find.byType(WorkerJobTrackingView), findsNothing);

      // Cambiar a rol worker
      appState.currentRole = UserRole.worker;
      await tester.pumpWidget(
        MaterialApp(
          home: JobTrackingScreen(
            appState: appState,
            job: sampleJob,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WorkerJobTrackingView), findsOneWidget);
      expect(find.byType(ClientJobTrackingView), findsNothing);
    });
  });
}

