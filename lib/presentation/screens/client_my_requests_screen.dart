import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import 'received_bids_screen.dart';
import 'job_tracking_screen.dart';
import 'post_job_screen.dart';

class ClientMyRequestsScreen extends StatefulWidget {
  final AppState appState;

  const ClientMyRequestsScreen({super.key, required this.appState});

  @override
  State<ClientMyRequestsScreen> createState() => _ClientMyRequestsScreenState();
}

class _ClientMyRequestsScreenState extends State<ClientMyRequestsScreen> {
  String _selectedFilter = 'Todas';

  final List<String> _filters = [
    'Todas',
    'Buscando',
    'Negociando',
    'En Curso',
    'Finalizadas',
  ];

  @override
  Widget build(BuildContext context) {
    final allJobs = widget.appState.clientJobs;
    final filteredJobs = allJobs.where((j) {
      if (_selectedFilter == 'Todas') return true;
      if (_selectedFilter == 'Buscando') return j.status == JobStatus.searching;
      if (_selectedFilter == 'Negociando') return j.status == JobStatus.negotiating;
      if (_selectedFilter == 'En Curso') {
        return j.status == JobStatus.onTheWay ||
            j.status == JobStatus.onSite ||
            j.status == JobStatus.inProgress ||
            j.status == JobStatus.forConfirmation;
      }
      if (_selectedFilter == 'Finalizadas') return j.status == JobStatus.completed;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mis Solicitudes',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 28),
            tooltip: 'Publicar nueva solicitud',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostJobScreen(appState: widget.appState),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter),
                      labelStyle: AppTypography.labelSm.copyWith(
                        color: isSelected ? Colors.white : AppColors.neutral,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      backgroundColor: AppColors.canvas,
                      selectedColor: AppColors.primary,
                      showCheckmark: false,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : const Color(0x1F202D33),
                        ),
                      ),
                      onSelected: (val) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x14202D33)),

          // Jobs List or Empty State
          Expanded(
            child: filteredJobs.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      return _buildJobCard(filteredJobs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes solicitudes en esta categoría',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publica un servicio del hogar y recibe ofertas directas de técnicos verificados en minutos.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            ChambaButton(
              label: 'Publicar una Chamba',
              leadingIcon: Icons.add,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostJobScreen(appState: widget.appState),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(JobRequest job) {
    final hasOffers = job.bids.isNotEmpty;
    final isOnTheWayOrActive = job.status == JobStatus.onTheWay ||
        job.status == JobStatus.onSite ||
        job.status == JobStatus.inProgress ||
        job.status == JobStatus.forConfirmation;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: ChambaCard(
        onTap: () {
          widget.appState.setActiveJob(job.id);
          if (isOnTheWayOrActive || job.status == JobStatus.completed) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => JobTrackingScreen(appState: widget.appState, job: job),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReceivedBidsScreen(appState: widget.appState, job: job),
              ),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.categoryName.toUpperCase(),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'S/. ${job.budget.toStringAsFixed(0)}',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.title,
              style: AppTypography.bodyLgMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${job.district} • ${job.address}',
                    style: AppTypography.labelSm.copyWith(color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                _buildStatusBadge(job),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isOnTheWayOrActive
                          ? 'Ver Seguimiento'
                          : hasOffers
                              ? 'Ver ${job.bids.length} Ofertas'
                              : 'Ver Detalle',
                      style: AppTypography.labelMd.copyWith(
                        color: isOnTheWayOrActive
                            ? AppColors.tertiary
                            : AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: isOnTheWayOrActive
                          ? AppColors.tertiary
                          : AppColors.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(JobRequest job) {
    switch (job.status) {
      case JobStatus.searching:
        return const ChambaBadge.negotiating(label: 'Buscando técnicos');
      case JobStatus.negotiating:
        return ChambaBadge.counterReceived(
          label: '${job.bids.length} ${job.bids.length == 1 ? 'Oferta' : 'Ofertas'}',
        );
      case JobStatus.accepted:
        return const ChambaBadge.negotiating(label: 'Aceptada (Pagar)');
      case JobStatus.onTheWay:
        return const ChambaBadge.confirmed(label: 'En camino');
      case JobStatus.onSite:
        return const ChambaBadge.confirmed(label: 'En sitio');
      case JobStatus.inProgress:
        return const ChambaBadge.confirmed(label: 'En ejecución');
      case JobStatus.forConfirmation:
        return const ChambaBadge.counterReceived(label: 'Por confirmar');
      case JobStatus.completed:
        return const ChambaBadge.confirmed(label: 'Completado');
      case JobStatus.inDispute:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'En disputa',
            style: AppTypography.labelSm.copyWith(
              color: Colors.deepOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case JobStatus.cancelled:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Cancelado',
            style: AppTypography.labelSm.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case JobStatus.refunded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Reembolsado',
            style: AppTypography.labelSm.copyWith(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    }
  }
}
