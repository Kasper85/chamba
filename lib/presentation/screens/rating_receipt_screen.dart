import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';

/// Pantalla de Calificación mutua, propina opcional y Recibo Formal (ALCANCE.md §6, §7, §8 L8)
class RatingReceiptScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const RatingReceiptScreen({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<RatingReceiptScreen> createState() => _RatingReceiptScreenState();
}

class _RatingReceiptScreenState extends State<RatingReceiptScreen> {
  int _stars = 5;
  double _tipAmount = 0.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitRating() async {
    setState(() => _isSubmitting = true);

    await widget.appState.submitRating(
      jobId: widget.job.id,
      stars: _stars,
      comment: _commentController.text.trim(),
      tipAmount: _tipAmount,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Gracias por tu calificación! Tu recibo ha sido guardado.'),
        backgroundColor: AppColors.secondary,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.appState.currentRole == UserRole.client;
    final otherPartyName = isClient ? (widget.job.workerName ?? 'Técnico Especialista') : widget.job.clientName;
    final agreedPrice = widget.job.budget;
    final commission = NumberUtilities.round2(agreedPrice * 0.08);
    const serviceFee = 2.0;
    final totalClient = NumberUtilities.round2(agreedPrice + serviceFee + _tipAmount);
    final totalWorker = NumberUtilities.round2(agreedPrice - commission + _tipAmount);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Calificación y Recibo',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Calificación con Estrellas
            _buildRatingCard(otherPartyName, isClient),
            const SizedBox(height: 18),

            // Propina opcional (solo cliente)
            if (isClient) ...[
              _buildTipSelector(),
              const SizedBox(height: 18),
            ],

            // Recibo Formal de Servicio
            _buildReceiptCard(
              agreedPrice: agreedPrice,
              commission: commission,
              serviceFee: serviceFee,
              totalClient: totalClient,
              totalWorker: totalWorker,
              isClient: isClient,
            ),
            const SizedBox(height: 24),

            // Botón Enviar
            ChambaButton(
              label: 'Enviar Calificación y Cerrar',
              leadingIcon: Icons.star_rounded,
              isLoading: _isSubmitting,
              onPressed: _handleSubmitRating,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard(String otherPartyName, bool isClient) {
    return ChambaCard(
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: isClient ? AppColors.workerAccent : AppColors.primary,
            child: Icon(
              isClient ? Icons.handyman_rounded : Icons.person_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '¿Cómo fue tu experiencia con $otherPartyName?',
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.neutral,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Selector de 5 estrellas interactivo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isFilled = starIndex <= _stars;
              return IconButton(
                onPressed: () => setState(() => _stars = starIndex),
                icon: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 38,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Campo de comentario
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Escribe tu opinión sobre el trabajo realizado (opcional)...',
              hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.muted, fontSize: 13),
              filled: true,
              fillColor: AppColors.canvas,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1F202D33)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0x1F202D33)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipSelector() {
    final tipOptions = [0.0, 5.0, 10.0, 15.0];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.volunteer_activism, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Propina voluntaria para el técnico',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El 100% de la propina va directamente al técnico sin descuento de comisión (§6).',
            style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: tipOptions.map((tip) {
              final isSelected = _tipAmount == tip;
              return ChoiceChip(
                label: Text(tip == 0.0 ? 'Sin propina' : 'S/ ${tip.toStringAsFixed(0)}'),
                selected: isSelected,
                selectedColor: AppColors.secondary,
                labelStyle: AppTypography.labelSm.copyWith(
                  color: isSelected ? Colors.white : AppColors.neutral,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _tipAmount = tip);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard({
    required double agreedPrice,
    required double commission,
    required double serviceFee,
    required double totalClient,
    required double totalWorker,
    required bool isClient,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F202D33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recibo de Servicio',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
              const ChambaBadge(
                label: 'Pagado',
                type: ChambaBadgeType.confirmed,
              ),
            ],
          ),
          const Divider(height: 20),
          _buildReceiptRow('Servicio:', widget.job.title),
          _buildReceiptRow('Categoría:', widget.job.categoryName),
          _buildReceiptRow('Distrito:', widget.job.district),
          _buildReceiptRow('Precio acordado (P):', 'S/ ${agreedPrice.toStringAsFixed(2)}'),
          _buildReceiptRow('Tarifa de servicio (plataforma):', 'S/ ${serviceFee.toStringAsFixed(2)}'),
          _buildReceiptRow('Comisión del 8% (deducida al técnico):', '- S/ ${commission.toStringAsFixed(2)}'),
          if (_tipAmount > 0)
            _buildReceiptRow('Propina opcional (100% técnico):', '+ S/ ${_tipAmount.toStringAsFixed(2)}'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isClient ? 'Total abonado por cliente:' : 'Total neto recibido por técnico:',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.neutral,
                ),
              ),
              Text(
                'S/ ${(isClient ? totalClient : totalWorker).toStringAsFixed(2)}',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Evidencia fotográfica en el recibo
          Row(
            children: [
              if (widget.job.beforePhotoTag != null)
                Expanded(
                  child: _buildPhotoThumb('Antes', widget.job.beforePhotoTag!),
                ),
              if (widget.job.beforePhotoTag != null && widget.job.afterPhotoTag != null)
                const SizedBox(width: 8),
              if (widget.job.afterPhotoTag != null)
                Expanded(
                  child: _buildPhotoThumb('Después', widget.job.afterPhotoTag!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd.copyWith(color: AppColors.muted, fontSize: 12.5)),
          Text(value, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildPhotoThumb(String title, String tag) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            tag,
            style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class NumberUtilities {
  static double round2(double value) => double.parse(value.toStringAsFixed(2));
}

