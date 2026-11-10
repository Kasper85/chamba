import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/core/widgets/price_dial_stepper.dart';
import 'package:chamba/presentation/screens/post_job_screen.dart';
import 'package:chamba/presentation/state/app_state.dart';

void main() {
  group('Loop L10 - Precio mínimo y alerta de IA (§3, §8 L10)', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets('PriceDialStepper tiene piso mínimo duro de S/ 20.0', (WidgetTester tester) async {
      double currentPrice = 20.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                return PriceDialStepper(
                  currentPrice: currentPrice,
                  recommendedPrice: 50.0,
                  minPrice: 20.0,
                  onPriceChanged: (newVal) => setState(() => currentPrice = newVal),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Debe mostrar S/. 20
      expect(find.text('20'), findsOneWidget);

      // El botón de restar debe estar deshabilitado al estar en el piso mínimo de S/ 20
      final minusButton = find.byIcon(Icons.remove);
      expect(minusButton, findsOneWidget);
      await tester.tap(minusButton);
      await tester.pump();

      // El precio se mantiene en S/ 20 sin bajar
      expect(currentPrice, 20.0);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('PriceDialStepper muestra alerta suave de IA si precio es < 50% del estimado', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceDialStepper(
              currentPrice: 30.0,
              recommendedPrice: 100.0, // 30 < 50% de 100
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Alerta de IA: El precio es menor al 50% del estimado'), findsOneWidget);
    });

    testWidgets('PriceDialStepper muestra alerta suave de IA si precio es > 300% del estimado', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceDialStepper(
              currentPrice: 350.0,
              recommendedPrice: 100.0, // 350 > 300% de 100
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Alerta de IA: El precio supera el 300% del estimado'), findsOneWidget);
    });

    testWidgets('PriceDialStepper no muestra alerta de IA si precio está en rango óptimo', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceDialStepper(
              currentPrice: 90.0,
              recommendedPrice: 100.0, // 90 está dentro de [50%, 300%]
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Alerta de IA:'), findsNothing);
    });

    testWidgets('PostJobScreen muestra diálogo "¿Seguro del precio?" al desviarse del estimado', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PostJobScreen(appState: appState),
        ),
      );
      await tester.pump();

      // Ajustar stepper para subir el precio por encima de 300% de 50 (ej. S/ 160 o más)
      final plusButton = find.byIcon(Icons.add);
      await tester.ensureVisible(plusButton);
      for (int i = 0; i < 25; i++) {
        await tester.tap(plusButton);
        await tester.pump(const Duration(milliseconds: 50));
      }

      final publishButton = find.text('Publicar Solicitud en Chiclayo');
      await tester.ensureVisible(publishButton);
      await tester.tap(publishButton);
      await tester.pump(const Duration(milliseconds: 300));

      // Debe mostrar el diálogo de confirmación suave de IA
      expect(find.text('¿Seguro del precio?'), findsOneWidget);
      expect(find.text('Sí, continuar'), findsOneWidget);
      expect(find.text('Revisar precio'), findsOneWidget);

      // Si toca "Revisar precio", cierra el diálogo y no publica
      await tester.tap(find.text('Revisar precio'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¿Seguro del precio?'), findsNothing);
    });
  });
}
