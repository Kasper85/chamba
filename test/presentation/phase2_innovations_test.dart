import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/core/theme/app_theme.dart';
import 'package:chamba/core/widgets/price_dial_stepper.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/presentation/screens/post_job_screen.dart';
import 'package:chamba/presentation/screens/received_bids_screen.dart';
import 'package:chamba/presentation/screens/chat_screen.dart';
import 'package:chamba/presentation/widgets/worker_earnings_dashboard.dart';

void main() {
  group('Fase 2 Innovation Tests', () {
    testWidgets(
      'PriceDialStepper changes Semáforo states based on price ratio',
      (tester) async {
        double currentPrice = 30.0;
        const double recommended = 50.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return PriceDialStepper(
                    currentPrice: currentPrice,
                    recommendedPrice: recommended,
                    onPriceChanged: (newVal) =>
                        setState(() => currentPrice = newVal),
                  );
                },
              ),
            ),
          ),
        );

        // Low price (< 85% of 50 = < 42.5): Baja probabilidad
        expect(
          find.text('Baja probabilidad • Pocos técnicos aceptarán'),
          findsOneWidget,
        );
        expect(find.text('PRECIO BAJO'), findsOneWidget);

        // Tap + until it reaches recommended fair price range (e.g. 50.0)
        await tester.tap(find.text('+S/.20'));
        await tester.pump();
        expect(currentPrice, equals(50.0));
        expect(
          find.text('Precio Justo en tu zona • Alta probabilidad'),
          findsOneWidget,
        );
        expect(find.text('PRECIO JUSTO IA'), findsOneWidget);

        // Tap + until it reaches priority destacada (> 125% of 50 = > 62.5)
        await tester.tap(find.text('+S/.20'));
        await tester.pump();
        expect(currentPrice, equals(70.0));
        expect(
          find.text('Oferta Destacada • Respuesta inmediata'),
          findsOneWidget,
        );
        expect(find.text('OFERTA DESTACADA'), findsOneWidget);
      },
    );

    testWidgets('PostJobScreen opens AI diagnosis sheet with 3 scenarios', (
      tester,
    ) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PostJobScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Tap on AI Visual diagnosis hero card
      expect(find.text('✨ Diagnóstico Visual'), findsOneWidget);
      await tester.tap(find.text('✨ Diagnóstico Visual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify sheet title and the 3 simulated scenarios are presented
      expect(find.text('Diagnóstico Visual con IA'), findsOneWidget);

      // Verify the 3 simulated scenarios are presented
      expect(find.text('Tubería goteando bajo lavadero'), findsOneWidget);
      expect(find.text('Enchufe chispeando en pared'), findsOneWidget);
      expect(find.text('Puerta de madera trabada'), findsOneWidget);
    });

    testWidgets('ReceivedBidsScreen shows filters and voice note player', (
      tester,
    ) async {
      final appState = AppState();
      final job = appState.jobs.firstWhere((j) => j.id == 'job-101');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ReceivedBidsScreen(appState: appState, job: job),
        ),
      );
      await tester.pump();

      // Check quick filter chips
      expect(find.text('⭐ Mejor calificados'), findsOneWidget);
      expect(find.text('⚡ Más rápidos'), findsOneWidget);
      expect(find.text('💰 Precio más bajo'), findsOneWidget);

      // Check that voice note banner & inclusion chips are displayed
      expect(find.text('Nota de Voz del Técnico'), findsWidgets);
      expect(find.text('✓ Incluye materiales'), findsWidgets);
    });

    testWidgets(
      'ChatScreen renders interactive counteroffer with accept and counter actions',
      (tester) async {
        final appState = AppState();
        appState.switchRole(
          UserRole.worker,
        ); // worker perspective receives client offer
        final job = appState.jobs.firstWhere((j) => j.id == 'job-101');

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: ChatScreen(appState: appState, job: job),
          ),
        );
        await tester.pumpAndSettle();

        // Verify bottom quick action button
        expect(find.text('Enviar Contraoferta'), findsOneWidget);

        // Verify in-chat counter-offer card
        expect(find.text('PROPUESTA DE PRECIO'), findsWidgets);
        expect(find.text('Aceptar S/. 70'), findsOneWidget);
        expect(find.text('Contraofertar'), findsWidgets);

        // Tap Aceptar S/. 70 directly
        await tester.tap(find.text('Aceptar S/. 70'));
        await tester.pumpAndSettle();

        // Job budget should now be updated to S/. 70 in AppState
        final updatedJob = appState.jobs.firstWhere((j) => j.id == 'job-101');
        expect(updatedJob.budget, equals(70.0));
        expect(
          find.text('¡Trato Aceptado! Presupuesto fijado'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'WorkerEarningsDashboard renders wallet balances, weekly bar chart and gamification level',
      (tester) async {
        final appState = AppState();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkerEarningsDashboard(appState: appState),
              ),
            ),
          ),
        );
        await tester.pump();

        // Verify header and balances
        expect(find.text('Mi Billetera y Rendimiento Semanal'), findsOneWidget);
        expect(find.text('S/. 480.00'), findsOneWidget);
        expect(find.text('S/. 220.00'), findsOneWidget);
        expect(find.text('Retirar'), findsOneWidget);

        // Verify weekly pure Flutter chart days
        expect(find.text('Lun'), findsOneWidget);
        expect(find.text('Mar'), findsOneWidget);
        expect(find.text('Mié'), findsOneWidget);
        expect(find.text('Jue'), findsOneWidget);
        expect(find.text('Vie'), findsOneWidget);
        expect(find.text('Sáb'), findsOneWidget);
        expect(find.text('Dom'), findsOneWidget);

        // Verify Gamification Level
        expect(find.text('Nivel Plata'), findsOneWidget);
        expect(find.text('Próximo: Maestro Chamba Oro'), findsOneWidget);
        expect(
          find.text('0% comisión en tus próximas 3 chambas SOS desbloqueado.'),
          findsOneWidget,
        );
      },
    );
  });
}
