import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import '../widgets/chamba_interactive_map.dart';
import 'chat_screen.dart';

class JobTrackingScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const JobTrackingScreen({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<JobTrackingScreen> createState() => _JobTrackingScreenState();
}

class _JobTrackingScreenState extends State<JobTrackingScreen> {
  late JobRequest _job;
  int _selectedRating = 5;
  final _reviewController = TextEditingController();
  String _selectedEscrowPaymentMethod = 'Yape';

  // State to simulate Technician entering the PIN on the door
  bool _isWorkerSimulatedMode = false;
  String _pinInput = '';
  String? _pinError;

  final List<String> _feedbackTags = [
    'Puntualidad 10/10',
    'Trabajo impecable',
    'Precio justo',
    'Herramientas completas',
    'Muy respetuoso',
  ];
  final Set<String> _chosenTags = {'Puntualidad 10/10', 'Precio justo'};

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _isWorkerSimulatedMode = widget.appState.currentRole == UserRole.worker;
    widget.appState.addListener(_onStateUpdate);
  }

  void _onStateUpdate() {
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
    widget.appState.removeListener(_onStateUpdate);
    _reviewController.dispose();
    super.dispose();
  }

  void _onKeypadTap(String digit) {
    if (_pinInput.length < 4) {
      setState(() {
        _pinInput += digit;
        _pinError = null;
      });

      if (_pinInput.length == 4) {
        _submitPinVerification(_pinInput);
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

  void _submitPinVerification(String pin) {
    final success = widget.appState.verifySecurityPin(_job.id, pin);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ ¡PIN Validado con éxito! Técnico identificado en puerta.'),
          backgroundColor: AppColors.tertiary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _pinError = null;
        _pinInput = '';
      });
    } else {
      setState(() {
        _pinError = 'PIN incorrecto. Pídele al cliente el código de su pantalla.';
        _pinInput = '';
      });
    }
  }

  void _showShareTrackingSheet() {
    showModalBottomSheet(
      context: context,
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
                        color: AppColors.tertiary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_location_rounded, color: AppColors.tertiary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compartir Enlace de Seguridad',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Tus familiares sabrán quién y cuándo llega a tu hogar',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x1F173B4D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enlace protegido en vivo:',
                        style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'https://chamba.pe/track/${_job.securityPin}',
                        style: AppTypography.bodyLgMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Incluye: Nombre del técnico, DNI verificado en RENIEC, placa de moto y PIN presencial (${_job.securityPin}).',
                        style: AppTypography.labelSm.copyWith(color: AppColors.neutral, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ChambaButton(
                  label: 'Compartir por WhatsApp',
                  leadingIcon: Icons.send_rounded,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Enlace de seguridad copiado y compartido por WhatsApp!'),
                        backgroundColor: AppColors.tertiary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCameraSimulationSheet({required bool isBefore}) {
    final title = isBefore ? 'Foto del Problema Inicial (Antes)' : 'Foto del Trabajo Resuelto (Después)';
    final subtitle = isBefore
        ? 'El técnico registra la falla antes de intervenir para proteger la garantía.'
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
                        color: isBefore ? AppColors.secondary.withValues(alpha: 0.15) : AppColors.tertiary.withValues(alpha: 0.15),
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
                  'Selecciona una captura de evidencia simulada:',
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
                          widget.appState.uploadBeforeEvidence(jobId: _job.id, tag: opt);
                        } else {
                          widget.appState.uploadAfterEvidence(jobId: _job.id, tag: opt);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
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

  void _showDepositEscrowSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                            color: AppColors.tertiary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_rounded, color: AppColors.tertiary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pago Protegido en Custodia',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                'Tu dinero se retiene de forma 100% segura hasta que el trabajo esté terminado.',
                                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x1F173B4D)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monto en Custodia:',
                            style: AppTypography.bodyLgMedium.copyWith(color: AppColors.neutral),
                          ),
                          Text(
                            'S/. ${_job.budget.toStringAsFixed(0)}',
                            style: AppTypography.numericBid.copyWith(
                              color: AppColors.secondary,
                              fontSize: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Elige método de depósito:',
                      style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentOption('Yape', 'Billetera digital BCP (+51 974 812 345)', Icons.qr_code_2, setModalState),
                    _buildPaymentOption('Plin', 'Interbank, Scotiabank, BBVA', Icons.phone_android, setModalState),
                    _buildPaymentOption('Tarjeta Visa/Mastercard', 'Débito o Crédito sin recargo', Icons.credit_card_rounded, setModalState),
                    const SizedBox(height: 20),
                    ChambaButton(
                      label: 'Depositar S/. ${_job.budget.toStringAsFixed(0)} en Custodia',
                      leadingIcon: Icons.lock_outline_rounded,
                      onPressed: () {
                        widget.appState.depositEscrow(
                          jobId: _job.id,
                          paymentMethod: _selectedEscrowPaymentMethod,
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOption(String title, String subtitle, IconData icon, StateSetter setModalState) {
    final isSelected = _selectedEscrowPaymentMethod == title;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setModalState(() => _selectedEscrowPaymentMethod = title);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0x1F202D33),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.secondary : AppColors.muted, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLgMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showReleaseSuccessCelebrationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.tertiary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: AppColors.tertiary, size: 54),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Chamba Exitosa y Garantizada!',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Se han transferido S/. ${_job.budget.toStringAsFixed(0)} de la cuenta de garantía a ${_job.workerName ?? "el especialista"}.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.neutral),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.shieldWarranty.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.shieldWarranty.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 16, color: AppColors.shieldWarranty),
                  const SizedBox(width: 6),
                  Text(
                    '🛡️ Garantía Chamba de 7 días activa',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.shieldWarranty,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ChambaButton(
              label: 'Calificar al Especialista ⭐',
              onPressed: () {
                Navigator.of(ctx).pop();
                _showRatingModal();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    Text(
                      '¿Cómo estuvo el servicio?',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu calificación ayuda a técnicos honestos en Chiclayo a recibir más trabajo.',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Star Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final isFilled = star <= _selectedRating;
                        return IconButton(
                          iconSize: 36,
                          icon: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber,
                          ),
                          onPressed: () {
                            setModalState(() => _selectedRating = star);
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Quick Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _feedbackTags.map((tag) {
                        final isChosen = _chosenTags.contains(tag);
                        return FilterChip(
                          selected: isChosen,
                          label: Text(tag),
                          labelStyle: AppTypography.labelSm.copyWith(
                            color: isChosen ? Colors.white : AppColors.neutral,
                            fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                          ),
                          backgroundColor: AppColors.canvas,
                          selectedColor: AppColors.primary,
                          showCheckmark: false,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                _chosenTags.add(tag);
                              } else {
                                _chosenTags.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _reviewController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Comentario opcional sobre el trabajo...',
                        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ChambaButton(
                      label: 'Enviar Calificación',
                      onPressed: () {
                        widget.appState.rateJob(
                          jobId: _job.id,
                          rating: _selectedRating,
                          reviewComment: _reviewController.text.trim(),
                        );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Gracias por calificar! Tu opinión fue registrada.'),
                            backgroundColor: AppColors.tertiary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '¿Cancelar solicitud?',
          style: AppTypography.headlineSm.copyWith(color: AppColors.primary),
        ),
        content: Text(
          'Al cancelar la solicitud, los fondos en garantía serán devueltos a tu cuenta de inmediato.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.appState.cancelJob(_job.id);
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workerName = _job.workerName ?? 'Jorge Quispe Baldera';
    final clientCoords = LatLng(_job.latitude, _job.longitude);
    final workerCoords = LatLng(_job.latitude + 0.006, _job.longitude + 0.008);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          _job.isSos ? '🚨 Chamba SOS en Curso' : 'Servicio Protegido y Seguimiento',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Abrir chat',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(appState: widget.appState, job: _job),
                ),
              );
            },
          ),
          if (_job.status != JobStatus.completed && _job.status != JobStatus.cancelled)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'cancel') _showCancelDialog();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancelar Solicitud', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Status Card
              ChambaCard(
                color: _job.isSos ? AppColors.sosRed : AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_job.isSos)
                          const ChambaBadge.sos(label: 'EMERGENCIA SOS < 30 MIN')
                        else
                          ChambaBadge.confirmed(label: _job.status.displayLabel),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'PIN: ${_job.securityPin}',
                                style: AppTypography.labelSm.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _job.title,
                      style: AppTypography.headlineSm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dirección: ${_job.address}, ${_job.district}',
                      style: AppTypography.bodyMd.copyWith(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    if (_job.reference.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'Ref: ${_job.reference}',
                          style: AppTypography.labelSm.copyWith(color: Colors.white60),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Colors.white24),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monto en Garantía:',
                              style: AppTypography.bodyMd.copyWith(color: Colors.white70),
                            ),
                            if (_job.isSos)
                              Text(
                                'Tarifa SOS Dinámica (+35%)',
                                style: AppTypography.labelSm.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'S/. ${_job.budget.toStringAsFixed(0)}',
                          style: AppTypography.numericBid.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Interactive Live Tracking Map with SOS Radar support
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ruta en Vivo y Posición del Especialista',
                    style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
                  ),
                  if (_job.isSos)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sosRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Llegada < 18 min',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.sosRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ChambaInteractiveMap(
                mode: MapDisplayMode.tracking,
                height: 220,
                isSos: _job.isSos,
                initialCenter: clientCoords,
                workerPosition: workerCoords,
                clientAddress: _job.address,
              ),
              const SizedBox(height: 16),

              // Assigned Worker Card with Trust Shield
              ChambaCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            workerName[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workerName,
                                style: AppTypography.bodyLgMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.neutral,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    '4.9 ⭐ (142 chambas)',
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
                    // Escudo de Confianza Badges
                    const TrustShieldBadgesRow(
                      isIdVerified: true,
                      hasCleanRecord: true,
                      offersWarranty: true,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ChambaButton.secondary(
                            label: 'Llamar',
                            height: 44,
                            leadingIcon: Icons.phone,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Llamando al especialista...')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChambaButton(
                            label: 'Chat',
                            height: 44,
                            leadingIcon: Icons.chat,
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
              ),
              const SizedBox(height: 16),

              // Perspective Switcher (Simulate Client vs. Worker PIN validation)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isWorkerSimulatedMode ? Icons.handyman_rounded : Icons.person_rounded,
                          size: 18,
                          color: _isWorkerSimulatedMode ? AppColors.workerAccent : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isWorkerSimulatedMode ? 'Vista Técnico: Validación PIN' : 'Vista Cliente: Tu Código PIN',
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {
                        setState(() {
                          _isWorkerSimulatedMode = !_isWorkerSimulatedMode;
                          _pinInput = '';
                          _pinError = null;
                        });
                      },
                      child: Text(
                        _isWorkerSimulatedMode ? 'Ver como Cliente' : 'Simular Técnico',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==========================================
              // REQUIREMENT 3: PIN DE SEGURIDAD Y ESCUDO DE CONFIANZA
              // ==========================================
              if (!_isWorkerSimulatedMode) ...[
                // CLIENT VIEW OF SECURITY PIN
                Container(
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
                                  'Escudo de Confianza Chamba',
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
                          children: _job.securityPin.split('').map((digit) {
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
                            ? '✅ El especialista ingresó el código correcto. La intervención está autorizada y asegurada.'
                            : 'Pídele este código al técnico en tu puerta antes de dejarlo pasar. No permitas el ingreso sin verificarlo.',
                        style: AppTypography.bodyMd.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white60),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: _showShareTrackingSheet,
                              icon: const Icon(Icons.share_location_rounded, size: 18),
                              label: const Text('Compartir seguimiento en vivo'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // WORKER / TECHNICIAN VIEW - INTERACTIVE PIN VALIDATION INPUT
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _job.isPinVerified ? AppColors.tertiary : AppColors.workerAccent,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 10,
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
                              color: AppColors.workerAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.dialpad_rounded, color: AppColors.workerAccent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Validación de Entrada en Puerta',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.workerAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Ingresa el PIN de 4 dígitos',
                                  style: AppTypography.headlineSm.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Solicita el código que el cliente tiene en su app para desbloquear el inicio del trabajo.',
                        style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      // PIN Boxes Display
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final hasDigit = index < _pinInput.length;
                          final digitChar = hasDigit ? _pinInput[index] : '';
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 50,
                            height: 54,
                            decoration: BoxDecoration(
                              color: _job.isPinVerified
                                  ? AppColors.tertiary.withValues(alpha: 0.12)
                                  : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _pinError != null
                                    ? Colors.red
                                    : hasDigit
                                        ? AppColors.workerAccent
                                        : const Color(0x1F173B4D),
                                width: hasDigit ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _job.isPinVerified ? _job.securityPin[index] : digitChar,
                              style: AppTypography.headlineLg.copyWith(
                                color: _job.isPinVerified ? AppColors.tertiary : AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_pinError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _pinError!,
                          style: AppTypography.labelSm.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (_job.isPinVerified) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.tertiary, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '¡PIN Correcto! Trabajo desbloqueado.',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.tertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 16),
                        // Interactive Numeric Keypad
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              for (var row in [
                                ['1', '2', '3'],
                                ['4', '5', '6'],
                                ['7', '8', '9'],
                                ['', '0', '⌫'],
                              ])
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: row.map((key) {
                                      if (key.isEmpty) {
                                        return const SizedBox(width: 64, height: 44);
                                      }
                                      return SizedBox(
                                        width: 64,
                                        height: 44,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: AppColors.primary,
                                            elevation: 1,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () {
                                            if (key == '⌫') {
                                              _onKeypadBackspace();
                                            } else {
                                              _onKeypadTap(key);
                                            }
                                          },
                                          child: Text(
                                            key,
                                            style: AppTypography.bodyLgMedium.copyWith(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // ==========================================
              // REQUIREMENT 4: PAGO PROTEGIDO (ESCROW) Y STEPPER INTERACTIVO DE 4 FASES
              // ==========================================
              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pago Protegido y Evidencia (Escrow)',
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.security, size: 13, color: AppColors.tertiary),
                              const SizedBox(width: 4),
                              Text(
                                'Garantía Chamba',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.tertiary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Flujo de custodia en 4 fases para garantizar que el dinero solo se pague con trabajo de calidad verificado.',
                      style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),

                    // PHASE 1: PAGO EN GARANTÍA (ESCROW)
                    _buildEscrowPhaseCard(
                      phaseNumber: 1,
                      title: 'Fase 1: Pago en Garantía (Escrow)',
                      isCompleted: _job.escrowStatus != EscrowStatus.pendingDeposit,
                      isCurrent: _job.escrowStatus == EscrowStatus.pendingDeposit,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_job.escrowStatus == EscrowStatus.pendingDeposit) ...[
                            Text(
                              'Los fondos aún no han sido depositados en custodia.',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 8),
                            ChambaButton(
                              label: 'Depositar S/. ${_job.budget.toStringAsFixed(0)} en Custodia',
                              leadingIcon: Icons.lock_outline_rounded,
                              height: 42,
                              onPressed: _showDepositEscrowSheet,
                            ),
                          ] else ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.tertiary, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'S/. ${_job.budget.toStringAsFixed(0)} en custodia retenida por Chamba',
                                    style: AppTypography.bodyLgMedium.copyWith(
                                      color: AppColors.tertiary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Retenido de forma segura. El técnico solo recibirá el dinero tras tu aprobación de la obra.',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // PHASE 2: LLEGADA Y PIN DE SEGURIDAD
                    _buildEscrowPhaseCard(
                      phaseNumber: 2,
                      title: 'Fase 2: Llegada y PIN de Seguridad',
                      isCompleted: _job.isPinVerified,
                      isCurrent: _job.escrowStatus != EscrowStatus.pendingDeposit && !_job.isPinVerified,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_job.isPinVerified) ...[
                            Row(
                              children: [
                                const Icon(Icons.verified_user_rounded, color: AppColors.tertiary, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Técnico validado en puerta con código ${_job.securityPin}',
                                    style: AppTypography.bodyLgMedium.copyWith(
                                      color: AppColors.tertiary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Identidad física confirmada. Trabajo oficialmente iniciado.',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11.5),
                            ),
                          ] else ...[
                            Text(
                              'Pendiente de validación presencial en el domicilio.',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 8),
                            ChambaButton.secondary(
                              label: 'Validar PIN en Puerta',
                              height: 40,
                              leadingIcon: Icons.pin,
                              onPressed: () {
                                setState(() => _isWorkerSimulatedMode = true);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // PHASE 3: EVIDENCIA DEL "ANTES" Y EJECUCIÓN
                    _buildEscrowPhaseCard(
                      phaseNumber: 3,
                      title: 'Fase 3: Evidencia del "Antes" y Ejecución',
                      isCompleted: _job.beforePhotoTag != null,
                      isCurrent: _job.isPinVerified && _job.beforePhotoTag == null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_job.beforePhotoTag != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x1F173B4D)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Foto del Problema Inicial (Antes):',
                                          style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
                                        ),
                                        Text(
                                          _job.beforePhotoTag!,
                                          style: AppTypography.bodyLgMedium.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check, color: AppColors.tertiary, size: 16),
                                ],
                              ),
                            ),
                          ] else if (!_job.isPinVerified) ...[
                            Text(
                              'Se desbloqueará una vez validado el PIN presencial.',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                          ] else ...[
                            Text(
                              'Registra el estado del desperfecto antes de intervenir para activar la garantía.',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 8),
                            ChambaButton(
                              label: '📸 Capturar Foto del "Antes"',
                              height: 40,
                              onPressed: () => _showCameraSimulationSheet(isBefore: true),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // PHASE 4: EVIDENCIA DEL "DESPUÉS" Y LIBERACIÓN DE FONDOS
                    _buildEscrowPhaseCard(
                      phaseNumber: 4,
                      title: 'Fase 4: Evidencia del "Después" y Liberación',
                      isCompleted: _job.escrowStatus == EscrowStatus.released,
                      isCurrent: _job.beforePhotoTag != null && _job.escrowStatus != EscrowStatus.released,
                      isLast: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_job.escrowStatus == EscrowStatus.released) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.tertiary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified, color: AppColors.tertiary, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '¡Fondos Liberados Exitosamente!',
                                          style: AppTypography.labelLg.copyWith(
                                            color: AppColors.tertiary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          'S/. ${_job.budget.toStringAsFixed(0)} transferidos • Garantía activa de 7 días',
                                          style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_job.afterPhotoTag == null) ...[
                            if (_job.beforePhotoTag == null)
                              Text(
                                'Se desbloqueará al subir la foto inicial del problema.',
                                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                              )
                            else ...[
                              Text(
                                'El técnico debe capturar la reparación finalizada.',
                                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 8),
                              ChambaButton(
                                label: '✨ Subir Foto del "Después" (Solucionado)',
                                height: 40,
                                onPressed: () => _showCameraSimulationSheet(isBefore: false),
                              ),
                            ],
                          ] else ...[
                            // After photo is uploaded, client can approve and release funds!
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x1F173B4D)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.task_alt_rounded, color: AppColors.tertiary, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Foto del Trabajo Resuelto (Después):',
                                          style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
                                        ),
                                        Text(
                                          _job.afterPhotoTag!,
                                          style: AppTypography.bodyLgMedium.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check, color: AppColors.tertiary, size: 16),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ChambaButton(
                              label: 'Confirmar Conformidad y Liberar Pago (S/. ${_job.budget.toStringAsFixed(0)})',
                              leadingIcon: Icons.payments_rounded,
                              onPressed: () async {
                                final workerId = _job.workerId ?? 'worker-1';
                                try {
                                  await widget.appState.releaseEscrowFunds(
                                    jobId: _job.id,
                                    workerUserId: workerId,
                                    amount: _job.budget,
                                  );
                                } catch (_) {
                                  widget.appState.releaseEscrow(_job.id);
                                }
                                if (mounted) {
                                  _showReleaseSuccessCelebrationDialog();
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Final Rating Button if completed and rating not provided
              if (_job.escrowStatus == EscrowStatus.released) ...[
                if (_job.rating == null)
                  ChambaButton.secondary(
                    label: 'Calificar al Especialista ⭐',
                    onPressed: _showRatingModal,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.tertiary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.tertiary),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified, color: AppColors.tertiary),
                        const SizedBox(width: 8),
                        Text(
                          'Servicio Calificado (${_job.rating} ⭐)',
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEscrowPhaseCard({
    required int phaseNumber,
    required String title,
    required bool isCompleted,
    required bool isCurrent,
    required Widget child,
    bool isLast = false,
  }) {
    Color badgeColor;
    if (isCompleted) {
      badgeColor = AppColors.tertiary;
    } else if (isCurrent) {
      badgeColor = AppColors.secondary;
    } else {
      badgeColor = const Color(0x33202D33);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? AppColors.secondary
              : isCompleted
                  ? AppColors.tertiary.withValues(alpha: 0.4)
                  : const Color(0x1F202D33),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.tertiary : badgeColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$phaseNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyLgMedium.copyWith(
                    fontWeight: isCurrent || isCompleted ? FontWeight.w800 : FontWeight.w600,
                    color: isCompleted
                        ? AppColors.tertiary
                        : isCurrent
                            ? AppColors.primary
                            : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 34.0),
            child: child,
          ),
        ],
      ),
    );
  }
}
