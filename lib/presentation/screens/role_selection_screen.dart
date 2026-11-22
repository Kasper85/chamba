import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_badge.dart';
import '../state/app_state.dart';
import 'app_shell_gate.dart';

class RoleSelectionScreen extends StatefulWidget {
  final AppState? appState;

  const RoleSelectionScreen({super.key, this.appState});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _selectedRole = UserRole.client;

  @override
  Widget build(BuildContext context) {
    final isClient = _selectedRole == UserRole.client;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Modo de Uso'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32.0 > 0
                      ? constraints.maxHeight - 32.0
                      : 0,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '¿Cómo quieres usar CHAMBA hoy?',
                        style: AppTypography.headlineLg.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Elige tu rol principal. Podrás alternar entre cliente y especialista en cualquier momento desde tu barra de perfil.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Option 1: Cliente
                      _buildRoleCard(
                        role: UserRole.client,
                        title: 'Necesito un Servicio',
                        subtitle: 'Para tu hogar o negocio',
                        description: 'Publica lo que necesitas (gasfitería, luz, cerrajería, pintura), define tu presupuesto en S/. y recibe ofertas de técnicos cercanos.',
                        icon: Icons.roofing_rounded,
                        badgeLabel: 'Cliente',
                        badgeType: ChambaBadgeType.confirmed,
                        isSelected: isClient,
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.client),
                      ),

                      const SizedBox(height: 16),

                      // Option 2: Especialista
                      _buildRoleCard(
                        role: UserRole.worker,
                        title: 'Quiero Trabajar',
                        subtitle: 'Técnico o especialista independiente',
                        description: 'Revisa solicitudes publicadas cerca de ti, envía tus cotizaciones o contraofertas y gana dinero directamente.',
                        icon: Icons.construction_rounded,
                        badgeLabel: 'Especialista',
                        badgeType: ChambaBadgeType.counterReceived,
                        isSelected: !isClient,
                        onTap: () =>
                            setState(() => _selectedRole = UserRole.worker),
                      ),

                      const Spacer(),
                      const SizedBox(height: 16),

                      // Switch explanation banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.swap_horiz_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Un solo perfil: puedes publicar servicios y al mismo tiempo trabajar como técnico.',
                                style: AppTypography.bodyMdMedium.copyWith(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      ChambaButton(
                        label: isClient
                            ? 'Continuar como Cliente'
                            : 'Continuar como Especialista',
                        leadingIcon: isClient ? Icons.search : Icons.handyman,
                        onPressed: () {
                          final state = widget.appState ?? AppState();
                          state.switchRole(_selectedRole);
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => AppShellGate(appState: state),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required String badgeLabel,
    required ChambaBadgeType badgeType,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.secondary : const Color(0x1F202D33),
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0x1FB84A1C)
                  : const Color(0x0A173B4D),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceContainer
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: isSelected ? AppColors.secondary : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            title,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral,
                            ),
                          ),
                          ChambaBadge(label: badgeLabel, type: badgeType),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppColors.secondary : AppColors.muted,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.neutral,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
