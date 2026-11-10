import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_card.dart';
import '../state/app_state.dart';
import 'notifications_sheet.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final AppState appState;

  const UserProfileScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mi Perfil',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
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
            // User Header Card
            ChambaCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      appState.userInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                appState.clientName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 18,
                              color: AppColors.tertiary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appState.clientDistrict,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appState.clientPhone,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metrics Summary
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    '${appState.clientJobsCount}',
                    'Publicadas',
                    Icons.post_add,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    '${appState.clientCompletedJobsCount}',
                    'Completadas',
                    Icons.task_alt,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    '${appState.clientAverageRating.toStringAsFixed(1)} ★',
                    'Calificación',
                    Icons.star,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mode Switcher Banner
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                appState.switchRole(UserRole.worker);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF284B5D)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F173B4D),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cambiar a Modo Chambeador',
                            style: AppTypography.labelLg.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gana dinero ofreciendo tus servicios',
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
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
            const SizedBox(height: 20),

            // Options List
            _buildOptionTile(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              subtitle: 'Avisos de ofertas y estado de servicios',
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
              icon: Icons.location_on_outlined,
              title: 'Direcciones Frecuentes',
              subtitle: appState.clientAddress,
              onTap: () => _showAddressesModal(context),
            ),
            _buildOptionTile(
              context,
              icon: Icons.payment_outlined,
              title: 'Métodos de Pago Preferidos',
              subtitle: 'Efectivo, Yape y Plin directo (Simulado)',
              onTap: () => _showPaymentMethodsModal(context),
            ),
            _buildOptionTile(
              context,
              icon: Icons.shield_outlined,
              title: 'Seguridad y Verificación DNI',
              subtitle: 'Validación en modo demostración (DEMO)',
              onTap: () => _showDniVerificationModal(context),
            ),
            _buildOptionTile(
              context,
              icon: Icons.help_outline,
              title: 'Soporte y Ayuda',
              subtitle: 'Atención directa por WhatsApp en Chiclayo',
              onTap: () => _showSupportModal(context),
            ),
            _buildOptionTile(
              context,
              icon: Icons.logout,
              title: 'Cerrar Sesión',
              subtitle: 'Salir de la cuenta de manera segura',
              textColor: AppColors.error,
              onTap: () async {
                await appState.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => WelcomeScreen(appState: appState),
                    ),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14202D33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
          ),
        ],
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
              child: Icon(
                icon,
                color: textColor ?? AppColors.primary,
                size: 20,
              ),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.muted,
                    ),
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

  void _showAddressesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                Text(
                  'Mis Direcciones Guardadas',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona o administra las direcciones para tus solicitudes en Chiclayo',
                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.home_outlined, color: AppColors.secondary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Casa (Principal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Por defecto', style: TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${appState.clientAddress}, ${appState.clientDistrict}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1F202D33)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.work_outline, color: AppColors.primary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Oficina / Local', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            SizedBox(height: 2),
                            Text('Av. Balta 780, Chiclayo Centro', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                  label: const Text('Agregar Nueva Dirección', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📍 Dirección registrada con éxito para Chiclayo.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  void _showPaymentMethodsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                Text(
                  'Métodos de Pago Preferidos',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Text(
                    '💡 Pagos 100% simulados con garantía Escrow para Chiclayo (§8 L9).',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.qr_code_2, color: Color(0xFF7209B7), size: 28),
                  title: const Text('Yape / Plin (Simulado)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Pago instantáneo y custodia en garantía', style: TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.check_circle, color: AppColors.secondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F202D33)),
                  ),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.credit_card, color: AppColors.primary, size: 26),
                  title: const Text('Tarjeta Débito/Crédito (Simulada)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Visa terminada en •••• 4242', style: TextStyle(fontSize: 11.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F202D33)),
                  ),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.payments_outlined, color: AppColors.secondary, size: 26),
                  title: const Text('Efectivo contra entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('Pago directo presencial en mano', style: TextStyle(fontSize: 11.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F202D33)),
                  ),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  void _showDniVerificationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                  const SizedBox(height: 6),
                  Text(
                    'Validación de identidad en modo demostración. La integración oficial con RENIEC se encuentra en proceso según ALCANCE.md §7 y §9.',
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x1F173B4D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: AppColors.primary, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DNI Registrado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text(
                                appState.currentWorkerProfile.dni.isNotEmpty
                                    ? appState.currentWorkerProfile.dni
                                    : '72384910',
                                style: const TextStyle(fontSize: 13, color: AppColors.neutral, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: AppColors.secondary, size: 22),
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
          ),
        );
      },
    );
  }

  void _showSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                Text(
                  'Soporte y Ayuda CHAMBA',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Atención directa al cliente para servicios del hogar en Chiclayo',
                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
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
                        content: Text('📱 Abriendo canal de soporte WhatsApp Chiclayo.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                  title: const Text('Correo de Atención al Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: const Text('soporte@chamba.pe', style: TextStyle(fontSize: 11.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F202D33)),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✉️ Correo de atención copiado al portapapeles.'),
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
        ),
      );
    },
  );
}
}
