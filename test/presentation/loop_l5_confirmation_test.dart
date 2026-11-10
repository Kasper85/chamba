import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/presentation/screens/job_confirmation_screen.dart';
import 'package:chamba/presentation/screens/post_job_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  late AppState appState;

  setUp(() {
    appState = AppState();
  });

  final testJobForConfirmation = JobRequest(
    id: 'job-confirm-test',
    title: 'Reparación de filtración de lavabo',
    categoryId: 'gasfiteria',
    categoryName: 'Gasfitería',
    description: 'Filtración reparada con sellos nuevos.',
    budget: 80.0,
    district: 'José Leonardo Ortiz, Chiclayo',
    address: 'Av. Balta 1234',
    distanceKm: 1.2,
    urgency: 'Urgente',
    status: JobStatus.forConfirmation,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    clientId: 'client-1',
    clientName: 'Lucía Fernández',
    confirmationCode: '1234',
    securityPin: '1234',
    isPinVerified: true,
    isSos: false,
    escrowStatus: EscrowStatus.afterPhotoUploaded,
    beforePhotoTag: 'Tubería rota y oxidada',
    afterPhotoTag: 'Tubería nueva con teflón y sellos',
    bids: const [],
  );

  testWidgets(
    'JobConfirmationScreen renders title, 24h countdown, before/after evidence and action buttons',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JobConfirmationScreen(
            appState: appState,
            job: testJobForConfirmation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirma tu servicio'), findsOneWidget);
      expect(find.textContaining('Plazo de confirmación:'), findsOneWidget);
      expect(find.text('Evidencia Antes vs Después'), findsOneWidget);
      expect(find.text('Todo bien, liberar pago'), findsOneWidget);
      expect(find.text('Reportar un problema'), findsOneWidget);
      expect(find.text('S/ 80.00'), findsOneWidget);
    },
  );

  testWidgets(
    'JobConfirmationScreen pressing "Todo bien, liberar pago" marks job completed',
    (tester) async {
      appState.addJob(testJobForConfirmation);

      await tester.pumpWidget(
        MaterialApp(
          home: JobConfirmationScreen(
            appState: appState,
            job: testJobForConfirmation,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final releaseButton = find.text('Todo bien, liberar pago');
      expect(releaseButton, findsOneWidget);
      await tester.ensureVisible(releaseButton);
      await tester.pumpAndSettle();
      await tester.tap(releaseButton);
      await tester.pumpAndSettle();

      final updatedJob = appState.jobs.firstWhere((j) => j.id == testJobForConfirmation.id);
      expect(updatedJob.status, JobStatus.completed);
    },
  );

  testWidgets(
    'PostJobScreen blocks publishing when client has a job in forConfirmation',
    (tester) async {
      appState.addJob(testJobForConfirmation);

      expect(appState.hasJobPendingConfirmation, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: PostJobScreen(appState: appState),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el cartel de bloqueo
      expect(find.text('Servicio pendiente de confirmación'), findsOneWidget);
      expect(find.text('Revisar y Confirmar Servicio'), findsOneWidget);
    },
  );
}
