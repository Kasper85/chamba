import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/presentation/widgets/chamba_interactive_map.dart';

void main() {
  for (final mode in [MapDisplayMode.approximate, MapDisplayMode.tracking]) {
    testWidgets(
      'worker map pans and zooms in $mode without moving service marker',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ChambaInteractiveMap(mode: mode)),
          ),
        );
        await tester.pump();
        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final controller = map.mapController!;
        final center = controller.camera.center;
        expect(map.options.onTap, isNull);
        await tester.drag(find.byType(FlutterMap), const Offset(60, 0));
        await tester.pump(const Duration(milliseconds: 300));
        expect(controller.camera.center, isNot(center));
        final zoom = controller.camera.zoom;
        await tester.tap(find.byTooltip('Acercar mapa'));
        await tester.pump();
        expect(controller.camera.zoom, zoom + 1);
        await tester.tap(find.byTooltip('Alejar mapa'));
        await tester.pump();
        expect(controller.camera.zoom, zoom);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
