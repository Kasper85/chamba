import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import 'dispute_detail_screen.dart';
import 'rating_receipt_screen.dart';

/// Pantalla obligatoria de confirmación de servicio (ALCANCE.md §3, §7, §8 L5)
/// Incluye slider interactivo Antes vs Después, cuenta regresiva de 24 horas
/// y botones para liberar el pago o reportar un problema.
class JobConfirmationScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const JobConfirmationScreen({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<JobConfirmationScreen> createState() => _JobConfirmationScreenState();
}

class _JobConfirmationScreenState extends State<JobConfirmationScreen> {
  late JobRequest _job;
  double _sliderPosition = 0.5; // 0.0 (todo antes) a 1.0 (todo después)
  Timer? _countdownTimer;
  late Duration _remainingTime;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _job = widget.job;

    // Calcular tiempo restante de la ventana de 24 horas
    final startedAt = _job.createdAt;
    final expiresAt = startedAt.add(const Duration(hours: 24));
    final diff = expiresAt.difference(DateTime.now());
    _remainingTime = diff.isNegative ? Duration.zero : diff;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          } else {
            _remainingTime = Duration.zero;
            timer.cancel();
          }
        });
      }
    });

    widget.appState.addListener(_onStateUpdate);
  }

  void _onStateUpdate() {
    if (!mounted) return;
    final updated = widget.appState.jobs.firstWhere(
      (j) => j.id == _job.id,
      orElse: () => _job,
    );
    setState(() => _job = updated);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    widget.appState.removeListener(_onStateUpdate);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleReleasePayment() async {
    setState(() => _isProcessing = true);
    final success = await widget.appState.advanceJobPhase(
      jobId: _job.id,
      nextPhase: JobStatus.completed,
    );
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pago liberado exitosamente! Gracias por confirmar la labor.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => RatingReceiptScreen(
            appState: widget.appState,
            job: _job.copyWith(status: JobStatus.completed),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo liberar el pago. Intenta nuevamente.'),
          backgroundColor: AppColors.sosRed,
        ),
      );
    }
  }

  Future<void> _handleReportProblem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reportar un problema?'),
        content: const Text(
          'Al abrir un reporte o reclamo, los fondos retenidos en custodia quedarán congelados '
          'y soporte revisará las evidencias del servicio con ambas partes en un plazo de 24 a 48 horas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abrir Disputa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      final success = await widget.appState.advanceJobPhase(
        jobId: _job.id,
        nextPhase: JobStatus.inDispute,
      );
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disputa iniciada. Los fondos han sido congelados para mediación de soporte.'),
            backgroundColor: Color(0xFFD97706),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (ctx) => DisputeDetailScreen(
              appState: widget.appState,
              job: _job.copyWith(status: JobStatus.inDispute),
              initialReason: 'Disconformidad con el acabado del servicio reportada desde la confirmación.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workerName = _job.bids.isNotEmpty ? _job.bids.first.workerName : 'Técnico asignado';
    final workerAvatar = _job.bids.isNotEmpty ? _job.bids.first.workerAvatar : 'TC';

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
          'Confirma tu servicio',
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
            // Banner de cuenta regresiva de 24 horas
            _buildCountdownBanner(),
            const SizedBox(height: 18),

            // Tarjeta del servicio y técnico
            _buildJobSummaryCard(workerName, workerAvatar),
            const SizedBox(height: 20),

            // Slider Antes vs Después
            _buildBeforeAfterComparison(),
            const SizedBox(height: 24),

            // Desglose del pago en custodia
            _buildEscrowDetailCard(),
            const SizedBox(height: 28),

            // Botones de acción
            ChambaButton(
              label: 'Todo bien, liberar pago',
              leadingIcon: Icons.check_circle_outline,
              isLoading: _isProcessing,
              onPressed: _handleReleasePayment,
            ),
            const SizedBox(height: 12),
            ChambaButton(
              label: 'Reportar un problema',
              leadingIcon: Icons.report_problem_outlined,
              variant: ChambaButtonVariant.secondary,
              onPressed: _isProcessing ? null : _handleReportProblem,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Pasadas las 24 horas sin respuesta, el pago se liberará automáticamente.',
                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.timer_outlined, color: Color(0xFFB45309), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Plazo de confirmación: ',
                      style: AppTypography.labelSm.copyWith(
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatDuration(_remainingTime),
                      style: AppTypography.headlineSm.copyWith(
                        color: const Color(0xFFB45309),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Revisa el trabajo realizado antes de que finalice la ventana de 24 horas.',
                  style: AppTypography.labelSm.copyWith(
                    color: const Color(0xFFB45309),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSummaryCard(String workerName, String workerAvatar) {
    return ChambaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: Text(
                  workerAvatar,
                  style: AppTypography.bodyMdMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workerName,
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.neutral,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Especialista verificado en Chiclayo',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ChambaBadge(
                label: 'Por Confirmar',
                type: ChambaBadgeType.neutral,
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            _job.title,
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _job.district,
            style: AppTypography.bodyMd.copyWith(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfterComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Evidencia Antes vs Después',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.neutral,
              ),
            ),
            Text(
              'Desliza para comparar',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Comparador interactivo con divisor deslizable
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const height = 220.0;

            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _sliderPosition = (_sliderPosition + details.primaryDelta! / width).clamp(0.0, 1.0);
                  });
                },
                child: SizedBox(
                  height: height,
                  width: width,
                  child: Stack(
                    children: [
                      // Fondo: Foto DESPUÉS
                      Positioned.fill(
                        child: Container(
                          color: const Color(0xFFE8F5E9),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 48, color: AppColors.tertiary),
                              const SizedBox(height: 8),
                              Text(
                                'FOTO DESPUÉS',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: AppColors.tertiary,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Text(
                                  _job.afterPhotoTag ?? 'Trabajo concluido según especificaciones',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.neutral),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Capa recortada: Foto ANTES
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: width * _sliderPosition,
                        child: ClipRect(
                          child: Container(
                            width: width,
                            color: const Color(0xFFFFEBEE),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history_outlined, size: 48, color: AppColors.sosRed),
                                const SizedBox(height: 8),
                                Text(
                                  'FOTO ANTES',
                                  style: AppTypography.headlineSm.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppColors.sosRed,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Text(
                                    _job.beforePhotoTag ?? 'Estado inicial del problema',
                                    style: AppTypography.labelSm.copyWith(color: AppColors.neutral),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Línea divisoria deslizable
                      Positioned(
                        left: width * _sliderPosition - 18,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(color: AppColors.primary, width: 2),
                            ),
                            child: const Icon(Icons.compare_arrows, size: 20, color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('🔴 Estado Inicial (Antes)', style: AppTypography.labelSm.copyWith(color: AppColors.sosRed, fontWeight: FontWeight.w700)),
            Text('🟢 Resultado (Después)', style: AppTypography.labelSm.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _buildEscrowDetailCard() {
    final agreedPrice = _job.budget;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F202D33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 20, color: AppColors.tertiary),
              const SizedBox(width: 8),
              Text(
                'Monto protegido en custodia',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monto a liberar al técnico:', style: AppTypography.bodyMd.copyWith(color: AppColors.muted)),
              Text(
                'S/ ${agreedPrice.toStringAsFixed(2)}',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Al confirmar, el monto se transferirá directamente a la billetera del técnico.',
            style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
