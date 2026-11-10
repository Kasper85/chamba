import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/presentation/screens/app_shell_gate.dart';
import 'package:chamba/presentation/screens/client_shell.dart';
import 'package:chamba/presentation/screens/worker_shell.dart';
import 'package:chamba/presentation/screens/client_home_screen.dart';
import 'package:chamba/presentation/screens/available_jobs_screen.dart';
import 'package:chamba/presentation/screens/user_profile_screen.dart';
import 'package:chamba/core/widgets/role_switcher_pill.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/core/theme/app_theme.dart';

void main() {
  group('Loop L0 — Estabilidad y limpieza', () {
    testWidgets(
      'AppShellGate handles 10 consecutive role switches without crash',
      (tester) async {
        final appState = AppState();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: AppShellGate(appState: appState),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Starts in Client mode
        expect(find.byType(ClientShell), findsOneWidget);
        expect(find.byType(WorkerShell), findsNothing);

        // Switch role 10 times consecutively
        for (int i = 0; i < 10; i++) {
          if (i.isEven) {
            appState.switchRole(UserRole.worker);
          } else {
            appState.switchRole(UserRole.client);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          if (i.isEven) {
            expect(find.byType(WorkerShell), findsOneWidget);
            expect(find.byType(ClientShell), findsNothing);
          } else {
            expect(find.byType(ClientShell), findsOneWidget);
            expect(find.byType(WorkerShell), findsNothing);
          }
        }
      },
    );

    testWidgets('RoleSwitcherPill is eliminated from headers', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: ClientHomeScreen(appState: appState)),
        ),
      );
      await tester.pump();
      expect(find.byType(RoleSwitcherPill), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: AvailableJobsScreen(appState: appState)),
        ),
      );
      await tester.pump();
      expect(find.byType(RoleSwitcherPill), findsNothing);
    });

    testWidgets(
      'ClientHomeScreen uses clientJobs count equal to appState.clientJobs',
      (tester) async {
        final appState = AppState();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: ClientHomeScreen(appState: appState)),
          ),
        );
        await tester.pump();

        final expectedCount = appState.clientJobs.length;
        expect(find.text('$expectedCount en curso'), findsOneWidget);
      },
    );

    testWidgets('Worker cabecita switches to Mi Perfil tab in WorkerShell', (
      tester,
    ) async {
      final appState = AppState();
      appState.switchRole(UserRole.worker);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: WorkerShell(appState: appState),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should be on Chambas tab initially
      expect(find.byType(AvailableJobsScreen), findsOneWidget);

      // Tap on worker cabecita (Icons.person_outline) in AvailableJobsScreen
      final profileIcon = find.byTooltip('Mi Perfil de Técnico');
      expect(profileIcon, findsOneWidget);
      await tester.tap(profileIcon);
      await tester.pumpAndSettle();

      // WorkerShell should now have switched to Mi Perfil tab
      expect(find.text('Mi Perfil de Chambeador'), findsOneWidget);
    });

    testWidgets('UserProfileScreen does NOT have Elegir Modo de Uso tile', (
      tester,
    ) async {
      final appState = AppState();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: UserProfileScreen(appState: appState)),
        ),
      );
      await tester.pump();

      expect(find.text('Elegir Modo de Uso'), findsNothing);
      expect(find.text('Cambiar a Modo Chambeador'), findsOneWidget);
    });
  });
}
