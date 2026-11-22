import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../state/app_state.dart';
import 'role_selection_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final AppState? appState;

  const WelcomeScreen({super.key, this.appState});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final AppState _appState;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _appState = widget.appState ?? AppState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    await _appState.restoreSession();
    if (mounted) {
      setState(() => _isCheckingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Brand logo & Peruvian identity badge
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/chamba.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'CHAMBA',
                    style: AppTypography.headlineXl.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PERÚ 🇵🇪',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Hero card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0x14202D33),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F173B4D),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceContainerHighest, width: 2),
                      ),
                      child: const Icon(
                        Icons.home_repair_service_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Servicios del hogar con negociación justa y directa',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMd.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tú propones el presupuesto en Soles o recibes contraofertas en tiempo real con técnicos verificados de tu distrito.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0x14202D33)),
                    const SizedBox(height: 18),
                    // Trust pills
                    _buildTrustRow(
                      Icons.verified_user_outlined,
                      '100% Técnicos verificados con DNI y antecedentes',
                    ),
                    const SizedBox(height: 12),
                    _buildTrustRow(
                      Icons.price_check_outlined,
                      'Precios transparentes en S/. sin comisiones abusivas',
                    ),
                    const SizedBox(height: 12),
                    _buildTrustRow(
                      Icons.flash_on_outlined,
                      'Respuestas y contraofertas en menos de 5 minutos',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Active session pill if user already logged in
              if (!_isCheckingSession && _appState.isAuthenticated) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.tertiary,
                        child: Text(
                          _appState.userInitials,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sesión activa',
                              style: AppTypography.labelSm.copyWith(color: AppColors.tertiary),
                            ),
                            Text(
                              _appState.clientName,
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.neutral,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.logout, color: AppColors.muted, size: 20),
                        onPressed: () async {
                          await _appState.logout();
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ChambaButton(
                  label: 'Continuar como ${_appState.clientName.split(" ").first}',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoleSelectionScreen(appState: _appState),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ] else ...[
                // Auth entry buttons
                ChambaButton(
                  label: 'Iniciar Sesión',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(appState: _appState),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(appState: _appState),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Crear Cuenta Nueva',
                    style: AppTypography.bodyLgMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoleSelectionScreen(appState: _appState),
                      ),
                    );
                  },
                  child: Text(
                    'Explorar modo demostración',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.muted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Al continuar aceptas las condiciones de servicio de CHAMBA Perú.',
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMdMedium.copyWith(
              fontSize: 13,
              color: AppColors.neutral,
            ),
          ),
        ),
      ],
    );
  }
}
