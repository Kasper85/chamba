import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_button.dart';
import '../../data/models/wallet_summary.dart';
import '../state/app_state.dart';

class WorkerWalletScreen extends StatefulWidget {
  final AppState appState;

  const WorkerWalletScreen({
    super.key,
    required this.appState,
  });

  @override
  State<WorkerWalletScreen> createState() => _WorkerWalletScreenState();
}

class _WorkerWalletScreenState extends State<WorkerWalletScreen> {
  int? _hoveredDayIndex;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.appState.fetchWallet();
      }
    });
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateChange);
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      return 'Hoy, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 2) {
      return 'Ayer, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  final List<Map<String, dynamic>> _weeklyData = const [
    {'day': 'Lun', 'amount': 80.0},
    {'day': 'Mar', 'amount': 110.0},
    {'day': 'Mié', 'amount': 65.0},
    {'day': 'Jue', 'amount': 95.0},
    {'day': 'Vie', 'amount': 140.0},
    {'day': 'Sáb', 'amount': 190.0, 'isBest': true},
    {'day': 'Dom', 'amount': 20.0},
  ];

  final List<Map<String, dynamic>> _movementHistory = const [
    {
      'title': 'Liberación de Escrow — Gasfitería',
      'subtitle': 'Trabajo completado • Ana García',
      'date': 'Hoy, 11:30 AM',
      'amount': 190.0,
      'isIncome': true,
      'status': 'Completado',
      'icon': Icons.check_circle_outline,
    },
    {
      'title': 'Liberación de Escrow — Tablero Eléctrico',
      'subtitle': 'Trabajo completado • Carlos R.',
      'date': 'Ayer, 4:15 PM',
      'amount': 140.0,
      'isIncome': true,
      'status': 'Completado',
      'icon': Icons.check_circle_outline,
    },
    {
      'title': 'Retención en Custodia (Escrow)',
      'subtitle': 'Chamba SOS en camino • Santa Victoria',
      'date': 'Hace 2 días',
      'amount': 95.0,
      'isIncome': false,
      'status': 'En Escrow',
      'icon': Icons.lock_clock_outlined,
    },
    {
      'title': 'Bono por Puntualidad Chiclayo',
      'subtitle': 'Incentivo Plata Chambeador',
      'date': '12 Oct 2026',
      'amount': 30.0,
      'isIncome': true,
      'status': 'Acreditado',
      'icon': Icons.card_giftcard,
    },
  ];

  void _showDemoWithdrawModal() {
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
                    width: 44,
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
                        color: AppColors.workerAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.workerAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Retiro de Fondos',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: const Text(
                                  'DEMO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Simulador de pasarela de pago para el Taller',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Aviso: En esta fase de prototipo, los fondos son demostrativos. No se debitan ni transfieren cuentas bancarias reales.',
                          style: AppTypography.labelSm.copyWith(
                            color: const Color(0xFF991B1B),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Disponible demostrativo:', style: AppTypography.labelSm.copyWith(color: AppColors.muted)),
                          const SizedBox(height: 2),
                          Text(
                            'S/. 480.00',
                            style: AppTypography.numericBidLarge.copyWith(
                              color: AppColors.primary,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.workerAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Sin comisión',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.workerAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Destino simulado:', style: AppTypography.labelLg.copyWith(color: AppColors.neutral)),
                const SizedBox(height: 8),
                _buildWithdrawOption('Yape BCP (Demo)', '+51 974 812 345 • Jorge Quispe B.', Icons.qr_code_2, true),
                _buildWithdrawOption('Plin Interbank (Demo)', '+51 974 812 345', Icons.phone_android, false),
                const SizedBox(height: 18),
                ChambaButton(
                  label: 'Simular Retiro de Prueba',
                  leadingIcon: Icons.bolt_rounded,
                  backgroundColor: AppColors.workerAccent,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚡ Simulación completada: Fondos de prueba retirados en modo DEMO.'),
                        backgroundColor: Color(0xFF0F766E),
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

  Widget _buildWithdrawOption(String title, String subtitle, IconData icon, bool isDefault) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDefault ? AppColors.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDefault ? AppColors.workerAccent : const Color(0x1F202D33),
          width: isDefault ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: isDefault ? AppColors.workerAccent : AppColors.muted, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyLgMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(subtitle, style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          if (isDefault)
            const Icon(Icons.check_circle, color: AppColors.workerAccent, size: 18),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.appState.walletSummary;
    final isReal = wallet != null && widget.appState.isAuthenticated;
    final availableBal = isReal ? wallet.availableBalance : 480.0;
    final escrowBal = isReal ? wallet.inEscrowBalance : 220.0;

    final weeklyItems = isReal
        ? wallet.calculateWeeklyEarnings()
        : _weeklyData.map((d) => DailyEarning(
              day: d['day'] as String,
              amount: d['amount'] as double,
              isBest: d['isBest'] as bool? ?? false,
            )).toList();

    final totalWeekly = isReal
        ? wallet.totalWeeklyEarnings
        : 700.0;

    final double maxAmount = weeklyItems.fold<double>(1.0, (m, e) => e.amount > m ? e.amount : m);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mi Billetera',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isReal ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isReal ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              isReal ? 'LEDGER' : 'DEMO',
              style: TextStyle(
                color: isReal ? const Color(0xFF15803D) : const Color(0xFFB45309),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => widget.appState.fetchWallet(),
        color: AppColors.workerAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isReal ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isReal ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isReal ? Icons.verified_outlined : Icons.shield_outlined,
                      color: isReal ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isReal
                            ? 'Billetera respaldada en tiempo real por el Libro Mayor inmutable (FinTech).'
                            : 'Entorno de Demostración: Los saldos y transacciones son simulados para fines académicos de la app móvil.',
                        style: AppTypography.labelSm.copyWith(
                          color: isReal ? const Color(0xFF166534) : const Color(0xFF92400E),
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Main Balances Card
              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Estado de Cuenta',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Semana Actual',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, boxConstraints) {
                        final isNarrow = boxConstraints.maxWidth < 280;

                        final disponibleBox = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Disponible',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelSm.copyWith(
                                        color: const Color(0xFF166534),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF16A34A)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S/. ${availableBal.toStringAsFixed(2)}',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF14532D),
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 32),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: _showDemoWithdrawModal,
                                    child: const Text(
                                      'Retirar (Demo)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        final escrowBox = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'En Custodia (Escrow)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelSm.copyWith(
                                        color: const Color(0xFF1E40AF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.lock_clock_rounded, size: 14, color: Color(0xFF2563EB)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S/. ${escrowBal.toStringAsFixed(2)}',
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E3A8A),
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                height: 32,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFDBEAFE)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isReal
                                      ? '${wallet.recentTransactions.where((t) => t.type == 'HOLD_ESCROW').length} retenciones activas'
                                      : '2 obras en proceso',
                                  style: AppTypography.labelSm.copyWith(
                                    color: const Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (isNarrow) {
                          return Column(
                            children: [
                              disponibleBox,
                              const SizedBox(height: 10),
                              escrowBox,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: disponibleBox),
                            const SizedBox(width: 10),
                            Expanded(child: escrowBox),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Weekly Earnings Bar Chart Card (Derivado de recentTransactions reales)
              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Ingresos Semanales: S/. ${totalWeekly.toStringAsFixed(2)}',
                          style: AppTypography.bodyLgMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AppColors.neutral,
                          ),
                        ),
                        if (_hoveredDayIndex != null && _hoveredDayIndex! < weeklyItems.length)
                          Text(
                            '${weeklyItems[_hoveredDayIndex!].day}: S/. ${weeklyItems[_hoveredDayIndex!].amount.toStringAsFixed(2)}',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.workerAccent,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          Text(
                            isReal ? 'Últimos 7 días (Ledger)' : 'Sábado top día ⭐',
                            style: AppTypography.labelSm.copyWith(color: AppColors.muted, fontSize: 11),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: LayoutBuilder(
                        builder: (context, chartConstraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: chartConstraints.maxWidth < 280
                                ? const AlwaysScrollableScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: chartConstraints.maxWidth),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(weeklyItems.length, (index) {
                                  final item = weeklyItems[index];
                                  final double amount = item.amount;
                                  final String day = item.day;
                                  final bool isBest = item.isBest;
                                  final barHeight = maxAmount > 0
                                      ? (amount / maxAmount) * 85.0
                                      : 4.0;

                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _hoveredDayIndex = index);
                                    },
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'S/.${amount.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
                                            color: isBest ? AppColors.secondary : AppColors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          width: 24,
                                          height: barHeight < 4.0 ? 4.0 : barHeight,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isBest
                                                  ? [AppColors.secondary, const Color(0xFFEA580C)]
                                                  : [AppColors.workerAccent, const Color(0xFF0F766E)],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                            boxShadow: isBest
                                                ? [
                                                    BoxShadow(
                                                      color: AppColors.secondary.withValues(alpha: 0.35),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, -2),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          day,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isBest ? FontWeight.w800 : FontWeight.w600,
                                            color: isBest ? AppColors.secondary : AppColors.neutral,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Gamification Level Chamba: Solo en modo DEMO (no inventar para usuarios reales)
              if (!isReal) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x20000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 20),
                          Text(
                            'Nivel Plata (DEMO)',
                            style: AppTypography.bodyLgMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '• Próximo: Maestro Chamba Oro',
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.amber,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: 142 / 150,
                          minHeight: 8,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '142 / 150 chambas (Faltan 8)',
                            style: AppTypography.labelSm.copyWith(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            '95% completado',
                            style: AppTypography.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // History of Movements (Real Ledger Entries o Mock Fallback)
              ChambaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Historial de Movimientos',
                          style: AppTypography.bodyLgMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          isReal ? 'Libro Mayor Inmutable' : 'Últimos 7 días',
                          style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isReal && wallet.recentTransactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.muted),
                              const SizedBox(height: 8),
                              Text(
                                'Aún sin movimientos registrados',
                                style: AppTypography.bodyLgMedium.copyWith(color: AppColors.muted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Las liberaciones de Escrow aparecerán aquí automáticamente.',
                                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (isReal)
                      ...wallet.recentTransactions.map((tx) {
                        final isIncome = tx.isIncome;
                        String title;
                        if (tx.type == 'RELEASE_ESCROW') {
                          title = 'Liberación de Escrow';
                        } else if (tx.type == 'HOLD_ESCROW') {
                          title = 'Retención en Custodia (Escrow)';
                        } else if (tx.type == 'DEPOSIT') {
                          title = 'Acreditación de Saldo';
                        } else {
                          title = 'Movimiento (${tx.type})';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFDBEAFE),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isIncome
                                      ? Icons.check_circle_outline
                                      : Icons.lock_clock_outlined,
                                  size: 16,
                                  color: isIncome
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelLg.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tx.description ?? "Operación de Ledger"} • ${_formatDate(tx.createdAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIncome ? "+" : ""}S/. ${tx.amount.abs().toStringAsFixed(2)}',
                                    style: AppTypography.bodyLgMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isIncome ? const Color(0xFF16A34A) : const Color(0xFF1E40AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    isIncome ? 'Acreditado' : 'En Custodia',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isIncome ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      })
                    else
                      ..._movementHistory.map((item) {
                        final isIncome = item['isIncome'] as bool;
                        final amount = item['amount'] as double;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFDBEAFE),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  size: 16,
                                  color: isIncome
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelLg.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item['subtitle']} • ${item['date']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isIncome ? "+" : ""}S/. ${amount.toStringAsFixed(2)}',
                                    style: AppTypography.bodyLgMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isIncome ? const Color(0xFF16A34A) : const Color(0xFF1E40AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    item['status'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: isIncome ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
