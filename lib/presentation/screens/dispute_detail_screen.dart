import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../data/models/job_request.dart';
import '../../data/services/disputes_api_service.dart';
import '../state/app_state.dart';

/// Pantalla de seguimiento y mediación de Disputas (ALCANCE.md §5, §8 L7, L13)
/// Cumple la regla dura: "La IA en disputas solo recomienda; nunca mueve dinero sola".
class DisputeDetailScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;
  final String? initialReason;

  const DisputeDetailScreen({
    super.key,
    required this.appState,
    required this.job,
    this.initialReason,
  });

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  late JobRequest _job;
  bool _hasAppealed = false;
  bool _isResolved = false;
  bool _isLoading = false;
  DisputeDetailData? _disputeData;
  final _statementController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _isResolved = _job.status == JobStatus.completed;
    _loadDisputeData();
  }

  Future<void> _loadDisputeData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.appState.getDisputeForJob(_job.id);
      if (data != null && mounted) {
        setState(() {
          _disputeData = data;
          if (data.isResolved) {
            _isResolved = true;
            _job = _job.copyWith(status: JobStatus.completed);
          }
        });
      }
    } catch (_) {
      // Ignorar error de red y mantener estado local
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _statementController.dispose();
    super.dispose();
  }

  void _handleResolveBySupport() {
    final agreedPrice = _job.budget;
    final refund50 = agreedPrice * 0.5;
    final workerGross = agreedPrice * 0.5;
    final commission = workerGross * 0.08;
    final workerNet = workerGross - commission;
    const serviceFee = 2.0;
    final platformTotal = commission + serviceFee;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolución de Soporte (Soporte / Admin)'),
        content: Text(
          '¿Deseas aplicar la resolución oficial de soporte?\n\n'
          'Veredicto: Dividir fondos al 50% / 50% según recomendación técnica.\n\n'
          '• Devolución a cliente: S/ ${refund50.toStringAsFixed(2)}\n'
          '• Pago a técnico: S/ ${workerNet.toStringAsFixed(2)} (neto tras 8% de comisión)\n'
          '• Plataforma (comisión + tarifa): S/ ${platformTotal.toStringAsFixed(2)}\n\n'
          'Los fondos serán descongelados y liquidados en el libro mayor inmutable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tertiary),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final disputeId = _disputeData?.id.isNotEmpty == true ? _disputeData!.id : _job.id;
                final resolved = await widget.appState.resolveDispute(
                  disputeId: disputeId,
                  verdict: 'SPLIT',
                  workerSplitPercent: 50,
                  notes: 'División equitativa 50/50 ejecutada por operador de soporte oficial.',
                );
                if (mounted) {
                  setState(() {
                    if (resolved != null) {
                      _disputeData = resolved;
                    }
                    _isResolved = true;
                    _job = _job.copyWith(status: JobStatus.completed);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Disputa resuelta por soporte humano. Fondos liquidados en libro mayor.'),
                      backgroundColor: AppColors.tertiary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al resolver disputa: $e'),
                      backgroundColor: AppColors.sosRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirmar y Liquidar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleAppeal() {
    if (_hasAppealed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo se permite una única apelación por disputa (§5.6).'),
          backgroundColor: AppColors.sosRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Presentar Apelación Única'),
        content: const Text(
          'Solo se admite una sola apelación si cuentas con nueva evidencia fotográfica o documental que no haya sido presentada antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _hasAppealed = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Apelación enviada a revisión de soporte.'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            },
            child: const Text('Enviar Apelación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Mediación y Disputa',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ChambaBadge(
                label: _isResolved ? 'Resuelta' : 'En Disputa',
                type: _isResolved ? ChambaBadgeType.confirmed : ChambaBadgeType.counterReceived,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const LinearProgressIndicator(color: AppColors.secondary, minHeight: 2),

            // Banner de fondos congelados o resuelto
            if (_isResolved) _buildResolvedFundsBanner() else _buildFrozenFundsBanner(),
            const SizedBox(height: 18),

            // Resumen de la solicitud
            _buildJobSummaryCard(),
            const SizedBox(height: 18),

            // Tarjeta de Recomendación de la IA (Regla Dura: Recomienda, no decide)
            _buildAiRecommendationCard(),
            const SizedBox(height: 18),

            // Declaraciones de las partes
            _buildStatementsCard(),
            const SizedBox(height: 18),

            // Estado del ticket de soporte
            _buildSupportStatusCard(),
            const SizedBox(height: 24),

            // Botón de resolución de soporte (SOLO visible para usuarios con rol de soporte y si no está resuelta)
            if (widget.appState.isSupportUser && !_isResolved) ...[
              ChambaButton(
                label: 'Resolver Disputa (Operador de Soporte)',
                leadingIcon: Icons.admin_panel_settings_outlined,
                variant: ChambaButtonVariant.primary,
                onPressed: _handleResolveBySupport,
              ),
              const SizedBox(height: 12),
            ],

            // Botón de apelación si aplica
            if (_job.status == JobStatus.inDispute || _job.status == JobStatus.completed)
              ChambaButton(
                label: _hasAppealed ? 'Apelación en curso' : 'Presentar Apelación Única',
                leadingIcon: Icons.gavel_rounded,
                variant: ChambaButtonVariant.secondary,
                onPressed: _hasAppealed ? null : _handleAppeal,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrozenFundsBanner() {
    // Banner de fondos congelados
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.sosRed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock, color: AppColors.sosRed, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fondos Congelados en Custodia',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.sosRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Los S/ ${_job.budget.toStringAsFixed(2)} depositados no se liberarán ni transferirán hasta que el equipo de soporte resuelva este caso.',
                  style: AppTypography.labelSm.copyWith(color: AppColors.neutral, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSummaryCard() {
    return ChambaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _job.title,
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(_job.district, style: AppTypography.labelSm.copyWith(color: AppColors.muted)),
              const Spacer(),
              Text(
                'Monto: S/ ${_job.budget.toStringAsFixed(2)}',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiRecommendationCard() {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recomendación del Asistente IA',
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Asesoría • No vinculante',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Veredicto propuesto: Dividir fondos en proporción justa (50% / 50%)',
            style: AppTypography.bodyMdMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Motivo: Se constató inicio presencial con código PIN, pero la culminación presenta observaciones según las fotos reportadas.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'La IA en disputas solo recomienda; nunca mueve dinero sola. Soporte humano emite la decisión final.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementsCard() {
    final clientStmt = _disputeData?.clientStatement ??
        widget.initialReason ??
        'El trabajo presentó fallas tras la salida del técnico.';
    final workerStmt = _disputeData?.workerStatement ??
        'Trabajo concluido según cotización y probado en sitio antes de retiro.';

    return ChambaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Declaraciones de las Partes (Plazo: 24 h)',
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatementBubble(
            title: 'Cliente (${_job.clientName})',
            statement: clientStmt,
            icon: Icons.person_outline,
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          _buildStatementBubble(
            title: 'Técnico (${_job.workerName ?? "Especialista"})',
            statement: workerStmt,
            icon: Icons.handyman_outlined,
            color: AppColors.workerAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatementBubble({
    required String title,
    required String statement,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1F202D33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(statement, style: AppTypography.bodyMd.copyWith(fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildSupportStatusCard() {
    final resolverDisplay = _disputeData?.resolvedBy?.fullName ??
        _disputeData?.resolvedBy?.email ??
        'Operador de Soporte Oficial';

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
              Icon(_isResolved ? Icons.verified_user : Icons.support_agent, size: 22, color: _isResolved ? AppColors.tertiary : AppColors.primary),
              const SizedBox(width: 8),
              Text(
                _isResolved ? 'Ticket de Soporte Resuelto' : 'Ticket de Soporte en Proceso',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.neutral,
                ),
              ),
              const Spacer(),
              ChambaBadge(
                label: _isResolved ? 'Cerrado' : 'En Proceso',
                type: _isResolved ? ChambaBadgeType.confirmed : ChambaBadgeType.inProgress,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isResolved
                ? 'El personal de soporte ($resolverDisplay) revisó las pruebas y aplicó la resolución en el libro mayor. Caso cerrado definitivamente.'
                : 'Soporte humano está analizando las fotos del antes/después, validación de PIN presencial y chat. Meta de resolución: 48 horas.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedFundsBanner() {
    final settlement = _disputeData?.settlement;
    final audit = _disputeData?.audit;
    final resolver = _disputeData?.resolvedBy;
    final agreedPrice = _job.budget;

    final totalCustody = audit?.totalCustody ?? settlement?.totalCustody ?? (agreedPrice + 2.0);
    final refundClient = audit?.refundClient ?? settlement?.refundClient ?? (agreedPrice * 0.5);
    final amountToWorker = audit?.amountToWorker ?? settlement?.amountToWorker ?? (agreedPrice * 0.5 * 0.92);
    final commission = audit?.commission ?? settlement?.commission ?? (agreedPrice * 0.5 * 0.08);
    final serviceFee = audit?.serviceFee ?? settlement?.serviceFee ?? 2.0;

    final formula = (audit?.invariantFormula.isNotEmpty ?? false)
        ? audit!.invariantFormula
        : '${totalCustody.toStringAsFixed(0)} = ${refundClient.toStringAsFixed(0)} + ${amountToWorker.toStringAsFixed(0)} + ${commission.toStringAsFixed(0)} + ${serviceFee.toStringAsFixed(0)}';

    final resolverDisplay = resolver?.fullName ?? resolver?.email ?? 'Operador de Soporte Oficial';
    final verdictLabel = settlement?.verdict == 'REFUND_CLIENT'
        ? 'Reembolso 100% al Cliente'
        : settlement?.verdict == 'RELEASE_WORKER'
            ? 'Liberación 100% al Especialista'
            : 'División 50% / 50%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.tertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.tertiary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, color: AppColors.tertiary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disputa Resuelta por Soporte Humano',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Operador: $resolverDisplay • Veredicto: $verdictLabel',
                      style: AppTypography.labelSm.copyWith(color: AppColors.neutral, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Liquidación Contable del Escrow (Invariante estricto):',
            style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          _buildReceiptRow('Depósito total en custodia:', 'S/ ${totalCustody.toStringAsFixed(2)}', isBold: true),
          _buildReceiptRow('• Reembolso a cliente:', 'S/ ${refundClient.toStringAsFixed(2)}', textColor: AppColors.primary),
          _buildReceiptRow('• Pago al especialista:', 'S/ ${amountToWorker.toStringAsFixed(2)}', textColor: AppColors.workerAccent),
          _buildReceiptRow('• Comisión plataforma (8%):', 'S/ ${commission.toStringAsFixed(2)}'),
          _buildReceiptRow('• Tarifa fija CHAMBA:', 'S/ ${serviceFee.toStringAsFixed(2)}'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Invariante: $formula', style: AppTypography.labelSm.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w800)),
              Text('Fondos liquidados', style: AppTypography.labelSm.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd.copyWith(fontSize: 12, fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
          Text(
            value,
            style: AppTypography.bodyMd.copyWith(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: textColor ?? AppColors.neutral,
            ),
          ),
        ],
      ),
    );
  }
}
