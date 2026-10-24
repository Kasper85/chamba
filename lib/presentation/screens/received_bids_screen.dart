import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../core/widgets/price_dial_stepper.dart';
import '../../data/models/job_request.dart';
import '../../data/models/bid.dart';
import '../state/app_state.dart';
import 'worker_profile_detail_screen.dart';
import 'chat_screen.dart';
import 'job_tracking_screen.dart';

enum BidFilter {
  all,
  bestRated,
  fastest,
  lowestPrice,
}

class ReceivedBidsScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const ReceivedBidsScreen({
    super.key,
    required this.appState,
    required this.job,
  });

  @override
  State<ReceivedBidsScreen> createState() => _ReceivedBidsScreenState();
}

class _ReceivedBidsScreenState extends State<ReceivedBidsScreen> {
  late JobRequest _currentJob;
  BidFilter _selectedFilter = BidFilter.all;

  // Voice Note Playback state
  String? _currentlyPlayingBidId;
  int _playbackSecond = 0;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    widget.appState.addListener(_onStateUpdate);
    widget.appState.joinJobRoom(_currentJob.id);
  }

  void _onStateUpdate() {
    if (mounted) {
      final updated = widget.appState.jobs.firstWhere(
        (j) => j.id == widget.job.id,
        orElse: () => _currentJob,
      );
      setState(() => _currentJob = updated);
    }
  }

  @override
  void dispose() {
    widget.appState.leaveJobRoom(_currentJob.id);
    _playbackTimer?.cancel();
    widget.appState.removeListener(_onStateUpdate);
    super.dispose();
  }

  void _toggleVoicePlayback(Bid bid) {
    if (_currentlyPlayingBidId == bid.id) {
      _playbackTimer?.cancel();
      setState(() {
        _currentlyPlayingBidId = null;
        _playbackSecond = 0;
      });
    } else {
      _playbackTimer?.cancel();
      setState(() {
        _currentlyPlayingBidId = bid.id;
        _playbackSecond = 0;
      });

      final totalDuration = bid.voiceDurationSeconds > 0 ? bid.voiceDurationSeconds : 10;
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_playbackSecond >= totalDuration) {
          timer.cancel();
          setState(() {
            _currentlyPlayingBidId = null;
            _playbackSecond = 0;
          });
        } else {
          setState(() => _playbackSecond++);
        }
      });
    }
  }

  List<Bid> _getSortedBids(List<Bid> bids) {
    final list = List<Bid>.from(bids);
    switch (_selectedFilter) {
      case BidFilter.bestRated:
        list.sort((a, b) => b.workerRating.compareTo(a.workerRating));
        break;
      case BidFilter.fastest:
        list.sort((a, b) => a.etaMinutes.compareTo(b.etaMinutes));
        break;
      case BidFilter.lowestPrice:
        list.sort((a, b) => (a.counterAmount ?? a.amount).compareTo(b.counterAmount ?? b.amount));
        break;
      case BidFilter.all:
        break;
    }
    return list;
  }

  void _showCounterOfferModal(Bid bid) {
    double counterValue = widget.job.budget;

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
                color: AppColors.canvas,
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
                          color: AppColors.muted.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Contraofertar a ${bid.workerName}',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'El técnico ofertó S/. ${bid.amount.toStringAsFixed(0)}. Ingresa tu propuesta final:',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    PriceDialStepper(
                      currentPrice: counterValue,
                      recommendedPrice: widget.job.budget,
                      minPrice: 15.0,
                      maxPrice: 1500.0,
                      label: 'Tu Contraoferta en Soles',
                      onPriceChanged: (val) {
                        setModalState(() => counterValue = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    ChambaButton(
                      label: 'Enviar Contraoferta S/. ${counterValue.toStringAsFixed(0)}',
                      onPressed: () {
                        widget.appState.counterBid(
                          jobId: _currentJob.id,
                          bidId: bid.id,
                          counterAmount: counterValue,
                        );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Contraoferta de S/. ${counterValue.toStringAsFixed(0)} enviada a ${bid.workerName}',
                            ),
                            backgroundColor: AppColors.secondary,
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

  @override
  Widget build(BuildContext context) {
    final rawBids = _currentJob.bids;
    final sortedBids = _getSortedBids(rawBids);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Ofertas Recibidas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    appState: widget.appState,
                    job: _currentJob,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Request Card
              ChambaCard(
                color: _currentJob.isSos ? const Color(0xFFFFF7F5) : AppColors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentJob.isSos)
                          const ChambaBadge.sos(label: 'URGENCIA SOS')
                        else
                          ChambaBadge.negotiating(label: _currentJob.status.displayLabel),
                        Text(
                          'S/. ${_currentJob.budget.toStringAsFixed(0)}',
                          style: AppTypography.numericBid.copyWith(
                            color: _currentJob.isSos ? AppColors.sosRed : Colors.white,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currentJob.title,
                      style: AppTypography.headlineSm.copyWith(
                        color: _currentJob.isSos ? AppColors.sosRedDark : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentJob.district} • ${_currentJob.address}',
                      style: AppTypography.labelSm.copyWith(
                        color: _currentJob.isSos ? AppColors.sosRed : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Indicador de conexión en tiempo real y etiqueta honesta
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.appState.isSocketConnected
                          ? const Color(0xFFD1FAE5)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: widget.appState.isSocketConnected
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: widget.appState.isSocketConnected
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.appState.isSocketConnected
                              ? 'Ofertas en vivo conectadas'
                              : 'Sin conexión en vivo',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: widget.appState.isSocketConnected
                                ? const Color(0xFF047857)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x1F202D33)),
                    ),
                    child: Text(
                      'Trabajo DEMO · ofertas en vivo',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // FEATURE 2: Quick Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Todos (${rawBids.length})', BidFilter.all),
                    _buildFilterChip('⭐ Mejor calificados', BidFilter.bestRated),
                    _buildFilterChip('⚡ Más rápidos', BidFilter.fastest),
                    _buildFilterChip('💰 Precio más bajo', BidFilter.lowestPrice),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Técnicos postulados (${sortedBids.length})',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Compara precios, tiempo de llegada y escucha sus notas de voz explicativas.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 16),

              if (sortedBids.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x14202D33)),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.secondary),
                      const SizedBox(height: 18),
                      Text(
                        'Esperando ofertas de técnicos...',
                        style: AppTypography.bodyLgMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Los especialistas en tu zona han sido notificados. Recibirás propuestas con audio en breve.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ...sortedBids.map((bid) => _buildBidCard(bid)),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, BidFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.neutral,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        showCheckmark: false,
        onSelected: (val) {
          if (val) setState(() => _selectedFilter = filter);
        },
      ),
    );
  }

  Widget _buildBidCard(Bid bid) {
    final worker = widget.appState.workers.firstWhere(
      (w) => w.id == bid.workerId,
      orElse: () => widget.appState.workers.first,
    );
    final hasCounter = bid.counterAmount != null;
    final isPlaying = _currentlyPlayingBidId == bid.id;
    final totalVoiceDuration = bid.voiceDurationSeconds > 0 ? bid.voiceDurationSeconds : 12;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ChambaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Worker header row
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkerProfileDetailScreen(worker: worker),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      bid.workerAvatar,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bid.workerName,
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral,
                              ),
                            ),
                          ),
                          if (bid.isWorkerVerified)
                            const ChambaBadge.verified(label: 'DNI Verificado'),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${bid.workerRating}',
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral,
                            ),
                          ),
                          Text(
                            ' (${bid.workerCompletedJobs} chambas)',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            'Llega en ${bid.etaMinutes} min',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // FEATURE 2: COMPACT VOICE NOTE PLAYER (If bid has audio)
            if (bid.hasVoiceNote) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _toggleVoicePlayback(bid),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.mic, size: 13, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Nota de Voz del Técnico',
                                        style: AppTypography.labelSm.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF15803D),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isPlaying
                                        ? '0:${_playbackSecond.toString().padLeft(2, "0")} / 0:${totalVoiceDuration.toString().padLeft(2, "0")}'
                                        : '0:${totalVoiceDuration.toString().padLeft(2, "0")}',
                                    style: AppTypography.labelSm.copyWith(
                                      color: const Color(0xFF15803D),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Waveform visualization
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(24, (i) {
                                  final isPassed = isPlaying &&
                                      (i / 24.0) <= (_playbackSecond / totalVoiceDuration);
                                  final barHeight = 4.0 + ((i * 7) % 14);
                                  return Container(
                                    width: 3.5,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: isPassed
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF86EFAC),
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
                    if (bid.voiceTranscriptPreview != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '"${bid.voiceTranscriptPreview}"',
                        style: AppTypography.labelSm.copyWith(
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF166534),
                          fontSize: 11.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (bid.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x0F202D33)),
                ),
                child: Text(
                  '"${bid.message}"',
                  style: AppTypography.bodyMd.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.neutral,
                  ),
                ),
              ),
            ],

            // FEATURE 2: Offer Inclusions Tags
            if (bid.inclusionTags.isNotEmpty || bid.includesMaterials) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (bid.includesMaterials && !bid.inclusionTags.contains('Incluye materiales'))
                    _buildInclusionPill('✓ Incluye materiales', const Color(0xFF047857), const Color(0xFFD1FAE5)),
                  ...bid.inclusionTags.map((tag) {
                    final isMaterial = tag.contains('materiales');
                    final isSpeed = tag.contains('25 min') || tag.contains('rápid');
                    final isFree = tag.contains('gratis');
                    final textColor = isMaterial
                        ? const Color(0xFF047857)
                        : (isSpeed
                            ? const Color(0xFFB45309)
                            : (isFree ? const Color(0xFF1E40AF) : AppColors.primary));
                    final bgColor = isMaterial
                        ? const Color(0xFFD1FAE5)
                        : (isSpeed
                            ? const Color(0xFFFEF3C7)
                            : (isFree ? const Color(0xFFDBEAFE) : AppColors.surfaceContainer));
                    return _buildInclusionPill(tag, textColor, bgColor);
                  }),
                ],
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0x14202D33)),
            const SizedBox(height: 12),

            // Price negotiation comparison
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCounter ? 'Tu contraoferta' : 'Oferta del técnico',
                      style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'S/. ',
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          hasCounter
                              ? bid.counterAmount!.toStringAsFixed(0)
                              : bid.amount.toStringAsFixed(0),
                          style: AppTypography.numericBid.copyWith(
                            color: AppColors.secondary,
                            fontSize: 26,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: const Text('Ver Perfil'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkerProfileDetailScreen(worker: worker),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Dual action buttons: Aceptar / Contraofertar
            LayoutBuilder(
              builder: (context, actionConstraints) {
                final isNarrow = actionConstraints.maxWidth < 280;
                final acceptButton = ChambaButton(
                  label: 'Aceptar S/. ${(bid.counterAmount ?? bid.amount).toStringAsFixed(0)}',
                  leadingIcon: Icons.check,
                  onPressed: () async {
                    final agreedAmount = bid.counterAmount ?? bid.amount;
                    try {
                      await widget.appState.holdEscrowFunds(
                        jobId: _currentJob.id,
                        amount: agreedAmount,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.error),
                              SizedBox(width: 8),
                              Text('Saldo insuficiente'),
                            ],
                          ),
                          content: Text(
                            'No cuentas con saldo suficiente en tu billetera CHAMBA para retener los S/. ${agreedAmount.toStringAsFixed(0)} de garantía en custodia.\n\nPor favor recarga saldo antes de confirmar el servicio.',
                            style: AppTypography.bodyMd,
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

                    if (!context.mounted) return;
                    widget.appState.acceptBid(
                      jobId: _currentJob.id,
                      bidId: bid.id,
                    );
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => JobTrackingScreen(
                          appState: widget.appState,
                          job: widget.appState.activeJob!,
                        ),
                      ),
                    );
                  },
                );
                final counterButton = ChambaButton.secondary(
                  label: 'Contraofertar',
                  leadingIcon: Icons.sync_alt,
                  onPressed: () => _showCounterOfferModal(bid),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      acceptButton,
                      const SizedBox(height: 8),
                      counterButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: acceptButton,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: counterButton,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInclusionPill(String label, Color textColor, Color bgColor) {
    final displayLabel = label.startsWith('✓') ? label : '✓ $label';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
