import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/presentation/screens/worker_wallet_screen.dart';
import 'package:chamba/presentation/screens/worker_portfolio_screen.dart';
import 'package:chamba/presentation/screens/worker_my_jobs_screen.dart';
import 'package:chamba/presentation/screens/worker_profile_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/core/theme/app_theme.dart';

void main() {
  group('Worker Refactor UI Tests', () {
    testWidgets('WorkerWalletScreen renders demo badge, balances, charts, and history', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WorkerWalletScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Check title and DEMO indicators
      expect(find.text('Mi Billetera'), findsOneWidget);
      expect(find.text('DEMO'), findsWidgets);
      expect(find.text('Estado de Cuenta'), findsOneWidget);
      expect(find.text('S/. 480.00'), findsOneWidget);
      expect(find.text('S/. 220.00'), findsOneWidget);

      // Check Chart
      expect(find.text('Ingresos Semanales: S/. 700.00'), findsOneWidget);
      expect(find.text('Lun'), findsOneWidget);
      expect(find.text('Sáb'), findsOneWidget);

      // Check Gamification
      expect(find.textContaining('Nivel Plata'), findsOneWidget);
      expect(find.text('142 / 150 chambas (Faltan 8)'), findsOneWidget);

      // Check History
      expect(find.text('Historial de Movimientos'), findsOneWidget);
      expect(find.textContaining('Liberación de Escrow'), findsWidgets);
    });

    testWidgets('WorkerPortfolioScreen renders BeforeAfterSlider and cases', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WorkerPortfolioScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Check header and list
      expect(find.text('Mi Portafolio'), findsOneWidget);
      expect(find.text('Comparador Antes / Después'), findsOneWidget);
      expect(find.textContaining('obras'), findsWidgets);
      expect(find.textContaining('Reparación de Fuga'), findsWidgets);
    });

    testWidgets('WorkerMyJobsScreen renders immediate tabs without top wallet card', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WorkerMyJobsScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Check title and confirm wallet card is removed
      expect(find.text('Mis Trabajos'), findsOneWidget);
      expect(find.text('Mi Billetera'), findsNothing);

      // Check immediate tabs
      expect(find.textContaining('Activas'), findsOneWidget);
      expect(find.textContaining('Negociando'), findsOneWidget);
      expect(find.textContaining('Historial'), findsOneWidget);
    });

    testWidgets('WorkerProfileScreen renders identity, switch mode, and navigable options without duplicate top cards', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WorkerProfileScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Check profile header
      expect(find.text('Mi Perfil de Chambeador'), findsOneWidget);
      expect(find.text(appState.currentWorkerProfile.name), findsOneWidget);

      // Switch mode button
      expect(find.text('Cambiar a Modo Cliente'), findsOneWidget);

      // Navigable options below switch button
      expect(find.text('Mi Portafolio'), findsOneWidget);
      expect(find.text('Mi Billetera y Ganancias'), findsOneWidget);
      expect(find.text('Mis Servicios y Especialidades'), findsOneWidget);
      expect(find.text('Verificación de Identidad'), findsOneWidget);
      expect(find.text('Ayuda y Soporte'), findsOneWidget);
    });
  });
}
