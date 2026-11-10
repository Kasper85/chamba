import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import '../widgets/chamba_interactive_map.dart';
import 'chat_screen.dart';
import 'job_confirmation_screen.dart';
import 'rating_receipt_screen.dart';

/// Vista de seguimiento especializada para el CLIENTE (ALCANCE.md §8 L4)
/// Incluye mapa interactivo con posición del técnico, PIN de 4 dígitos destacado para dictar,
/// visualización de fotos antes/después en modo solo lectura, y botón de confirmación final.
/// Libre de controles del técnico ("Simular Técnico").
class ClientJobTrackingView extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const ClientJobTrackingView({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<ClientJobTrackingView> createState() => _ClientJobTrackingViewState();
}

class _ClientJobTrackingViewState extends State<ClientJobTrackingView> {
  late JobRequest _job;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    widget.appState.addListener(_onStateChange);
  }

  void _onStateChange() {
    if (mounted) {
      final updated = widget.appState.jobs.firstWhere(
        (j) => j.id == widget.job.id,
        orElse: () => _job,
      );
      setState(() => _job = updated);
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChange);
    super.dispose();
  }

  void _showCancellationDialog() {
    if (_job.status == JobStatus.inProgress ||
        _job.status == JobStatus.forConfirmation) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelación no disponible'),
          content: const Text(
            'El PIN de seguridad ya fue validado y el técnico está interviniendo o por confirmar. '
            'Cualquier inconveniente debe resolverse abriendo una Disputa con soporte (§5).',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final isEnCamino = _job.status == JobStatus.onTheWay;
    final agreedPrice = _job.budget;
    final compensation = (agreedPrice * 0.10).clamp(5.0, 20.0);
    final refundAmount = (agreedPrice + 2.0) - compensation;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar solicitud?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEnCamino) ...[
              Text(
                'El técnico ya se encuentra en camino. Si cancelas por decisión propia, se le transferirá una compensación de S/ ${compensation.toStringAsFixed(2)} por su desplazamiento y recibirás un reembolso de S/ ${refundAmount.toStringAsFixed(2)} (incluyendo la tarifa de servicio).',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 12),
              const Text(
                '¿O el técnico se ha demorado más de 30 minutos sin llegar?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ] else ...[
              Text(
                'El técnico aún no ha salido al domicilio. Si cancelas ahora, recibirás el reembolso total de S/ ${(agreedPrice + 2.0).toStringAsFixed(2)}.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Volver'),
          ),
          if (isEnCamino) ...[
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await widget.appState.cancelJob(_job.id, isWorkerDelay: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cancelación por retraso del técnico: Reembolso total procesado e incidente registrado.'),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Técnico no llegó (>30m)', style: TextStyle(color: AppColors.sosRed)),
            ),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.appState.cancelJob(_job.id, isWorkerDelay: false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEnCamino
                        ? 'Cancelado. Reembolso: S/ ${refundAmount.toStringAsFixed(2)} (Compensación técnico: S/ ${compensation.toStringAsFixed(2)})'
                        : 'Solicitud cancelada. Reembolso total procesado.'),
                    backgroundColor: AppColors.secondary,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientCoords = LatLng(_job.latitude, _job.longitude);
    final workerCoords = LatLng(
      _job.latitude + 0.0035,
      _job.longitude - 0.0035,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.neutral),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seguimiento en Vivo',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Text(
              _job.title,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          ChambaBadge(
            label: _job.status.displayLabel,
            type: _job.status == JobStatus.completed
                ? ChambaBadgeType.confirmed
                : ChambaBadgeType.inProgress,
          ),
          if (_job.status != JobStatus.completed && _job.status != JobStatus.cancelled)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: AppColors.sosRed),
              tooltip: 'Cancelar solicitud',
              onPressed: _showCancellationDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mapa interactivo con posición del técnico
            ChambaInteractiveMap(
              mode: MapDisplayMode.tracking,
              height: 220,
              isSos: _job.isSos,
              initialCenter: clientCoords,
              workerPosition: workerCoords,
              clientAddress: _job.address,
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta del Técnico Asignado
                  _buildWorkerInfoCard(),
                  const SizedBox(height: 16),

                  // PIN de Seguridad de 4 dígitos DESTACADO
                  _buildSecurityPinCard(),
                  const SizedBox(height: 16),

                  // Línea de tiempo de fases
                  _buildPhasesTimeline(),
                  const SizedBox(height: 16),

                  // Fotos de Evidencia (Antes / Después) en solo lectura
                  _buildEvidenceSection(),
                  const SizedBox(height: 20),

                  // Acción según fase (Confirmación final cuando esté POR_CONFIRMAR)
                  if (_job.status == JobStatus.forConfirmation) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.tertiary, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '¡El especialista terminó el trabajo!',
                                  style: AppTypography.headlineSm.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Revisa las fotos del Antes y Después. Si todo está conforme, confirma para liberar el pago en garantía. Tienes 24 h de plazo.',
                            style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
                          ),
                          const SizedBox(height: 16),
                          ChambaButton(
                            label: 'Ver Comparador y Confirmar Servicio',
                            backgroundColor: AppColors.tertiary,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => JobConfirmationScreen(
                                    appState: widget.appState,
                                    job: _job,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ] else if (_job.status == JobStatus.completed) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.tertiary),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified, color: AppColors.tertiary, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            '¡Chamba Completada con Éxito!',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.tertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Garantía Chamba de 7 días activa y pago liberado al técnico.',
                            style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ChambaButton(
                            label: 'Ver Recibo y Calificar',
                            leadingIcon: Icons.receipt_long_outlined,
                            variant: ChambaButtonVariant.secondary,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => RatingReceiptScreen(
                                    appState: widget.appState,
                                    job: _job,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F173B4D)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppColors.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _job.workerName ?? 'Especialista Chamba',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '4.9 (42 chambas)',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DNI Verificado',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Llamando a ${_job.workerName ?? "el especialista"}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone, size: 18, color: AppColors.primary),
                  label: const Text('Llamar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChambaButton(
                  label: 'Chat',
                  height: 42,
                  leadingIcon: Icons.chat_bubble_outline,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(appState: widget.appState, job: _job),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityPinCard() {
    final pinDigits = _job.securityPin.isNotEmpty ? _job.securityPin.split('') : ['4', '8', '2', '1'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _job.isPinVerified ? const Color(0xFF0F4C3A) : const Color(0xFF173B4D),
            _job.isPinVerified ? const Color(0xFF1B6B54) : const Color(0xFF23556D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24173B4D),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _job.isPinVerified ? Icons.verified_user_rounded : Icons.shield_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escudo de Confianza CHAMBA',
                      style: AppTypography.labelSm.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _job.isPinVerified ? '¡Identidad Validada en Puerta!' : 'Tu PIN de Seguridad Presencial',
                      style: AppTypography.headlineSm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: pinDigits.map((digit) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 48,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x20000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    digit,
                    style: AppTypography.headlineLg.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _job.isPinVerified
                ? '✅ El especialista validó el código correcto. La intervención está autorizada y asegurada.'
                : 'Pídele este código al técnico en tu puerta antes de dejarlo pasar. No permitas el ingreso sin verificarlo.',
            style: AppTypography.bodyMd.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12.5,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPhasesTimeline() {
    final phases = [
      {'status': JobStatus.accepted, 'label': 'Aceptada'},
      {'status': JobStatus.onTheWay, 'label': 'En camino'},
      {'status': JobStatus.onSite, 'label': 'En sitio'},
      {'status': JobStatus.inProgress, 'label': 'En ejecución'},
      {'status': JobStatus.forConfirmation, 'label': 'Por confirmar'},
      {'status': JobStatus.completed, 'label': 'Completada'},
    ];

    final currentIndex = phases.indexWhere((p) => p['status'] == _job.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F173B4D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fases del Servicio',
            style: AppTypography.headlineSm.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(phases.length, (idx) {
              final isPassed = currentIndex >= idx;
              final isCurrent = currentIndex == idx;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isPassed
                            ? (isCurrent ? AppColors.secondary : AppColors.tertiary)
                            : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phases[idx]['label'] as String,
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 9,
                        color: isPassed ? AppColors.neutral : AppColors.muted,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceSection() {
    final hasBefore = _job.beforePhotoTag != null;
    final hasAfter = _job.afterPhotoTag != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1F173B4D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fotos de Evidencia (Garantía)',
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              ChambaBadge(
                label: hasAfter ? '2 / 2 Fotos' : (hasBefore ? '1 / 2 Fotos' : '0 / 2 Fotos'),
                type: hasAfter ? ChambaBadgeType.confirmed : ChambaBadgeType.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Foto Antes
              Expanded(
                child: _buildPhotoBox(
                  title: 'Foto "Antes"',
                  isUploaded: hasBefore,
                  tag: _job.beforePhotoTag,
                  placeholder: 'A la espera de foto inicial del técnico',
                ),
              ),
              const SizedBox(width: 12),
              // Foto Después
              Expanded(
                child: _buildPhotoBox(
                  title: 'Foto "Después"',
                  isUploaded: hasAfter,
                  tag: _job.afterPhotoTag,
                  placeholder: 'Se cargará al concluir la labor',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBox({
    required String title,
    required bool isUploaded,
    required String? tag,
    required String placeholder,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? AppColors.surfaceContainerLow : const Color(0xFFF9FAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? AppColors.tertiary.withValues(alpha: 0.3) : const Color(0x1F173B4D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle : Icons.camera_alt_outlined,
                size: 16,
                color: isUploaded ? AppColors.tertiary : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isUploaded ? const Color(0xFFEAF5F0) : const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isUploaded
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image, size: 28, color: AppColors.tertiary),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          tag ?? 'Foto registrada',
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 10,
                            color: AppColors.neutral,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        placeholder,
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
