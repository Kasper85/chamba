import 'package:flutter/material.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import 'client_job_tracking_view.dart';
import 'worker_job_tracking_view.dart';

/// Router central de seguimiento que despacha a la vista especializada
/// del cliente o del chambeador según el rol activo (ALCANCE.md §8 L4).
///
/// - Vista cliente: mapa con posición del técnico, PIN de 4 dígitos destacado
///   para dictar en puerta, fotos del antes/después en solo lectura, y confirmación final.
/// - Vista chambeador: mapa con ruta, botón 'Estoy en camino', botón 'Llegué al domicilio',
///   campo para validar PIN del cliente, cámara obligatoria para foto 'Antes' y 'Después'.
/// - Elimina completamente el bloque 'Simular Técnico'.
class JobTrackingScreen extends StatelessWidget {
  final AppState appState;
  final JobRequest job;

  const JobTrackingScreen({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    if (appState.currentRole == UserRole.worker) {
      return WorkerJobTrackingView(
        appState: appState,
        job: job,
      );
    }

    return ClientJobTrackingView(
      appState: appState,
      job: job,
    );
  }
}
