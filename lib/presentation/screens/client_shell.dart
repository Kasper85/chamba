import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../state/app_state.dart';
import 'client_home_screen.dart';
import 'client_my_requests_screen.dart';
import 'messages_inbox_screen.dart';
import 'user_profile_screen.dart';

class ClientShell extends StatefulWidget {
  final AppState appState;
  final int initialIndex;

  const ClientShell({
    super.key,
    required this.appState,
    this.initialIndex = 0,
  });

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ClientHomeScreen(appState: widget.appState),
      ClientMyRequestsScreen(appState: widget.appState),
      MessagesInboxScreen(appState: widget.appState),
      UserProfileScreen(appState: widget.appState),
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
              color: Color(0x0F173B4D),
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
          selectedItemColor: AppColors.secondary,
          unselectedItemColor: AppColors.muted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTypography.labelSm,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Solicitudes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Mensajes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

