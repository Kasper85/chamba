import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/bid.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/data/models/wallet_summary.dart';
import 'package:chamba/presentation/screens/send_bid_screen.dart';
import 'package:chamba/presentation/screens/received_bids_screen.dart';
import 'package:chamba/presentation/screens/worker_wallet_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  group('Loop L3 — Escrow, Comisión y Ledger Tests', () {
    late AppState appState;
    late JobRequest testJob;

    setUp(() {
      appState = AppState();
      testJob = JobRequest(
        id: 'job-l3-test',
        title: 'Instalación de tomacorriente',
        description: 'Tomacorriente doble en sala',
        categoryId: 'cat-elec',
        categoryName: 'Electricidad',
        clientId: 'client-1',
        clientName: 'Juan Pérez',
        address: 'Calle Real 123',
        budget: 100.0,
        latitude: -6.7713,
        longitude: -79.8409,
        district: 'Chiclayo',
        distanceKm: 1.2,
        urgency: 'Media',
        confirmationCode: 'CH-1234',
        createdAt: DateTime.now(),
        status: JobStatus.searching,
        escrowStatus: EscrowStatus.pendingDeposit,
        bids: [
          Bid(
            id: 'bid-1',
            jobId: 'job-l3-test',
            workerId: 'worker-1',
            workerName: 'Carlos Técnico',
            workerAvatar: 'C',
            workerRating: 4.8,
            workerCompletedJobs: 25,
            isWorkerVerified: true,
            amount: 100.0,
            etaMinutes: 20,
            message: 'Puedo hacerlo hoy',
            status: BidStatus.pending,
            createdAt: DateTime.now(),
          ),
        ],
      );
      appState.activeJob = testJob;
    });

    testWidgets('SendBidScreen muestra advertencia transparente de 8% de comisión', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SendBidScreen(
            appState: appState,
            job: testJob,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe mostrar el texto con desglose de comisión: S/ 100 -> S/ 92 (comisión 8%)
      expect(find.textContaining('comisión 8%'), findsOneWidget);
      expect(find.textContaining('Ofertas S/ 100 → recibes S/ 92'), findsOneWidget);
    });

    testWidgets('ReceivedBidsScreen muestra hoja de pago en garantía con desglose formal (S/ 100 + S/ 2 = S/ 102)', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ReceivedBidsScreen(
            appState: appState,
            job: testJob,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Botón para aceptar oferta
      final acceptButtonFinder = find.text('Aceptar S/. 100');
      expect(acceptButtonFinder, findsOneWidget);

      await tester.ensureVisible(acceptButtonFinder);
      await tester.tap(acceptButtonFinder);
      await tester.pumpAndSettle();

      // Verifica desglose formal en el BottomSheet
      expect(find.text('Pago en Garantía (Escrow)'), findsOneWidget);
      expect(find.text('Precio de la chamba:'), findsOneWidget);
      expect(find.text('Tarifa de servicio CHAMBA:'), findsOneWidget);
      expect(find.text('Total a retener en garantía:'), findsOneWidget);
      expect(find.text('S/ 100 + S/ 2 tarifa = S/ 102'), findsOneWidget);
      expect(find.text('Confirmar y Retener S/ 102.00'), findsOneWidget);
    });

    testWidgets('WorkerWalletScreen muestra etiquetas reales del Libro Mayor', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockWallet = WalletSummary(
        walletId: 'wallet-test',
        userId: 'worker-1',
        availableBalance: 92.0,
        inEscrowBalance: 0.0,
        totalBalance: 92.0,
        currency: 'PEN',
        recentTransactions: [
          WalletTransaction(
            id: 'tx-1',
            amount: 92.0,
            type: 'RELEASE_ESCROW',
            description: 'Liberación de pago por trabajo completado',
            createdAt: DateTime.now(),
          ),
          WalletTransaction(
            id: 'tx-2',
            amount: 10.0,
            type: 'COMPENSATION',
            description: 'Compensación por cancelación',
            createdAt: DateTime.now(),
          ),
          WalletTransaction(
            id: 'tx-3',
            amount: -102.0,
            type: 'HOLD_ESCROW',
            description: 'Depósito en garantía',
            createdAt: DateTime.now(),
          ),
        ],
      );

      appState.walletSummary = mockWallet;

      await tester.pumpWidget(
        MaterialApp(
          home: WorkerWalletScreen(appState: appState),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Liberación de garantía'), findsOneWidget);
      expect(find.text('Compensación por cancelación'), findsOneWidget);
      expect(find.text('Depósito en garantía'), findsOneWidget);
    });
  });
}
