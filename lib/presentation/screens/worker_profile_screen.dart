import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../state/app_state.dart';
import 'create_worker_profile_screen.dart';
import 'notifications_sheet.dart';
import 'settings_screen.dart';
import 'role_selection_screen.dart';
import 'welcome_screen.dart';
import 'worker_wallet_screen.dart';
import 'worker_portfolio_screen.dart';

class WorkerProfileScreen extends StatelessWidget {
  final AppState appState;

  const WorkerProfileScreen({super.key, required this.appState});

  void _showIdentityVerificationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final profile = appState.currentWorkerProfile;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33202D33),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.workerAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_outlined, color: AppColors.workerAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Verificación de Identidad',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: const Text(
                                  'DEMO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Estado del perfil técnico de Chiclayo',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1F173B4D)),
                  ),
                  child: Column(
                    children: [
                      _buildVerificationRow(
                        Icons.credit_card,
                        'DNI Registrado',
                        profile.dni.isNotEmpty ? profile.dni : '72384910',
                        isVerified: true,
                      ),
                      const Divider(height: 16, color: Color(0x1F202D33)),
                      _buildVerificationRow(
                        Icons.account_balance,
                        'Cotejo RENIEC',
                        'Demostración visual — En proceso de integración oficial',
                        isVerified: false,
                        isWarning: true,
                      ),
                      const Divider(height: 16, color: Color(0x1F202D33)),
                      _buildVerificationRow(
                        Icons.gavel_rounded,
                        'Antecedentes Policiales PNP',
                        'Declaración jurada de buena conducta registrada',
                        isVerified: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationRow(IconData icon, String title, String subtitle, {required bool isVerified, bool isWarning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isWarning
              ? const Color(0xFFD97706)
              : (isVerified ? AppColors.workerAccent : AppColors.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodyLgMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.labelSm.copyWith(
                  color: isWarning ? const Color(0xFFB45309) : AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(
          isWarning ? Icons.info_outline : (isVerified ? Icons.check_circle : Icons.pending_outlined),
          size: 18,
          color: isWarning ? const Color(0xFFD97706) : (isVerified ? AppColors.workerAccent : AppColors.muted),
        ),
      ],
    );
  }

  void _showHelpSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0x33202D33),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: AppColors.secondary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ayuda y Soporte CHAMBA',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Asistencia técnica para especialistas en Chiclayo',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
                  title: const Text('WhatsApp Soporte Directo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('+51 974 812 345 • Chiclayo Centro', style: TextStyle(fontSize: 11.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F202D33)),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📱 Canal de soporte WhatsApp (Lunes a Sábado 8:00 AM - 8:00 PM).'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                  title: const Text('Correo de Soporte Técnico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('soporte@chamba.pe', style: TextStyle(fontSize: 11.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F202D33)),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✉️ Correo de soporte copiado.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = appState.currentWorkerProfile;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mi Perfil de Chambeador',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            tooltip: 'Configuración',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(appState: appState),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Worker Identity Card (Authenticated user details preserved)
            ChambaCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          profile.avatarInitials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    profile.name,
                                    style: AppTypography.headlineSm.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.neutral,
                                      fontSize: 17,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (profile.isVerified)
                                  const Icon(Icons.verified, size: 18, color: AppColors.tertiary),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              profile.district.isNotEmpty ? profile.district : 'Chiclayo',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 15, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile.rating}',
                                  style: AppTypography.labelSm.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.neutral,
                                  ),
                                ),
                                Text(
                                  ' (${profile.completedJobs} chambas)',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TrustShieldBadgesRow(
                    isIdVerified: profile.isIdVerified,
                    hasCleanRecord: profile.hasCleanRecord,
                    offersWarranty: profile.offersWarranty,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0x14202D33)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tarifa base orientativa',
                        style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                      ),
                      Text(
                        'S/. ${profile.baseRate.toStringAsFixed(0)} / servicio',
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Switch to Client Mode Banner
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                appState.switchRole(UserRole.client);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.secondary, Color(0xFFC75B2E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1FB84A1C),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cambiar a Modo Cliente',
                            style: AppTypography.labelLg.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Publica una necesidad para tu hogar',
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.swap_horiz, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Clean, Navigable Options List as requested in instruction #4
            _buildOptionTile(
              context,
              icon: Icons.photo_library_outlined,
              title: 'Mi Portafolio',
              subtitle: 'Galería de proyectos con Antes y Después',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorkerPortfolioScreen(appState: appState)),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Mi Billetera y Ganancias',
              subtitle: 'Saldos, transferencias e historial de ingresos',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WorkerWalletScreen(appState: appState)),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.handyman_outlined,
              title: 'Mis Servicios y Especialidades',
              subtitle: 'Categorías de trabajo, experiencia y tarifas',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateWorkerProfileScreen(appState: appState),
                  ),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Verificación de Identidad',
              subtitle: 'Validación de DNI y antecedentes en Chiclayo',
              onTap: () => _showIdentityVerificationModal(context),
            ),
            _buildOptionTile(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              subtitle: 'Avisos de chambas y contraofertas',
              badgeCount: appState.unreadNotificationsCount,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => NotificationsSheet(appState: appState),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.settings_outlined,
              title: 'Configuración',
              subtitle: 'Privacidad, cuenta y preferencias',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SettingsScreen(appState: appState)),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.help_outline_rounded,
              title: 'Ayuda y Soporte',
              subtitle: 'Contacto WhatsApp y preguntas frecuentes',
              onTap: () => _showHelpSupportModal(context),
            ),
            _buildOptionTile(
              context,
              icon: Icons.swap_horiz,
              title: 'Elegir Modo de Uso',
              subtitle: 'Alternar entre Modo Cliente y Modo Trabajador',
              textColor: AppColors.workerPrimary,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RoleSelectionScreen(appState: appState)),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.logout,
              title: 'Cerrar Sesión',
              subtitle: 'Salir de la cuenta de manera segura',
              textColor: AppColors.error,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Cerrar sesión?'),
                    content: const Text('Tendrás que volver a ingresar tus credenciales para acceder a CHAMBA.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await appState.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => WelcomeScreen(appState: appState)),
                      (route) => false,
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ChambaCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: textColor ?? AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLgMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor ?? AppColors.neutral,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
