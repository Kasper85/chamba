import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/presentation/screens/rating_receipt_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';
import 'package:chamba/data/models/job_request.dart';

void main() {
  group('Loop L8 - Calificación, recibo y notificaciones (§6, §8 L8)', () {
    late AppState appState;
    late JobRequest testJob;

    setUp(() {
      appState = AppState();
      testJob = JobRequest(
        id: 'job-l8-test',
        title: 'Reparación de Fuga en Baño',
        description: 'Tubería rota bajo el lavamanos en Chiclayo',
        categoryId: 'gasfiteria',
        categoryName: 'Gasfitería',
        budget: 100.0,
        district: 'Chiclayo',
        address: 'Calle San José 321, Chiclayo',
        distanceKm: 1.5,
        urgency: 'MEDIA',
        createdAt: DateTime.now(),
        clientId: 'client-1',
        confirmationCode: '1234',
        status: JobStatus.completed,
        clientName: 'Juan Pérez',
        workerName: 'Carlos Mendoza',
        beforePhotoTag: 'foto_antes_lavamanos.jpg',
        afterPhotoTag: 'foto_despues_reparado.jpg',
      );
      appState.addJob(testJob);
    });

    testWidgets('Muestra selector de estrellas, chips de propina y recibo formal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RatingReceiptScreen(
            appState: appState,
            job: testJob,
          ),
        ),
      );
      await tester.pump();

      // Verifica título y experiencia
      expect(find.text('Calificación y Recibo'), findsOneWidget);
      expect(find.textContaining('Carlos Mendoza'), findsOneWidget);

      // Verifica selector de 5 estrellas grandes
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star_rounded && w.size == 38),
        findsNWidgets(5),
      );

      // Verifica selector de propinas voluntarias
      expect(find.text('Propina voluntaria para el técnico'), findsOneWidget);
      expect(find.textContaining('El 100% de la propina va directamente al técnico'), findsOneWidget);
      expect(find.text('Sin propina'), findsOneWidget);
      expect(find.text('S/ 5'), findsOneWidget);
      expect(find.text('S/ 10'), findsOneWidget);
      expect(find.text('S/ 15'), findsOneWidget);

      // Verifica recibo formal con desglose financiero
      expect(find.text('Recibo de Servicio'), findsOneWidget);
      expect(find.text('Precio acordado (P):'), findsOneWidget);
      expect(find.text('S/ 100.00'), findsOneWidget);
      expect(find.text('Tarifa de servicio (plataforma):'), findsOneWidget);
      expect(find.text('S/ 2.00'), findsOneWidget);
      expect(find.text('Comisión del 8% (deducida al técnico):'), findsOneWidget);
      expect(find.text('- S/ 8.00'), findsOneWidget);

      // Total cliente sin propina inicial = 100 + 2 = 102
      expect(find.text('Total abonado por cliente:'), findsOneWidget);
      expect(find.text('S/ 102.00'), findsOneWidget);

      // Fotos de evidencia en el recibo
      expect(find.text('Antes'), findsOneWidget);
      expect(find.text('Después'), findsOneWidget);
    });

    testWidgets('Al seleccionar propina de S/ 10 se actualiza el total abonado a S/ 112.00', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RatingReceiptScreen(
            appState: appState,
            job: testJob,
          ),
        ),
      );
      await tester.pump();

      // Selecciona chip S/ 10
      await tester.tap(find.text('S/ 10'));
      await tester.pump();

      // Total cliente ahora debe ser S/ 112.00 (100 + 2 + 10)
      expect(find.text('S/ 112.00'), findsOneWidget);
      expect(find.text('+ S/ 10.00'), findsOneWidget);
    });

    testWidgets('Enviar calificación guarda rating y genera notificación', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RatingReceiptScreen(
            appState: appState,
            job: testJob,
          ),
        ),
      );
      await tester.pump();

      // Cambia a 4 estrellas (toca el 4to icono de estrella)
      final starIcons = find.byIcon(Icons.star_rounded);
      await tester.tap(starIcons.at(3));
      await tester.pump();

      // Agrega propina de S/ 5
      await tester.tap(find.text('S/ 5'));
      await tester.pump();

      // Escribe comentario
      await tester.enterText(find.byType(TextField), 'Excelente trabajo y muy puntual');
      await tester.pump();

      // Toca botón de envío
      final submitButton = find.text('Enviar Calificación y Cerrar');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      // Verifica notificación en AppState
      expect(appState.notifications.isNotEmpty, isTrue);
      expect(appState.notifications.first.title, 'Calificación registrada');
      expect(appState.notifications.first.body, contains('4 estrellas'));
      expect(appState.notifications.first.body, contains('S/ 5'));
    });
  });
}
