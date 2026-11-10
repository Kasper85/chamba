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
import 'worker_wallet_screen.dart';

/// Vista de seguimiento especializada para el CHAMBEADOR / ESPECIALISTA (ALCANCE.md §8 L4)
/// Incluye mapa de ruta al cliente, botón "Estoy en camino", botón "Llegué al domicilio",
/// validación interactiva del PIN del cliente en puerta, y cámara obligatoria para foto
/// del "Antes" (desbloquea inicio de trabajo) y foto del "Después" (desbloquea fin de trabajo).
class WorkerJobTrackingView extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const WorkerJobTrackingView({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<WorkerJobTrackingView> createState() => _WorkerJobTrackingViewState();
}

class _WorkerJobTrackingViewState extends State<WorkerJobTrackingView> {
  late JobRequest _job;
  bool _isLoading = false;
  String _pinInput = '';
  String? _pinError;

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

  void _onKeypadTap(String digit) {
    if (_pinInput.length < 4) {
      setState(() {
        _pinInput += digit;
        _pinError = null;
      });

      if (_pinInput.length == 4) {
        _submitPinVerification();
      }
    }
  }

  void _onKeypadBackspace() {
    if (_pinInput.isNotEmpty) {
      setState(() {
        _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        _pinError = null;
      });
    }
  }

  void _submitPinVerification() {
    final validPin = _job.securityPin.trim().isNotEmpty ? _job.securityPin.trim() : _job.confirmationCode.trim();
    if (_pinInput.trim() == validPin) {
      setState(() {
        _pinError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ ¡PIN Validado con éxito! Ahora captura la foto del antes para iniciar.'),
          backgroundColor: AppColors.tertiary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _pinError = 'PIN incorrecto. Pídele al cliente el código de su pantalla.';
        _pinInput = '';
      });
    }
  }

  Future<void> _advancePhase(JobStatus nextPhase, {String? pin, String? photoBefore, String? photoAfter}) async {
    setState(() => _isLoading = true);
    try {
      final success = await widget.appState.advanceJobPhase(
        jobId: _job.id,
        nextPhase: nextPhase,
        pin: pin,
        photoBefore: photoBefore,
        photoAfter: photoAfter,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo avanzar la fase. Verifica que los requisitos se cumplan.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEvidenceCaptureSheet({required bool isBefore}) {
    final title = isBefore ? 'Foto del Problema Inicial (Antes)' : 'Foto del Trabajo Resuelto (Después)';
    final subtitle = isBefore
        ? 'Registra la falla antes de intervenir para proteger la garantía.'
        : 'Sube la foto del acabado final para que el cliente verifique y libere los fondos.';

    final options = isBefore
        ? [
            'Fuga activa con tubería partida en pared',
            'Cables sulfatados y chispeando en tablero',
            'Inodoro desbordado con empaque roto',
            'Cerradura trabada sin pestillo',
          ]
        : [
            'Termofusión certificada con prueba de presión',
            'Llaves Schneider nuevas con rotulado peineta',
            'Sanitario sellado y funcionando al 100%',
            'Chapa Phillips nueva instalada y lubricada',
          ];

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
                    width: 40,
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
                        color: isBefore
                            ? AppColors.secondary.withValues(alpha: 0.15)
                            : AppColors.tertiary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isBefore ? Icons.camera_alt_rounded : Icons.check_circle_rounded,
                        color: isBefore ? AppColors.secondary : AppColors.tertiary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Captura de evidencia fotográfica obligatoria:',
                  style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 10),
                ...options.map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        if (isBefore) {
                          _advancePhase(
                            JobStatus.inProgress,
                            pin: _pinInput.isNotEmpty ? _pinInput : _job.securityPin,
                            photoBefore: opt,
                          );
                        } else {
                          _advancePhase(
                            JobStatus.forConfirmation,
                            photoAfter: opt,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x1F173B4D)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.photo_camera_back_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt,
                                style: AppTypography.bodyLgMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutral,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
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
              'Trabajo Activo (Técnico)',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.workerPrimary,
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
            type: ChambaBadgeType.inProgress,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mapa con ruta hacia el cliente
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
                  // Tarjeta del Cliente y Domicilio
                  _buildClientInfoCard(),
                  const SizedBox(height: 16),

                  // Controles según fase actual (§7 Chambeador)
                  _buildWorkerPhaseControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientInfoCard() {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.workerAccent.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: AppColors.workerPrimary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _job.clientName,
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _job.address,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Llamando al cliente ${_job.clientName}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.phone, size: 18, color: AppColors.workerPrimary),
                  label: const Text('Llamar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.workerPrimary,
                    side: const BorderSide(color: AppColors.workerPrimary),
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

  Widget _buildWorkerPhaseControls() {
    switch (_job.status) {
      case JobStatus.accepted:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F173B4D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_clock, color: AppColors.secondary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chamba Aceptada',
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
                'El cliente tiene fondos asegurados en garantía. Presiona "Estoy en camino" cuando salgas al domicilio.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 16),
              ChambaButton(
                label: 'Estoy en camino',
                variant: ChambaButtonVariant.primary,
                isLoading: _isLoading,
                onPressed: () => _advancePhase(JobStatus.onTheWay),
              ),
            ],
          ),
        );

      case JobStatus.onTheWay:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F173B4D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bike, color: AppColors.secondary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'En Camino al Domicilio',
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
                'Sigue la ruta en el mapa hacia ${_job.address}. Al llegar a la puerta del cliente, pulsa el botón.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 16),
              ChambaButton(
                label: 'Llegué al domicilio',
                variant: ChambaButtonVariant.primary,
                isLoading: _isLoading,
                onPressed: () => _advancePhase(JobStatus.onSite),
              ),
            ],
          ),
        );

      case JobStatus.onSite:
        final isPinValid = _job.isPinVerified || _pinInput.length == 4 && _pinError == null;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPinValid ? AppColors.tertiary : AppColors.workerAccent,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isPinValid ? Icons.verified_user_rounded : Icons.pin_outlined,
                    color: isPinValid ? AppColors.tertiary : AppColors.workerPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPinValid ? '¡PIN Validado en Puerta!' : 'Validar PIN del Cliente',
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isPinValid ? AppColors.tertiary : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isPinValid
                    ? 'Identidad confirmada. Ahora es obligatorio tomar la Foto del Antes para iniciar la intervención.'
                    : 'Pídele al cliente el código de 4 dígitos que aparece en su pantalla para identificarte formalmente.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 14),

              if (!isPinValid) ...[
                // Input visual de PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final hasChar = index < _pinInput.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 48,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasChar ? AppColors.surfaceContainerLow : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _pinError != null ? AppColors.error : AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        hasChar ? _pinInput[index] : '•',
                        style: AppTypography.headlineLg.copyWith(
                          color: hasChar ? AppColors.primary : AppColors.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    );
                  }),
                ),
                if (_pinError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _pinError!,
                    style: AppTypography.labelSm.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 14),

                // Teclado numérico
                _buildNumericKeypad(),
              ] else ...[
                // Botón obligatorio para capturar la Foto del Antes
                const SizedBox(height: 10),
                ChambaButton(
                  label: '📸 Capturar Foto del "Antes"',
                  variant: ChambaButtonVariant.secondary,
                  isLoading: _isLoading,
                  onPressed: () => _showEvidenceCaptureSheet(isBefore: true),
                ),
              ],
            ],
          ),
        );

      case JobStatus.inProgress:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F173B4D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.handyman, color: AppColors.secondary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Trabajo en Ejecución',
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
                'Foto inicial registrada: "${_job.beforePhotoTag ?? "Evidencia inicial"}".\nAl terminar la reparación, captura la foto del acabado para solicitar la conformidad del cliente.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 16),
              ChambaButton(
                label: '✨ Subir Foto del "Después" y Finalizar',
                backgroundColor: AppColors.tertiary,
                isLoading: _isLoading,
                onPressed: () => _showEvidenceCaptureSheet(isBefore: false),
              ),
            ],
          ),
        );

      case JobStatus.forConfirmation:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.secondary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AppColors.secondary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esperando Conformidad',
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
                'Fotos del Antes y Después enviadas al cliente. El cliente tiene un plazo de 24 h para liberar el pago en garantía. Si no hay reclamo dentro del plazo, los fondos se liberan automáticamente.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
              ),
            ],
          ),
        );

      case JobStatus.completed:
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.tertiary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.monetization_on_rounded, color: AppColors.tertiary, size: 40),
              const SizedBox(height: 8),
              Text(
                '¡Pago Liberado a tu Billetera!',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'El cliente confirmó la recepción del servicio. Se descontó la comisión de plataforma del 8% y el neto está en tu saldo.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ChambaButton(
                label: 'Ver Ganancias en Billetera',
                variant: ChambaButtonVariant.primary,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkerWalletScreen(appState: widget.appState),
                    ),
                  );
                },
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNumericKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 48);
              }
              final isDel = key == 'DEL';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 72,
                height: 48,
                child: OutlinedButton(
                  onPressed: isDel ? _onKeypadBackspace : () => _onKeypadTap(key),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: Color(0x22173B4D)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.white,
                  ),
                  child: isDel
                      ? const Icon(Icons.backspace_outlined, size: 18, color: AppColors.neutral)
                      : Text(
                          key,
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral,
                          ),
                        ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
