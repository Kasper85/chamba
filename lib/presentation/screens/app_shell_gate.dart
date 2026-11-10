import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'client_shell.dart';
import 'worker_shell.dart';

/// Gate central de navegación de rol para CHAMBA Perú.
///
/// Un único punto de control que escucha [AppState] y conmuta limpiamente
/// entre [ClientShell] y [WorkerShell] sin invocar [Navigator.pushReplacement]
/// dentro de los shells, evitando bucles de navegación y carreras de estado.
class AppShellGate extends StatelessWidget {
  final AppState appState;

  const AppShellGate({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (appState.isWorker) {
          return WorkerShell(
            key: const ValueKey('WorkerShell'),
            appState: appState,
          );
        }
        return ClientShell(
          key: const ValueKey('ClientShell'),
          appState: appState,
        );
      },
    );
  }
}

