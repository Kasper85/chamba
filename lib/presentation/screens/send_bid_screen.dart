import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../core/widgets/price_dial_stepper.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import '../widgets/chamba_interactive_map.dart';
import 'worker_my_jobs_screen.dart';

class SendBidScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const SendBidScreen({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<SendBidScreen> createState() => _SendBidScreenState();
}

class _SendBidScreenState extends State<SendBidScreen> with SingleTickerProviderStateMixin {
  late double _proposedAmount;
  int _selectedEtaMinutes = 25;
  final _messageController = TextEditingController(
    text: 'Tengo las herramientas y repuestos listos. Puedo salir de inmediato.',
  );
  bool _isSubmitting = false;

  // Voice Note State
  bool _isRecording = false;
  bool _hasVoiceNote = false;
  int _voiceSeconds = 0;
  Timer? _recordTimer;
  bool _isPlayingVoice = false;
  Timer? _playbackTimer;
  int _playbackProgress = 0;
  late AnimationController _waveAnimController;

  // Quick Inclusion Tags
  final Set<String> _selectedInclusions = {'Solo mano de obra', 'Llego en < 25 min'};
  final List<String> _availableInclusions = [
    'Incluye materiales',
    'Solo mano de obra',
    'Diagnóstico gratis',
    'Llego en < 25 min',
    'Garantía 7 días',
  ];

  final List<int> _etaOptions = [15, 25, 40, 60];

  final List<String> _quickNotes = [
    'Herramientas y repuestos en mi moto',
    'Llego en menos de 30 minutos',
    'Garantía de servicio por escrito',
    'Precio final sin cobros sorpresa',
  ];

  @override
  void initState() {
    super.initState();
    _proposedAmount = widget.job.budget;
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    widget.appState.joinJobRoom(widget.job.id);
  }

  @override
  void dispose() {
    widget.appState.leaveJobRoom(widget.job.id);
    _recordTimer?.cancel();
    _playbackTimer?.cancel();
    _waveAnimController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _voiceSeconds = 0;
      _hasVoiceNote = false;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_voiceSeconds >= 15) {
        _stopRecording();
      } else {
        setState(() => _voiceSeconds++);
      }
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _hasVoiceNote = true;
      if (_voiceSeconds == 0) _voiceSeconds = 8; // fallback realistic duration
    });
  }

  void _togglePlayback() {
    if (_isPlayingVoice) {
      _playbackTimer?.cancel();
      setState(() {
        _isPlayingVoice = false;
        _playbackProgress = 0;
      });
    } else {
      setState(() {
        _isPlayingVoice = true;
        _playbackProgress = 0;
      });
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_playbackProgress >= _voiceSeconds) {
          timer.cancel();
          setState(() {
            _isPlayingVoice = false;
            _playbackProgress = 0;
          });
        } else {
          setState(() => _playbackProgress++);
        }
      });
    }
  }

  void _deleteVoiceNote() {
    _playbackTimer?.cancel();
    setState(() {
      _hasVoiceNote = false;
      _isPlayingVoice = false;
      _voiceSeconds = 0;
      _playbackProgress = 0;
    });
  }

  void _submitBid() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final transcript = _hasVoiceNote
        ? 'Hola vecino, tengo las herramientas en mi moto y puedo resolver ${_selectedInclusions.contains("Incluye materiales") ? "incluyendo materiales" : "la mano de obra"} de inmediato.'
        : null;

    widget.appState.submitBid(
      jobId: widget.job.id,
      amount: _proposedAmount,
      etaMinutes: _selectedEtaMinutes,
      message: _messageController.text.trim(),
      hasVoiceNote: _hasVoiceNote,
      voiceDurationSeconds: _voiceSeconds,
      voiceTranscriptPreview: transcript,
      includesMaterials: _selectedInclusions.contains('Incluye materiales'),
      estimatedArrival: '$_selectedEtaMinutes min',
      inclusionTags: _selectedInclusions.toList(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Oferta de S/. ${_proposedAmount.toStringAsFixed(0)} ${_hasVoiceNote ? "con Nota de Voz " : ""}enviada a ${widget.job.clientName}!',
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkerMyJobsScreen(appState: widget.appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientBudget = widget.job.budget;
    final isDirectAccept = (_proposedAmount - clientBudget).abs() < 0.1;
    final isHigher = _proposedAmount > clientBudget;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Enviar Cotización'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.appState.isSocketConnected
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: widget.appState.isSocketConnected
                          ? const Color(0xFF047857)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.appState.isSocketConnected ? 'En vivo' : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.appState.isSocketConnected
                            ? const Color(0xFF047857)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client request summary card
              ChambaCard(
                color: widget.job.isSos ? const Color(0xFFFFF7F5) : AppColors.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.job.categoryName.toUpperCase(),
                              style: AppTypography.labelSm.copyWith(
                                color: widget.job.isSos ? AppColors.sosRed : AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (widget.job.isSos) ...[
                              const SizedBox(width: 8),
                              const ChambaBadge.sos(label: 'SOS < 30 MIN'),
                            ],
                          ],
                        ),
                        Text(
                          'A ${widget.job.distanceKm} km',
                          style: AppTypography.labelSm.copyWith(
                            color: widget.job.isSos ? AppColors.sosRed : AppColors.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.job.title,
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutral,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.job.description,
                      style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0x14202D33)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Presupuesto ofrecido por cliente:',
                          style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                        ),
                        Text(
                          'S/. ${clientBudget.toStringAsFixed(0)}',
                          style: AppTypography.labelLg.copyWith(
                            color: widget.job.isSos ? AppColors.sosRed : AppColors.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Approximate Privacy Map Preview
              Text(
                'Zona Aproximada de Trabajo',
                style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 6),
              Text(
                'Por seguridad del cliente, se muestra el radio aproximado de 500m en ${widget.job.district}:',
                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              ChambaInteractiveMap(
                mode: MapDisplayMode.approximate,
                height: 180,
                isSos: widget.job.isSos,
                initialCenter: LatLng(widget.job.latitude, widget.job.longitude),
                isInteractive: false,
              ),
              const SizedBox(height: 20),

              // inDrive Price dial negotiation with Semáforo
              PriceDialStepper(
                currentPrice: _proposedAmount,
                recommendedPrice: clientBudget,
                minPrice: 15.0,
                maxPrice: 1500.0,
                label: 'Tu Propuesta de Precio en Soles',
                isSosSurge: widget.job.isSos,
                surgeLabel: '⚡ Tarifa de Emergencia SOS (+35%)',
                onPriceChanged: (val) {
                  setState(() => _proposedAmount = val);
                },
              ),
              const SizedBox(height: 12),

              // Status indicator comparing against client offer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDirectAccept
                      ? AppColors.tertiary.withValues(alpha: 0.1)
                      : isHigher
                          ? AppColors.secondary.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDirectAccept
                          ? Icons.check_circle_outline
                          : isHigher
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                      size: 16,
                      color: isDirectAccept
                          ? AppColors.tertiary
                          : isHigher
                              ? AppColors.secondary
                              : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDirectAccept
                            ? 'Aceptas directamente el presupuesto del cliente'
                            : isHigher
                                ? 'Contraoferta: propones S/. ${(_proposedAmount - clientBudget).toStringAsFixed(0)} más'
                                : 'Propones una tarifa S/. ${(clientBudget - _proposedAmount).toStringAsFixed(0)} más económica',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDirectAccept
                              ? AppColors.tertiary
                              : isHigher
                                  ? AppColors.secondary
                                  : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ==========================================
              // FEATURE 2: GRABADOR INTERACTIVO DE NOTA DE VOZ (MÁX 15S)
              // ==========================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isRecording
                        ? Colors.red
                        : _hasVoiceNote
                            ? AppColors.workerAccent
                            : const Color(0x1F173B4D),
                    width: _isRecording || _hasVoiceNote ? 1.8 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A173B4D),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _isRecording
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : AppColors.workerAccent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isRecording ? Icons.fiber_manual_record : Icons.mic_rounded,
                                color: _isRecording ? Colors.red : AppColors.workerAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nota de Voz Rápida (máx. 15s)',
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral,
                              ),
                            ),
                          ],
                        ),
                        if (_hasVoiceNote)
                          GestureDetector(
                            onTap: _deleteVoiceNote,
                            child: const Text(
                              'Borrar',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explica tu diagnóstico y herramientas al cliente sin escribir textos largos.',
                      style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),

                    if (!_hasVoiceNote && !_isRecording) ...[
                      // Button to start recording
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.workerAccent, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: AppColors.workerAccent,
                          ),
                          onPressed: _startRecording,
                          icon: const Icon(Icons.mic, size: 20),
                          label: const Text(
                            'Pulsar para Grabar Audio (15s)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ] else if (_isRecording) ...[
                      // Active recording state with wave animation
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Blinking dot
                            AnimatedBuilder(
                              animation: _waveAnimController,
                              builder: (context, _) {
                                return Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.4 + (_waveAnimController.value * 0.6)),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '00:${_voiceSeconds.toString().padLeft(2, "0")} / 00:15',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Simulated audio waves
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _waveAnimController,
                                builder: (context, _) {
                                  return LayoutBuilder(
                                    builder: (context, waveConstraints) {
                                      final count = (waveConstraints.maxWidth / 6.5).floor().clamp(4, 14);
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: List.generate(count, (i) {
                                          final factor = ((i * 7) % 10) / 10.0;
                                          final height = 8.0 + (22.0 * (_waveAnimController.value * factor));
                                          return Container(
                                            width: 3.0,
                                            height: height,
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          );
                                        }),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _stopRecording,
                              child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Recorded state with audio waveform player
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.workerAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.workerAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    _isPlayingVoice ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: AppColors.workerAccent,
                                    size: 36,
                                  ),
                                  onPressed: _togglePlayback,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _isPlayingVoice ? 'Reproduciendo audio...' : 'Nota de voz lista',
                                            style: AppTypography.labelSm.copyWith(
                                              color: AppColors.workerAccent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            '0:${_playbackProgress.toString().padLeft(2, "0")} / 0:${_voiceSeconds.toString().padLeft(2, "0")}',
                                            style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Waveform bars
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: List.generate(20, (i) {
                                          final isPassed = _playbackProgress > 0 &&
                                              (i / 20.0) <= (_playbackProgress / _voiceSeconds);
                                          final barHeight = 6.0 + ((i * 11) % 18);
                                          return Container(
                                            width: 4,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              color: isPassed
                                                  ? AppColors.workerAccent
                                                  : AppColors.workerAccent.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.short_text_rounded, size: 14, color: AppColors.muted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '"Hola vecino, tengo los repuestos listos en la moto y lo pruebo en 25 min..."',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.neutral,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Inclusion Chips (¿Qué incluye tu propuesta?)
              Text(
                '¿Qué incluye tu propuesta?',
                style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona las condiciones para dar mayor claridad al cliente:',
                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableInclusions.map((chipLabel) {
                  final isSelected = _selectedInclusions.contains(chipLabel);
                  return FilterChip(
                    selected: isSelected,
                    label: Text(chipLabel),
                    labelStyle: AppTypography.labelSm.copyWith(
                      color: isSelected ? Colors.white : AppColors.neutral,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    backgroundColor: AppColors.card,
                    selectedColor: AppColors.primary,
                    showCheckmark: isSelected,
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedInclusions.add(chipLabel);
                        } else {
                          _selectedInclusions.remove(chipLabel);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // ETA Arrival chips
              Text(
                'Tiempo estimado de llegada (en moto/transporte)',
                style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 10),
              Row(
                children: _etaOptions.map((eta) {
                  final isSelected = _selectedEtaMinutes == eta;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _selectedEtaMinutes = eta),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0x1F202D33),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$eta',
                                style: AppTypography.labelLg.copyWith(
                                  color: isSelected ? Colors.white : AppColors.neutral,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'min',
                                style: AppTypography.labelSm.copyWith(
                                  color: isSelected ? Colors.white70 : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Message input
              Text(
                'Mensaje personalizado para el cliente (opcional)',
                style: AppTypography.labelLg.copyWith(color: AppColors.neutral),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ej. Cuento con repuestos en moto, puedo ir de inmediato...',
                ),
              ),
              const SizedBox(height: 10),

              // Quick notes chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickNotes.map((note) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        backgroundColor: AppColors.card,
                        label: Text(note),
                        labelStyle: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        onPressed: () {
                          setState(() {
                            _messageController.text = note;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 26),

              // Submit CTA Button
              ChambaButton(
                label: _isSubmitting
                    ? 'Enviando propuesta...'
                    : 'Enviar Propuesta S/. ${_proposedAmount.toStringAsFixed(0)} ${_hasVoiceNote ? "🎙️" : ""}',
                leadingIcon: Icons.send_rounded,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submitBid,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
