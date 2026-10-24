import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../state/app_state.dart';
import 'available_jobs_screen.dart';
import 'worker_my_jobs_screen.dart';
import 'messages_inbox_screen.dart';
import 'worker_profile_screen.dart';
import 'client_shell.dart';

class WorkerShell extends StatefulWidget {
  final AppState appState;
  final int initialIndex;

  const WorkerShell({
    super.key,
    required this.appState,
    this.initialIndex = 0,
  });

  @override
  State<WorkerShell> createState() => _WorkerShellState();
}

class _WorkerShellState extends State<WorkerShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    widget.appState.addListener(_onStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.appState.syncWorkerLocation();
      }
    });
  }

  void _onStateChange() {
    if (mounted) {
      if (widget.appState.isClient) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (context, animation, secondaryAnimation) => ClientShell(appState: widget.appState),
            transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      AvailableJobsScreen(appState: widget.appState),
      WorkerMyJobsScreen(appState: widget.appState),
      MessagesInboxScreen(appState: widget.appState),
      WorkerProfileScreen(appState: widget.appState),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0F0F4C3A),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.workerAccent,
          unselectedItemColor: AppColors.muted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: AppTypography.labelSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.workerAccent,
          ),
          unselectedLabelStyle: AppTypography.labelSm,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.handyman_outlined),
              activeIcon: Icon(Icons.handyman),
              label: 'Chambas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'Mis Trabajos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Mensajes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Mi Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

