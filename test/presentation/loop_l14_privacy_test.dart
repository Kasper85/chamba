import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/data/models/user_account.dart';
import 'package:chamba/presentation/screens/dispute_detail_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  final testJobInDispute = JobRequest(
    id: 'job-l14-test',
    title: 'Reparación de filtración de tubería',
    categoryId: 'gasfiteria',
    categoryName: 'Gasfitería',
    description: 'Filtración en lavadero de cocina',
    budget: 60.0,
    district: 'Chiclayo Centro',
    address: 'Av. Balta 1200',
    distanceKm: 1.2,
    urgency: 'ALTA',
    status: JobStatus.completed,
    createdAt: DateTime.now(),
    clientId: 'client-test-1',
    clientName: 'María Ramos',
    confirmationCode: '1234',
    securityPin: '1234',
    workerId: 'worker-test-1',
    workerName: 'Carlos Gómez',
    escrowStatus: EscrowStatus.released,
  );

  group('Loop L14 - Control de Acceso y Privacidad en UI (§3, §8 L14)', () {
    testWidgets('Disputa resuelta muestra nombre de operador sin correo cuando este se omite por privacidad', (tester) async {
      final appState = AppState();
      final clientUser = UserAccount(
        id: 'client-test-1',
        fullName: 'María Ramos',
        email: 'maria@gmail.com',
        role: 'CLIENT',
      );
      appState.currentUser = clientUser;

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: testJobInDispute,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el banner resuelto con Operador de Soporte Oficial y NO correo ajeno
      expect(find.textContaining('Disputa Resuelta por Soporte Humano'), findsOneWidget);
      expect(find.textContaining('Operador de Soporte'), findsWidgets);
      // No debe contener emails en pantalla para cliente
      expect(find.textContaining('@chamba.pe'), findsNothing);
    });

    testWidgets('Cliente (CLIENT) nunca ve el botón de resolver soporte', (tester) async {
      final appState = AppState();
      appState.currentUser = UserAccount(
        id: 'client-test-1',
        fullName: 'María Ramos',
        email: 'maria@gmail.com',
        role: 'CLIENT',
      );

      final jobActive = testJobInDispute.copyWith(status: JobStatus.inDispute);

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: jobActive,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolver Disputa (Operador de Soporte)'), findsNothing);
    });

    testWidgets('Técnico (WORKER) nunca ve el botón de resolver soporte', (tester) async {
      final appState = AppState();
      appState.currentUser = UserAccount(
        id: 'worker-test-1',
        fullName: 'Carlos Gómez',
        email: 'carlos@gmail.com',
        role: 'WORKER',
      );

      final jobActive = testJobInDispute.copyWith(status: JobStatus.inDispute);

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: jobActive,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolver Disputa (Operador de Soporte)'), findsNothing);
    });
  });
}
