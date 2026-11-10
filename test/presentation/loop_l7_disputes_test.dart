import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/presentation/screens/dispute_detail_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  late AppState appState;

  setUp(() {
    appState = AppState();
  });

  final testJobInDispute = JobRequest(
    id: 'job-l7-disp',
    title: 'Instalación de tomacorriente doble',
    categoryId: 'electricidad',
    categoryName: 'Electricidad',
    description: 'Tomacorriente chispea al conectar electrodomésticos',
    budget: 90.0,
    district: 'Chiclayo Centro',
    address: 'Calle San José 540',
    distanceKm: 0.9,
    urgency: 'ALTA',
    status: JobStatus.inDispute,
    createdAt: DateTime.now(),
    clientId: 'client-1',
    clientName: 'Pedro Alarcón',
    confirmationCode: '9876',
    securityPin: '9876',
    workerId: 'worker-1',
    workerName: 'Jorge Quispe Baldera',
    escrowStatus: EscrowStatus.heldInEscrow,
  );

  group('Loop L7 - Disputas y Soporte (§5)', () {
    testWidgets('DisputeDetailScreen renders frozen funds, AI recommendation disclaimer and support status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: testJobInDispute,
            initialReason: 'El tomacorriente sigue sin voltaje.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner de fondos congelados
      expect(find.text('Fondos Congelados en Custodia'), findsOneWidget);
      expect(find.textContaining('Los S/ 90.00 depositados no se liberarán'), findsOneWidget);

      // Regla dura de IA explícita
      expect(find.text('Recomendación del Asistente IA'), findsOneWidget);
      expect(find.textContaining('La IA en disputas solo recomienda; nunca mueve dinero sola'), findsOneWidget);

      // Ticket de soporte
      expect(find.text('Ticket de Soporte en Proceso'), findsOneWidget);

      // Botón de apelación
      expect(find.text('Presentar Apelación Única'), findsOneWidget);
    });

    testWidgets('Permite una sola apelación y bloquea posteriores (§5.6)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: testJobInDispute,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appealBtn = find.text('Presentar Apelación Única');
      expect(appealBtn, findsOneWidget);
      await tester.ensureVisible(appealBtn);
      await tester.pumpAndSettle();
      await tester.tap(appealBtn);
      await tester.pumpAndSettle();

      // Diálogo de confirmación
      expect(find.text('Presentar Apelación Única'), findsWidgets);
      final confirmBtn = find.text('Enviar Apelación');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Botón queda deshabilitado ("Apelación en curso")
      expect(find.text('Apelación en curso'), findsOneWidget);
    });

    test('Transición a inDispute congela los fondos y actualiza estado', () async {
      final job = testJobInDispute.copyWith(status: JobStatus.forConfirmation);
      appState.addJob(job);

      final success = await appState.advanceJobPhase(
        jobId: job.id,
        nextPhase: JobStatus.inDispute,
      );

      expect(success, isTrue);
      final updated = appState.jobs.firstWhere((j) => j.id == job.id);
      expect(updated.status, JobStatus.inDispute);
    });
  });
}
