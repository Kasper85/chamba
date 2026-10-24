import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../core/widgets/role_switcher_pill.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import 'send_bid_screen.dart';
import 'worker_my_jobs_screen.dart';
import 'create_worker_profile_screen.dart';
import 'chat_screen.dart';

class AvailableJobsScreen extends StatefulWidget {
  final AppState? appState;
  final bool showBottomNav;

  const AvailableJobsScreen({
    super.key,
    this.appState,
    this.showBottomNav = false,
  });

  @override
  State<AvailableJobsScreen> createState() => _AvailableJobsScreenState();
}

class _AvailableJobsScreenState extends State<AvailableJobsScreen> {
  late AppState _appState;
  int _selectedIndex = 0;
  String _selectedFilter = 'Todos';
  bool _isAvailable = true;

  final List<String> _filters = [
    'Todos',
    '🚨 Solo SOS',
    'Gasfitería',
    'Electricidad',
    'Cerrajería',
    'Pintura',
    '< 3 km',
  ];

  @override
  void initState() {
    super.initState();
    _appState = widget.appState ?? AppState();
    _appState.addListener(_onStateUpdate);
  }

  void _onStateUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allJobs = List<JobRequest>.from(_appState.availableWorkerJobs);
    // Pin SOS jobs at the top, then sort by date
    allJobs.sort((a, b) {
      if (a.isSos && !b.isSos) return -1;
      if (!a.isSos && b.isSos) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    final filteredJobs = allJobs.where((j) {
      if (_selectedFilter == 'Todos') return true;
      if (_selectedFilter == '🚨 Solo SOS') return j.isSos;
      if (_selectedFilter == '< 3 km') return j.distanceKm <= 3.0;
      return j.categoryName.toLowerCase().contains(_selectedFilter.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chambas Disponibles',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isAvailable ? AppColors.tertiary : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _isAvailable ? 'Disponible para recibir ofertas' : 'No disponible',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      color: _isAvailable ? AppColors.tertiary : AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.primary),
            tooltip: 'Mi Perfil de Técnico',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateWorkerProfileScreen(appState: _appState),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: RoleSwitcherPill(appState: _appState, compact: true),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: AppColors.secondary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top worker metrics banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _appState.currentWorkerProfile.name,
                              style: AppTypography.bodyLgMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Radio: ${_appState.currentWorkerProfile.serviceRadiusKm} km • ${_appState.currentWorkerProfile.rating} ⭐ (${_appState.currentWorkerProfile.completedJobs} chambas)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isAvailable,
                        activeThumbColor: AppColors.tertiary,
                        onChanged: (val) {
                          setState(() => _isAvailable = val);
                          if (val) {
                            _appState.syncWorkerLocation();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Category and distance filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.card,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.neutral,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 18),

                // Header counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${filteredJobs.length} Solicitudes cerca de ti',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.tune, size: 18, color: AppColors.muted),
                  ],
                ),

                const SizedBox(height: 14),

                if (filteredJobs.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x14202D33)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off, size: 48, color: AppColors.muted),
                        const SizedBox(height: 12),
                        Text(
                          'No hay solicitudes con ese filtro',
                          style: AppTypography.bodyLgMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prueba seleccionando "Todos" para ver los pedidos en Chiclayo.',
                          style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ...filteredJobs.map((job) => _buildAvailableJobCard(job)),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0F173B4D),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerMyJobsScreen(appState: _appState),
                ),
              );
            } else if (index == 2) {
              if (_appState.jobs.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      appState: _appState,
                      job: _appState.jobs.first,
                    ),
                  ),
                );
              }
            } else if (index == 3) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateWorkerProfileScreen(appState: _appState),
                ),
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.secondary,
          unselectedItemColor: AppColors.muted,
          selectedLabelStyle: AppTypography.labelSm.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTypography.labelSm,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.handyman_outlined),
              activeIcon: Icon(Icons.handyman),
              label: 'Chambas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_history_outlined),
              activeIcon: Icon(Icons.work_history),
              label: 'Mis Trabajos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Mensajes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Mi Perfil',
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _buildAvailableJobCard(JobRequest job) {
    final isSos = job.isSos;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: isSos
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.sosRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sosRed.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: ChambaCard(
          color: isSos ? const Color(0xFFFFF7F5) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSos) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.sosRedLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emergency_rounded, size: 16, color: AppColors.sosRed),
                          const SizedBox(width: 6),
                          Text(
                            'URGENTE • < 30 MIN',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.sosRedDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.sosAmber),
                          const SizedBox(width: 4),
                          Text(
                            job.sosExpiresAt != null
                                ? '${job.sosExpiresAt!.difference(DateTime.now()).inMinutes.clamp(1, 30)} min restantes'
                                : '24 min restantes',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.sosRedDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSos ? AppColors.sosRedLight : AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          job.categoryName.toUpperCase(),
                          style: AppTypography.labelSm.copyWith(
                            color: isSos ? AppColors.sosRed : AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'A ${job.distanceKm} km',
                        style: AppTypography.labelSm.copyWith(
                          color: isSos ? AppColors.sosRed : AppColors.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  isSos
                      ? const ChambaBadge.sos(label: '🚨 Tarifa 1.35x')
                      : ChambaBadge(
                          label: job.urgency,
                          type: job.urgency.contains('Urgente')
                              ? ChambaBadgeType.counterReceived
                              : ChambaBadgeType.neutral,
                        ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.title,
                style: AppTypography.headlineSm.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isSos ? AppColors.sosRedDark : AppColors.neutral,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.muted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${job.district} (${job.address})',
                      style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0x14202D33)),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, cardConstraints) {
                  final isCompact = cardConstraints.maxWidth < 360;
                  final budgetColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSos ? 'Tarifa Dinámica SOS' : 'Presupuesto del Cliente',
                        style: AppTypography.labelSm.copyWith(
                          color: isSos ? AppColors.sosRed : AppColors.muted,
                          fontWeight: isSos ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'S/. ',
                            style: AppTypography.labelLg.copyWith(
                              color: isSos ? AppColors.sosRed : AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            job.budget.toStringAsFixed(0),
                            style: AppTypography.numericBid.copyWith(
                              color: isSos ? AppColors.sosRed : AppColors.secondary,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  final actionBtn = ChambaButton(
                    width: isCompact ? double.infinity : 170,
                    height: 46,
                    label: isSos ? 'Atender SOS Ya' : 'Enviar Oferta',
                    leadingIcon: isSos ? Icons.flash_on : Icons.send,
                    backgroundColor: isSos ? AppColors.sosRed : null,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SendBidScreen(
                            appState: _appState,
                            job: job,
                          ),
                        ),
                      );
                    },
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        budgetColumn,
                        const SizedBox(height: 12),
                        actionBtn,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: budgetColumn),
                      const SizedBox(width: 8),
                      actionBtn,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

