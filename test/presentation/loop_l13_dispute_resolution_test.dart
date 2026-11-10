import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/data/models/user_account.dart';
import 'package:chamba/presentation/screens/dispute_detail_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  final testJobInDispute = JobRequest(
    id: 'job-l13-test',
    title: 'Reparación de filtración de tubería',
    categoryId: 'gasfiteria',
    categoryName: 'Gasfitería',
    description: 'Filtración en lavadero de cocina',
    budget: 60.0,
    district: 'José Leonardo Ortiz',
    address: 'Av. Balta 1200',
    distanceKm: 1.2,
    urgency: 'ALTA',
    status: JobStatus.inDispute,
    createdAt: DateTime.now(),
    clientId: 'client-test-1',
    clientName: 'María Ramos',
    confirmationCode: '1234',
    securityPin: '1234',
    workerId: 'worker-test-1',
    workerName: 'Carlos Gómez',
    escrowStatus: EscrowStatus.heldInEscrow,
  );

  group('Loop L13 - Seguridad de Roles y Resolución Dinámica de Disputas (§5, §8)', () {
    testWidgets('Cliente normal (role: CLIENT) NO ve el botón de resolver disputa', (tester) async {
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

      // Botón de soporte NO debe existir para el cliente
      expect(find.text('Resolver Disputa (Operador de Soporte)'), findsNothing);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);
    });

    testWidgets('Chambeador (role: WORKER) NO ve el botón de resolver disputa', (tester) async {
      final appState = AppState();
      final workerUser = UserAccount(
        id: 'worker-test-1',
        fullName: 'Carlos Gómez',
        email: 'carlos@gmail.com',
        role: 'WORKER',
      );
      appState.currentUser = workerUser;

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: testJobInDispute,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Botón de soporte NO debe existir para el técnico
      expect(find.text('Resolver Disputa (Operador de Soporte)'), findsNothing);
    });

    testWidgets('Usuario de soporte (role: SUPPORT) SÍ ve el botón de resolver disputa', (tester) async {
      final appState = AppState();
      final supportUser = UserAccount(
        id: 'support-test-1',
        fullName: 'Operador Chamba Soporte',
        email: 'soporte@chamba.pe',
        role: 'SUPPORT',
      );
      appState.currentUser = supportUser;

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: testJobInDispute,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Botón de soporte DEBE ser visible para el operador
      expect(find.text('Resolver Disputa (Operador de Soporte)'), findsOneWidget);
    });

    testWidgets('Liquidación de disputa muestra datos dinámicos del ledger y fórmula del invariante', (tester) async {
      final appState = AppState();
      final completedJob = testJobInDispute.copyWith(
        status: JobStatus.completed,
        budget: 60.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DisputeDetailScreen(
            appState: appState,
            job: completedJob,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner resuelto debe estar visible
      expect(find.text('Disputa Resuelta por Soporte Humano'), findsOneWidget);
      expect(find.text('Liquidación Contable del Escrow (Invariante estricto):'), findsOneWidget);
      // Depósito total dinámico: 60 + 2 = S/ 62.00
      expect(find.text('S/ 62.00'), findsOneWidget);
      // Reembolso dinámico (50% de 60): S/ 30.00
      expect(find.text('S/ 30.00'), findsOneWidget);
      // Pago técnico dinámico (30 - 8% com = 27.60): S/ 27.60
      expect(find.text('S/ 27.60'), findsOneWidget);
      // Comisión 8%: S/ 2.40
      expect(find.text('S/ 2.40'), findsOneWidget);
      // Tarifa fija: S/ 2.00
      expect(find.text('S/ 2.00'), findsOneWidget);
      // Fórmula del invariante calculada dinámicamente con los números
      expect(find.textContaining('Invariante:'), findsOneWidget);
      expect(find.textContaining('62 = 30 + 28 + 2 + 2'), findsOneWidget);
    });
  });
}
