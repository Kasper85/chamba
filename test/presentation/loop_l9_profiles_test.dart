import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/presentation/screens/user_profile_screen.dart';
import 'package:chamba/presentation/screens/available_jobs_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/data/models/job_request.dart';

void main() {
  group('Loop L9 - Perfiles y datos reales (§7, §8 L9)', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      // Agregamos solicitudes para probar el cómputo dinámico de métricas
      final job1 = JobRequest(
        id: 'job-l9-1',
        title: 'Reparación de Cañería',
        description: 'Fuga de agua',
        categoryId: 'gasfiteria',
        categoryName: 'Gasfitería',
        budget: 80.0,
        district: 'Chiclayo',
        address: 'Calle San José 120, Chiclayo',
        distanceKm: 1.0,
        urgency: 'MEDIA',
        createdAt: DateTime.now(),
        clientId: 'client-1',
        clientName: 'Juan Pérez',
        confirmationCode: '1111',
        status: JobStatus.completed,
        rating: 5,
      );
      final job2 = JobRequest(
        id: 'job-l9-2',
        title: 'Instalación de Tomacorriente',
        description: 'Cortocircuito en cocina',
        categoryId: 'electricidad',
        categoryName: 'Electricidad',
        budget: 60.0,
        district: 'Chiclayo',
        address: 'Av. Balta 450, Chiclayo',
        distanceKm: 2.0,
        urgency: 'ALTA',
        createdAt: DateTime.now(),
        clientId: 'client-1',
        clientName: 'Juan Pérez',
        confirmationCode: '2222',
        status: JobStatus.completed,
        rating: 4,
      );
      final job3 = JobRequest(
        id: 'job-l9-3',
        title: 'Pintado de Fachada',
        description: 'Fachada de dos pisos',
        categoryId: 'pintura',
        categoryName: 'Pintura',
        budget: 200.0,
        district: 'Chiclayo',
        address: 'Calle Elías Aguirre 330, Chiclayo',
        distanceKm: 1.5,
        urgency: 'BAJA',
        createdAt: DateTime.now(),
        clientId: 'client-1',
        clientName: 'Juan Pérez',
        confirmationCode: '3333',
        status: JobStatus.searching,
      );

      appState.addJob(job1);
      appState.addJob(job2);
      appState.addJob(job3);
    });

    testWidgets('UserProfileScreen muestra métricas calculadas y no valores fijos', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Métricas calculadas en sus respectivos cuadros:
      final publicadasFinder = find.ancestor(
        of: find.text('Publicadas'),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: publicadasFinder, matching: find.text('${appState.clientJobsCount}')),
        findsOneWidget,
      );

      final completadasFinder = find.ancestor(
        of: find.text('Completadas'),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: completadasFinder, matching: find.text('${appState.clientCompletedJobsCount}')),
        findsOneWidget,
      );

      // Calificación promedio calculada
      expect(find.text('${appState.clientAverageRating.toStringAsFixed(1)} ★'), findsOneWidget);
      expect(find.text('Calificación'), findsOneWidget);
    });

    testWidgets('Botón Direcciones Frecuentes abre modal con direcciones de Chiclayo', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Tap en Direcciones Frecuentes
      final addressesOption = find.text('Direcciones Frecuentes');
      await tester.ensureVisible(addressesOption);
      await tester.tap(addressesOption);
      await tester.pumpAndSettle();

      expect(find.text('Mis Direcciones Guardadas'), findsOneWidget);
      expect(find.text('Casa (Principal)'), findsOneWidget);
      expect(find.text('Por defecto'), findsOneWidget);
      expect(find.text('Agregar Nueva Dirección'), findsOneWidget);
    });

    testWidgets('Botón Métodos de Pago Preferidos abre modal con aviso de pagos simulados', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Tap en Métodos de Pago
      final paymentOption = find.text('Métodos de Pago Preferidos');
      await tester.ensureVisible(paymentOption);
      await tester.tap(paymentOption);
      await tester.pumpAndSettle();

      expect(find.text('Métodos de Pago Preferidos'), findsNWidgets(2)); // Tile + Modal Header
      expect(find.textContaining('Pagos 100% simulados'), findsOneWidget);
      expect(find.text('Yape / Plin (Simulado)'), findsOneWidget);
      expect(find.text('Tarjeta Débito/Crédito (Simulada)'), findsOneWidget);
    });

    testWidgets('Botón Seguridad y Verificación DNI muestra etiqueta DEMO explícita', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Tap en Verificación DNI
      final dniOption = find.text('Seguridad y Verificación DNI');
      await tester.ensureVisible(dniOption);
      await tester.tap(dniOption);
      await tester.pumpAndSettle();

      expect(find.text('DEMO'), findsOneWidget);
      expect(find.textContaining('integración oficial con RENIEC'), findsOneWidget);
      expect(find.text('DNI Registrado'), findsOneWidget);
    });

    testWidgets('Botón Soporte y Ayuda abre canales de atención WhatsApp Chiclayo', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserProfileScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Tap en Soporte y Ayuda
      final supportOption = find.text('Soporte y Ayuda');
      await tester.ensureVisible(supportOption);
      await tester.tap(supportOption);
      await tester.pumpAndSettle();

      expect(find.text('Soporte y Ayuda CHAMBA'), findsOneWidget);
      expect(find.text('WhatsApp Soporte Directo'), findsOneWidget);
      expect(find.textContaining('+51 974 812 345'), findsOneWidget);
      expect(find.text('soporte@chamba.pe'), findsOneWidget);
    });

    testWidgets('Switch de disponibilidad en AvailableJobsScreen persiste en AppState', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AvailableJobsScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Inicialmente disponible
      expect(appState.isWorkerAvailable, isTrue);
      expect(find.text('Disponible para recibir ofertas'), findsOneWidget);

      // Alternar switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();

      // Ahora no disponible
      expect(appState.isWorkerAvailable, isFalse);
      expect(find.text('No disponible'), findsOneWidget);
    });
  });
}
