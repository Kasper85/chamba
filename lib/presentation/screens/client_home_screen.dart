import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../core/widgets/role_switcher_pill.dart';
import '../../data/models/category.dart';
import '../../data/models/job_request.dart';
import '../../data/models/worker_profile.dart';
import '../state/app_state.dart';
import '../widgets/chamba_interactive_map.dart';
import 'post_job_screen.dart';
import 'received_bids_screen.dart';
import 'job_tracking_screen.dart';
import 'role_selection_screen.dart';
import 'worker_profile_detail_screen.dart';
import 'chat_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  final AppState? appState;
  final bool showBottomNav;

  const ClientHomeScreen({
    super.key,
    this.appState,
    this.showBottomNav = false,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
  with SingleTickerProviderStateMixin {
  late AppState _appState;
  late AnimationController _radarController;
  int _selectedIndex = 0;
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    _appState = widget.appState ?? AppState();
    _appState.addListener(_onStateChange);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Consultar automáticamente los técnicos cercanos con PostGIS al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectLocationAndFetchNearby();
    });
  }

  Future<void> _detectLocationAndFetchNearby() async {
    double lat = _appState.userLatitude;
    double lng = _appState.userLongitude;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      // Usar coordenadas por defecto en caso de emulador sin GPS o error
    }
    if (mounted) {
      await _appState.fetchNearbyWorkers(latitude: lat, longitude: lng);
    }
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChange);
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeJobs = _appState.jobs;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _detectLocationAndFetchNearby,
          color: AppColors.secondary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: Greeting, Location & Mode Switcher
                LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final isCompactHeader = headerConstraints.maxWidth < 360;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, ${_appState.clientName.split(" ").first} 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.headlineSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      _appState.clientDistrict,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelMd.copyWith(
                                        color: AppColors.neutral,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: AppColors.muted,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoleSwitcherPill(
                          appState: _appState,
                          compact: isCompactHeader,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 18),

                // FEATURE 2: Chamba SOS Emergency Radar Section (< 30 min)
                _buildChambaSosSection(),

                const SizedBox(height: 18),

                // Hero CTA Banner: Publicar Chamba Standard
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF284B5D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A173B4D),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TIPO INDRIVE',
                              style: AppTypography.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Publica una Chamba y fija tu precio en S/.',
                        style: AppTypography.headlineSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Los especialistas cercanos verán tu pedido y te enviarán sus ofertas o contraofertas.',
                        style: AppTypography.bodyMd.copyWith(
                          color: Colors.white70,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ChambaButton(
                        label: 'Publicar Solicitud Ahora',
                        leadingIcon: Icons.add_circle_outline,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostJobScreen(appState: _appState),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Section: Categorías Populares
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Categorías de Servicio',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '8 oficios',
                      style: AppTypography.labelMd.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildCategoriesGrid(),

                const SizedBox(height: 28),

                // Section: Tus Solicitudes Activas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Tus Solicitudes Activas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeJobs.length} en curso',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...activeJobs.map((job) => _buildActiveJobCard(job)),

                const SizedBox(height: 24),

                // Section: Especialistas Cercanos (PostGIS en tiempo real)
                _buildNearbyTechniciansSection(),
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
              if (_appState.jobs.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReceivedBidsScreen(
                      appState: _appState,
                      job: _appState.jobs.first,
                    ),
                  ),
                );
              }
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
                  builder: (_) => const RoleSelectionScreen(),
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
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Solicitudes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Mensajes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _buildCategoriesGrid() {
    final categories = JobCategory.defaultCategories;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final aspectRatio = isCompact ? 0.72 : 0.85;
        final iconBoxSize = isCompact ? 46.0 : 56.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: isCompact ? 8 : 10,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final cat = categories[index];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostJobScreen(
                      appState: _appState,
                      initialCategory: cat,
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x14202D33), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08173B4D),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      cat.icon,
                      size: isCompact ? 22 : 26,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutral,
                      fontSize: isCompact ? 10.5 : 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChambaSosSection() {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.sosRed.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Radar Pulse Ripple Animation
              Positioned(
                right: -20,
                top: -20,
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: SosRadarPainter(_radarController.value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.sosRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'CHAMBA SOS • < 30 MIN',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.sosRedDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Tarifa 1.35x',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '¿Emergencia en Casa?',
                      style: AppTypography.headlineSm.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fugas de agua, cortocircuitos o chapas atascadas. Técnicos de guardia en Chiclayo salen en moto de inmediato.',
                      style: AppTypography.bodyMd.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.sosRedDark,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, color: AppColors.sosRed, size: 20),
                        label: Text(
                          'Pedir Chamba SOS Ahora (< 30 min)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.sosRedDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostJobScreen(
                                appState: _appState,
                                isSosInitial: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveJobCard(JobRequest job) {
    final hasOffers = job.bids.isNotEmpty;
    final isOnTheWayOrActive = job.status == JobStatus.onTheWay || job.status == JobStatus.inProgress;
    final isSos = job.isSos;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Container(
        decoration: isSos
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.sosRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sosRed.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: ChambaCard(
          onTap: () {
            _appState.setActiveJob(job.id);
            if (isOnTheWayOrActive) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobTrackingScreen(appState: _appState, job: job),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReceivedBidsScreen(appState: _appState, job: job),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isSos) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sosRedLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '🚨 SOS PRIORIDAD',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.sosRed,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                job.categoryName.toUpperCase(),
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            Text(
                              '• ${job.district}',
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          job.title,
                          style: AppTypography.bodyLgMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSos ? AppColors.sosRedDark : AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/. ${job.budget.toStringAsFixed(0)}',
                        style: AppTypography.numericBid.copyWith(
                          color: isSos ? AppColors.sosRed : AppColors.secondary,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        isSos ? 'Tarifa SOS' : 'Presupuesto',
                        style: AppTypography.labelSm.copyWith(
                          color: isSos ? AppColors.sosRed : AppColors.muted,
                          fontWeight: isSos ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0x14202D33)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (hasOffers) ...[
                    ChambaBadge.counterReceived(
                      label: '${job.bids.length} Ofertas recibidas',
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Revisar ofertas',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.secondary),
                      ],
                    ),
                  ] else if (isOnTheWayOrActive) ...[
                    ChambaBadge.confirmed(label: job.status.displayLabel),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver seguimiento',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.tertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.tertiary),
                      ],
                    ),
                  ] else ...[
                    isSos
                        ? const ChambaBadge.sos(label: '🚨 Alerta SOS Enviada (<30 min)')
                        : const ChambaBadge.negotiating(label: 'Buscando especialistas...'),
                    Text(
                      'Ver detalles',
                      style: AppTypography.labelMd.copyWith(color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyTechniciansSection() {
    final nearbyWorkers = _appState.nearbyWorkers;
    final fallbackWorkers = _appState.workers;
    final isLoading = _appState.isLoadingNearbyWorkers;
    final error = _appState.nearbyWorkersError;
    final hasFetched = _appState.hasFetchedNearbyWorkers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Técnicos Cercanos en Chiclayo',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PostGIS en tiempo real • Radio ${_appState.nearbyRadiusKm.toInt()} km',
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: _showMap ? 'Ocultar mapa' : 'Mostrar mapa',
                  icon: Icon(
                    _showMap ? Icons.map : Icons.map_outlined,
                    color: _showMap ? AppColors.secondary : AppColors.muted,
                  ),
                  onPressed: () => setState(() => _showMap = !_showMap),
                ),
                IconButton(
                  tooltip: 'Actualizar GPS y técnicos',
                  icon: const Icon(Icons.my_location, color: AppColors.secondary),
                  onPressed: _detectLocationAndFetchNearby,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Radios chips: 5km, 10km, 15km, 30km
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [5.0, 10.0, 15.0, 30.0].map((radius) {
              final isSelected = _appState.nearbyRadiusKm == radius;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text('${radius.toInt()} km'),
                  selected: isSelected,
                  selectedColor: AppColors.secondary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.secondary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.secondary : AppColors.neutral,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _appState.fetchNearbyWorkers(radiusKm: radius);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Map section
        if (_showMap) ...[
          ChambaInteractiveMap(
            height: 210,
            initialCenter: LatLng(_appState.userLatitude, _appState.userLongitude),
            nearbyWorkers: nearbyWorkers,
            onWorkerTap: (worker) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerProfileDetailScreen(worker: worker),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
        ],

        // Loading state
        if (isLoading) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1F173B4D)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.secondary),
                ),
                SizedBox(width: 14),
                Text(
                  'Buscando especialistas con PostGIS...',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.neutral),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (error != null) ...[
          // Error state with retry
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sosRedLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: AppColors.sosRed, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'No se pudo conectar con el servidor',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.sosRedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Verifica que el backend esté encendido en http://localhost:3000.',
                  style: AppTypography.labelSm.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sosRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reintentar búsqueda'),
                  onPressed: _detectLocationAndFetchNearby,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (hasFetched && nearbyWorkers.isEmpty) ...[
          // Empty state
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1F173B4D)),
            ),
            child: Column(
              children: [
                const Icon(Icons.person_search_outlined, size: 44, color: AppColors.muted),
                const SizedBox(height: 10),
                Text(
                  'No hay técnicos disponibles en este radio',
                  style: AppTypography.headlineSm.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No encontramos especialistas dentro de ${_appState.nearbyRadiusKm.toInt()} km de tu ubicación.',
                  textAlign: TextAlign.center,
                  style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _appState.fetchNearbyWorkers(radiusKm: 30.0),
                  child: const Text('Ampliar radio a 30 km'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (nearbyWorkers.isNotEmpty) ...[
          // Real backend workers list (sorted by distance)
          ...nearbyWorkers.map((worker) => _buildWorkerCard(worker)),
        ] else ...[
          // Initial demo fallback
          ...fallbackWorkers.map((worker) => _buildWorkerCard(worker)),
        ],
      ],
    );
  }

  Widget _buildWorkerCard(dynamic worker) {
    final bool isReal = worker is WorkerProfile && worker.isRealBackendWorker;
    final double? distance = worker is WorkerProfile ? worker.distanceKm : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ChambaCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkerProfileDetailScreen(worker: worker),
            ),
          );
        },
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    worker.avatarInitials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    worker.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyLgMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.neutral,
                                    ),
                                  ),
                                ),
                                if (!isReal) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'DEMO',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.muted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (worker.isVerified)
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.tertiary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (worker.skills as List).take(2).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelMd.copyWith(color: AppColors.muted),
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${distance.toStringAsFixed(1)} km',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${worker.rating}',
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              ' (${worker.completedJobs} chambas)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isReal || worker.baseRate == 0.0
                                ? 'Tarifa a convenir'
                                : 'S/. ${worker.baseRate.toInt()}/h',
                            style: AppTypography.labelSm.copyWith(
                              color: isReal ? AppColors.secondary : AppColors.neutral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            if (!isReal &&
                (worker.isIdVerified == true ||
                    worker.hasCleanRecord == true ||
                    worker.offersWarranty == true)) ...[
              const SizedBox(height: 10),
              // Trust Shield Micro Row only for DEMO data
              TrustShieldBadgesRow(
                isIdVerified: worker.isIdVerified ?? true,
                hasCleanRecord: worker.hasCleanRecord ?? true,
                offersWarranty: worker.offersWarranty ?? true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Custom radar waves painter for Chamba SOS
class SosRadarPainter extends CustomPainter {
  final double animationValue;

  SosRadarPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final progress = (animationValue + (i / 3.0)) % 1.0;
      final radius = progress * maxRadius;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SosRadarPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

