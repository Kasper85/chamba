import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../core/widgets/before_after_slider.dart';
import '../../data/models/worker_profile.dart';

class WorkerProfileDetailScreen extends StatelessWidget {
  final WorkerProfile worker;

  const WorkerProfileDetailScreen({
    super.key,
    required this.worker,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Perfil del Especialista'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero card
              ChambaCard(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            worker.avatarInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (worker.isVerified)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.tertiary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 16, color: Colors.white),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            worker.name,
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.neutral,
                            ),
                          ),
                        ),
                        if (!worker.isRealBackendWorker) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DEMO',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.distanceKm != null
                          ? '${worker.district} • ${worker.distanceKm!.toStringAsFixed(1)} km de ti'
                          : worker.district,
                      style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    if (!worker.isRealBackendWorker) ...[
                      const SizedBox(height: 10),
                      TrustShieldBadgesRow(
                        isIdVerified: worker.isIdVerified,
                        hasCleanRecord: worker.hasCleanRecord,
                        offersWarranty: worker.offersWarranty,
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Divider(height: 1, color: Color(0x14202D33)),
                    const SizedBox(height: 18),
                    // Stats metrics row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Calificación', '${worker.rating} ⭐'),
                        _buildStat('Chambas', '${worker.completedJobs}'),
                        if (!worker.isRealBackendWorker && worker.experienceYears > 0)
                          _buildStat('Experiencia', '${worker.experienceYears} años')
                        else if (worker.isRealBackendWorker && worker.distanceKm != null)
                          _buildStat('Distancia', '${worker.distanceKm!.toStringAsFixed(1)} km')
                        else
                          _buildStat('Estado', 'Disponible'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Bio
              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acerca del Especialista',
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      worker.bio,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.neutral,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Oficios y Especialidades',
                      style: AppTypography.labelLg.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: worker.skills.map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x1F173B4D)),
                          ),
                          child: Text(
                            skill,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Coverage & Rates
              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tarifa Referencial y Cobertura',
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_outlined, size: 20, color: AppColors.secondary),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              worker.isRealBackendWorker || worker.baseRate == 0.0
                                  ? 'Tarifa a convenir'
                                  : 'S/. ${worker.baseRate.toStringAsFixed(0)} / visita o base',
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral,
                              ),
                            ),
                            Text(
                              worker.isRealBackendWorker
                                  ? 'A convenir según magnitud del trabajo mediante ofertas'
                                  : 'Negociable según magnitud del trabajo',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.radar_outlined, size: 20, color: AppColors.tertiary),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Radio de cobertura: ${worker.serviceRadiusKm} km',
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral,
                              ),
                            ),
                            Text(
                              'Chiclayo, La Victoria, José Leonardo Ortiz, Pimentel',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Before & After Interactive Portfolio Gallery
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Casos Resueltos (Antes y Después)',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Desliza la barra ◀ ▶ para comparar la avería vs. el resultado',
                          style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.compare_arrows_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${worker.portfolioCases.length} obras',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (worker.portfolioCases.isEmpty)
                ChambaCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_outlined, size: 40, color: AppColors.muted),
                          const SizedBox(height: 8),
                          Text(
                            'Este especialista aún no ha subido casos comparativos antes/después.',
                            style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...worker.portfolioCases.map((caseItem) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18.0),
                    child: ChambaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  caseItem.title,
                                  style: AppTypography.bodyLgMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  caseItem.category,
                                  style: AppTypography.labelSm.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(
                                '${caseItem.timeSpent} • Presupuesto aprox: S/. ${caseItem.cost.toStringAsFixed(0)}',
                                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BeforeAfterSlider(caseData: caseItem),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 16),

              // Reviews
              Text(
                'Reseñas de Clientes (${worker.reviews.length})',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),

              if (worker.reviews.isEmpty) ...[
                ChambaCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Aún sin reseñas',
                        style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ...worker.reviews.map((rev) => _buildReviewCard(rev)),
              ],

              const SizedBox(height: 24),

              ChambaButton(
                label: 'Cerrar y Regresar',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
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
    );
  }

  Widget _buildReviewCard(WorkerReview rev) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ChambaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rev.clientName,
                  style: AppTypography.bodyLgMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutral,
                  ),
                ),
                Text(
                  rev.date,
                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  Icons.star,
                  size: 14,
                  color: i < rev.rating.round() ? Colors.amber : Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              rev.comment,
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
