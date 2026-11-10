import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'chamba_button.dart';

class PriceDialStepper extends StatelessWidget {
  final double currentPrice;
  final ValueChanged<double> onPriceChanged;
  final double step;
  final double minPrice;
  final double maxPrice;
  final String label;
  final List<double> quickIncrements;
  final bool isSosSurge;
  final String? surgeLabel;
  final double recommendedPrice;

  const PriceDialStepper({
    super.key,
    required this.currentPrice,
    required this.onPriceChanged,
    this.step = 5.0,
    this.minPrice = 20.0,
    this.maxPrice = 2000.0,
    this.label = 'Tu Oferta Propuesta',
    this.quickIncrements = const [-5.0, 5.0, 10.0, 20.0],
    this.isSosSurge = false,
    this.surgeLabel,
    this.recommendedPrice = 50.0,
  });

  void _adjust(double delta) {
    final next = (currentPrice + delta).clamp(minPrice, maxPrice);
    onPriceChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = currentPrice / (recommendedPrice > 0 ? recommendedPrice : 50.0);

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;
    String statusBadge;
    int activeDots;

    if (ratio < 0.85) {
      statusColor = const Color(0xFFE05638);
      statusIcon = Icons.speed_rounded;
      statusTitle = 'Baja probabilidad • Pocos técnicos aceptarán';
      statusSubtitle = 'Sube S/. ${(recommendedPrice * 0.85 - currentPrice).clamp(5, 50).toStringAsFixed(0)} para atraer más especialistas.';
      statusBadge = 'PRECIO BAJO';
      activeDots = 1;
    } else if (ratio <= 1.25) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.verified_rounded;
      statusTitle = 'Precio Justo en tu zona • Alta probabilidad';
      statusSubtitle = 'Tarifa óptima según diagnósticos en Chiclayo (S/. ${recommendedPrice.toStringAsFixed(0)} sugerido).';
      statusBadge = 'PRECIO JUSTO IA';
      activeDots = 2;
    } else {
      statusColor = const Color(0xFF2563EB); // Azul/Dorado prioritario
      statusIcon = Icons.bolt_rounded;
      statusTitle = 'Oferta Destacada • Respuesta inmediata';
      statusSubtitle = 'Aparecerás con máxima visibilidad en el radar de técnicos cercanos.';
      statusBadge = 'OFERTA DESTACADA';
      activeDots = 3;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSosSurge ? AppColors.sosRed : const Color(0x1F202D33),
          width: isSosSurge ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSosSurge ? AppColors.sosGlow : const Color(0x0A173B4D),
            blurRadius: isSosSurge ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isSosSurge) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.sosRedLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, size: 16, color: AppColors.sosRed),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      surgeLabel ?? 'Tarifa Dinámica de Emergencia (+35%)',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.sosRed,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: isSosSurge ? AppColors.sosRedDark : AppColors.muted,
              fontWeight: isSosSurge ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCircularStepButton(
                icon: Icons.remove,
                enabled: currentPrice > minPrice,
                onTap: () => _adjust(-step),
              ),
              const SizedBox(width: 20),
              // Prominent numeric bid display
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'S/. ',
                    style: AppTypography.headlineLg.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    currentPrice.toStringAsFixed(0),
                    style: AppTypography.numericBidLarge.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              _buildCircularStepButton(
                icon: Icons.add,
                enabled: currentPrice < maxPrice,
                onTap: () => _adjust(step),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick pills: -S/.5, +S/.5, +S/.10, +S/.20
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: quickIncrements.map((increment) {
                final isNegative = increment < 0;
                final sign = isNegative ? '' : '+';
                final labelText = '${sign}S/.${increment.abs().toStringAsFixed(0)}';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChambaButton.pill(
                    label: labelText,
                    onPressed: () => _adjust(increment),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // SEMÁFORO DE PROBABILIDAD DE ACEPTACIÓN
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.28), width: 1.2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 280;
                final badgeWidget = Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCompact) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(3, (i) {
                                  final isDotActive = i < activeDots;
                                  final dotColor = isDotActive
                                      ? (activeDots == 1
                                          ? const Color(0xFFE05638)
                                          : activeDots == 2
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF2563EB))
                                      : const Color(0x33202D33);
                                  return Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    width: 9,
                                    height: 9,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: dotColor,
                                      boxShadow: isDotActive
                                          ? [
                                              BoxShadow(
                                                color: dotColor.withValues(alpha: 0.45),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Icon(statusIcon, size: 16, color: statusColor),
                            ],
                          ),
                          badgeWidget,
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusTitle,
                        style: AppTypography.labelSm.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Row(
                            children: List.generate(3, (i) {
                              final isDotActive = i < activeDots;
                              final dotColor = isDotActive
                                  ? (activeDots == 1
                                      ? const Color(0xFFE05638)
                                      : activeDots == 2
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF2563EB))
                                  : const Color(0x33202D33);
                              return Container(
                                margin: const EdgeInsets.only(right: 5),
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dotColor,
                                  boxShadow: isDotActive
                                      ? [
                                          BoxShadow(
                                            color: dotColor.withValues(alpha: 0.45),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              statusTitle,
                              style: AppTypography.labelSm.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          badgeWidget,
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        statusSubtitle,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (ratio < 0.5 || ratio > 3.0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ratio < 0.5
                          ? 'Alerta de IA: El precio es menor al 50% del estimado (S/ ${recommendedPrice.toStringAsFixed(0)}). Podrías recibir menos ofertas.'
                          : 'Alerta de IA: El precio supera el 300% del estimado (S/ ${recommendedPrice.toStringAsFixed(0)}).',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularStepButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: enabled ? AppColors.surfaceContainer : AppColors.surfaceContainerLow,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: enabled ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
