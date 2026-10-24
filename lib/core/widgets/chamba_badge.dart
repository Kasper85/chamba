import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum ChambaBadgeType {
  negotiating,
  confirmed,
  counterReceived,
  inProgress,
  verified,
  neutral,
  trustShield,
  sos,
}

class ChambaBadge extends StatelessWidget {
  final String label;
  final ChambaBadgeType type;
  final IconData? icon;
  final VoidCallback? onTap;

  const ChambaBadge({
    super.key,
    required this.label,
    this.type = ChambaBadgeType.neutral,
    this.icon,
    this.onTap,
  });

  const ChambaBadge.negotiating({
    super.key,
    this.label = 'Negociando',
    this.icon,
    this.onTap,
  }) : type = ChambaBadgeType.negotiating;

  const ChambaBadge.confirmed({
    super.key,
    this.label = 'Confirmado',
    this.icon = Icons.check_circle_outline,
    this.onTap,
  }) : type = ChambaBadgeType.confirmed;

  const ChambaBadge.counterReceived({
    super.key,
    this.label = 'Contraoferta Recibida',
    this.icon = Icons.sync_alt,
    this.onTap,
  }) : type = ChambaBadgeType.counterReceived;

  const ChambaBadge.verified({
    super.key,
    this.label = 'Verificado',
    this.icon = Icons.verified,
    this.onTap,
  }) : type = ChambaBadgeType.verified;

  const ChambaBadge.trustShield({
    super.key,
    this.label = 'Escudo de Confianza',
    this.icon = Icons.shield_rounded,
    this.onTap,
  }) : type = ChambaBadgeType.trustShield;

  const ChambaBadge.sos({
    super.key,
    this.label = 'URGENTE • LLEGADA < 30 MIN',
    this.icon = Icons.emergency_rounded,
    this.onTap,
  }) : type = ChambaBadgeType.sos;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case ChambaBadgeType.negotiating:
        bg = AppColors.badgeNegotiatingBg;
        fg = AppColors.badgeNegotiatingText;
        break;
      case ChambaBadgeType.confirmed:
        bg = AppColors.badgeConfirmedBg;
        fg = AppColors.badgeConfirmedText;
        break;
      case ChambaBadgeType.counterReceived:
        bg = AppColors.badgeCounterBg;
        fg = AppColors.badgeCounterText;
        break;
      case ChambaBadgeType.inProgress:
        bg = const Color(0x1F284B5D);
        fg = AppColors.primary;
        break;
      case ChambaBadgeType.verified:
        bg = AppColors.badgeConfirmedBg;
        fg = AppColors.tertiary;
        break;
      case ChambaBadgeType.neutral:
        bg = const Color(0x14667085);
        fg = AppColors.muted;
        break;
      case ChambaBadgeType.trustShield:
        bg = const Color(0x1F0F4C3A);
        fg = AppColors.workerPrimary;
        break;
      case ChambaBadgeType.sos:
        bg = AppColors.sosRedLight;
        fg = AppColors.sosRed;
        break;
    }

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
        border: type == ChambaBadgeType.sos
            ? Border.all(color: AppColors.sosRed.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSm.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        child: badge,
      );
    }
    return badge;
  }
}

/// Interactive Trust Shield Row displaying RENIEC, Police records, and Warranty badges
class TrustShieldBadgesRow extends StatelessWidget {
  final bool isIdVerified;
  final bool hasCleanRecord;
  final bool offersWarranty;

  const TrustShieldBadgesRow({
    super.key,
    this.isIdVerified = true,
    this.hasCleanRecord = true,
    this.offersWarranty = true,
  });

  static void showTrustModal(BuildContext context) {
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
                        color: AppColors.workerSurfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded, color: AppColors.workerPrimary, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escudo de Confianza Chamba',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Seguridad estricta para tu hogar en Chiclayo',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTrustItem(
                  icon: Icons.badge_outlined,
                  color: AppColors.shieldReniec,
                  title: 'DNI Verificado con RENIEC',
                  description:
                      'Validación biométrica e identidad oficial cotejada en tiempo real. Sabemos con certeza quién entra a tu domicilio.',
                ),
                const SizedBox(height: 14),
                _buildTrustItem(
                  icon: Icons.gavel_rounded,
                  color: AppColors.shieldPolice,
                  title: 'Antecedentes Policiales Limpios',
                  description:
                      'Certificado de antecedentes policiales y judiciales vigente ante la PNP sin requisitorias ni denuncias registradas.',
                ),
                const SizedBox(height: 14),
                _buildTrustItem(
                  icon: Icons.verified_user_rounded,
                  color: AppColors.shieldWarranty,
                  title: 'Garantía Escrita de 7 Días Chamba',
                  description:
                      'Si la reparación presenta fallas durante los primeros 7 días, el especialista retorna sin costo o Chamba reembolsa tus fondos retenidos en Escrow.',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Entendido, me da seguridad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildTrustItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLgMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isIdVerified && !hasCleanRecord && !offersWarranty) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () => showTrustModal(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.workerSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.workerAccent.withValues(alpha: 0.3)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_rounded, size: 16, color: AppColors.workerAccent),
              const SizedBox(width: 6),
              Text(
                'Escudo de Confianza:',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.workerPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (isIdVerified) ...[
                _buildMiniBadge(Icons.badge_outlined, 'RENIEC', AppColors.shieldReniec),
                const SizedBox(width: 4),
              ],
              if (hasCleanRecord) ...[
                _buildMiniBadge(Icons.gavel_rounded, 'Sin Antecedentes', AppColors.shieldPolice),
                const SizedBox(width: 4),
              ],
              if (offersWarranty) ...[
                _buildMiniBadge(Icons.verified_rounded, 'Garantía 7d', AppColors.shieldWarranty),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 13, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

