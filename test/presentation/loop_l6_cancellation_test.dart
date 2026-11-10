import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/presentation/screens/client_job_tracking_view.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  late AppState appState;

  setUp(() {
    appState = AppState();
  });

  JobRequest createTestJob({
    required String id,
    required JobStatus status,
    double budget = 100.0,
    EscrowStatus escrowStatus = EscrowStatus.heldInEscrow,
  }) {
    return JobRequest(
      id: id,
      title: 'Reparación de Cerradura',
      categoryId: 'cerrajeria',
      categoryName: 'Cerrajería',
      description: 'Chapa trabada en puerta principal',
      budget: budget,
      district: 'Chiclayo',
      address: 'Av. Balta 450, Chiclayo',
      distanceKm: 1.2,
      urgency: 'ALTA',
      status: status,
      createdAt: DateTime.now(),
      clientId: 'client-1',
      clientName: 'María García',
      confirmationCode: '7412',
      securityPin: '7412',
      workerId: 'worker-1',
      workerName: 'Juan Pérez',
      escrowStatus: escrowStatus,
    );
  }

  group('Loop L6 - Matriz de Cancelación (§4)', () {
    test('Cancelación con técnico EN_CAMINO otorga compensación 10% (mín S/ 5, máx S/ 20) al técnico', () async {
      // Precio P = S/ 100 -> Compensación 10% = S/ 10. Reembolso cliente: 102 - 10 = S/ 92
      final job = createTestJob(id: 'job-l6-camino', status: JobStatus.onTheWay, budget: 100.0);
      appState.addJob(job);

      final success = await appState.cancelJob(job.id, isWorkerDelay: false);

      expect(success, isTrue);
      final updatedJob = appState.jobs.firstWhere((j) => j.id == job.id);
      expect(updatedJob.status, JobStatus.cancelled);
      expect(updatedJob.escrowStatus, EscrowStatus.refunded);

      // Notificación con desglose
      final notif = appState.notifications.firstWhere((n) => n.relatedJobId == job.id);
      expect(notif.body, contains('Compensación al técnico: S/ 10.00'));
      expect(notif.body, contains('Reembolso: S/ 92.00'));
    });

    test('Compensación respeta límites mín S/ 5 y máx S/ 20', () async {
      // 1. Caso mínimo: P = S/ 30 -> 10% = S/ 3 -> acotado a S/ 5. Reembolso: 32 - 5 = S/ 27
      final jobMin = createTestJob(id: 'job-l6-min', status: JobStatus.onTheWay, budget: 30.0);
      appState.addJob(jobMin);
      await appState.cancelJob(jobMin.id, isWorkerDelay: false);
      final notifMin = appState.notifications.firstWhere((n) => n.relatedJobId == jobMin.id);
      expect(notifMin.body, contains('Compensación al técnico: S/ 5.00'));
      expect(notifMin.body, contains('Reembolso: S/ 27.00'));

      // 2. Caso máximo: P = S/ 300 -> 10% = S/ 30 -> acotado a S/ 20. Reembolso: 302 - 20 = S/ 282
      final jobMax = createTestJob(id: 'job-l6-max', status: JobStatus.onTheWay, budget: 300.0);
      appState.addJob(jobMax);
      await appState.cancelJob(jobMax.id, isWorkerDelay: false);
      final notifMax = appState.notifications.firstWhere((n) => n.relatedJobId == jobMax.id);
      expect(notifMax.body, contains('Compensación al técnico: S/ 20.00'));
      expect(notifMax.body, contains('Reembolso: S/ 282.00'));
    });

    test('Cancelación por retraso del técnico (>30 min) otorga reembolso total sin compensación', () async {
      final jobDelay = createTestJob(id: 'job-l6-delay', status: JobStatus.onTheWay, budget: 100.0);
      appState.addJob(jobDelay);

      final success = await appState.cancelJob(jobDelay.id, isWorkerDelay: true);

      expect(success, isTrue);
      final updatedJob = appState.jobs.firstWhere((j) => j.id == jobDelay.id);
      expect(updatedJob.status, JobStatus.cancelled);

      final notif = appState.notifications.firstWhere((n) => n.relatedJobId == jobDelay.id);
      expect(notif.body, contains('Reembolso total: S/ 102.00'));
      expect(notif.body, isNot(contains('Compensación al técnico')));
    });

    test('Rechaza cancelación directa si el PIN ya fue validado (inProgress o forConfirmation)', () async {
      final jobInProgress = createTestJob(id: 'job-l6-progress', status: JobStatus.inProgress);
      appState.addJob(jobInProgress);

      final result1 = await appState.cancelJob(jobInProgress.id);
      expect(result1, isFalse);

      final jobForConf = createTestJob(id: 'job-l6-conf', status: JobStatus.forConfirmation);
      appState.addJob(jobForConf);

      final result2 = await appState.cancelJob(jobForConf.id);
      expect(result2, isFalse);
    });

    testWidgets('ClientJobTrackingView muestra diálogo con reglas de cancelación y ejecuta reembolso', (tester) async {
      final job = createTestJob(id: 'job-l6-ui', status: JobStatus.onTheWay, budget: 80.0);
      appState.addJob(job);

      await tester.pumpWidget(
        MaterialApp(
          home: ClientJobTrackingView(
            appState: appState,
            job: job,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Botón cancelar en la AppBar
      final cancelIcon = find.byIcon(Icons.cancel_outlined);
      expect(cancelIcon, findsOneWidget);
      await tester.tap(cancelIcon);
      await tester.pump(const Duration(milliseconds: 300));

      // Diálogo con explicación de compensación
      expect(find.text('¿Cancelar solicitud?'), findsOneWidget);
      expect(find.textContaining('compensación de S/ 8.00'), findsOneWidget);

      // Confirmar cancelación
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Cancelar');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump(const Duration(milliseconds: 300));

      final updated = appState.jobs.firstWhere((j) => j.id == job.id);
      expect(updated.status, JobStatus.cancelled);
    });
  });
}
