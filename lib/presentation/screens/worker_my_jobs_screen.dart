import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/chamba_card.dart';
import '../../core/widgets/chamba_badge.dart';
import '../../data/models/job_request.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';
import 'job_tracking_screen.dart';

class WorkerMyJobsScreen extends StatefulWidget {
  final AppState appState;

  const WorkerMyJobsScreen({
    super.key,
    required this.appState,
  });

  @override
  State<WorkerMyJobsScreen> createState() => _WorkerMyJobsScreenState();
}

class _WorkerMyJobsScreenState extends State<WorkerMyJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    widget.appState.addListener(_onStateUpdate);
  }

  void _onStateUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.appState.removeListener(_onStateUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allWorkerJobs = widget.appState.jobs;
    final workerId = widget.appState.currentWorkerProfile.id;

    final activeJobs = allWorkerJobs.where((j) {
      final isAccepted = j.workerId == workerId || j.acceptedBidId != null;
      return isAccepted &&
          (j.status == JobStatus.onTheWay ||
              j.status == JobStatus.onSite ||
              j.status == JobStatus.inProgress ||
              j.status == JobStatus.forConfirmation);
    }).toList();

    final negotiatingJobs = allWorkerJobs.where((j) {
      final hasBid = j.bids.any((b) => b.workerId == workerId);
      return hasBid && (j.status == JobStatus.searching || j.status == JobStatus.negotiating);
    }).toList();

    final completedJobs = allWorkerJobs.where((j) {
      return j.status == JobStatus.completed;
    }).toList();

    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mis Trabajos',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.secondary,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.secondary,
                indicatorWeight: 3,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: AppTypography.bodyMdMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 12),
                unselectedLabelStyle: AppTypography.bodyMdMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                tabs: [
                  Tab(text: 'Activas (${activeJobs.length})'),
                  Tab(text: 'Negociando (${negotiatingJobs.length})'),
                  Tab(text: 'Historial (${completedJobs.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildJobList(
                    activeJobs,
                    emptyTitle: 'Sin trabajos en curso',
                    emptyMessage: 'No tienes servicios activos en este momento.\nRevisa las chambas disponibles para postularte.',
                    icon: Icons.handyman_outlined,
                  ),
                  _buildJobList(
                    negotiatingJobs,
                    emptyTitle: 'Sin cotizaciones pendientes',
                    emptyMessage: 'No tienes contraofertas ni cotizaciones en negociación actualmente.',
                    icon: Icons.question_answer_outlined,
                  ),
                  _buildJobList(
                    completedJobs,
                    emptyTitle: 'Sin chambas finalizadas',
                    emptyMessage: 'Tus servicios completados y calificaciones se registrarán en esta sección.',
                    icon: Icons.history_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobList(
    List<JobRequest> jobs, {
    required String emptyTitle,
    required String emptyMessage,
    required IconData icon,
  }) {
    if (jobs.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                style: AppTypography.bodyLgMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.muted,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: ChambaCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobTrackingScreen(appState: widget.appState, job: job),
                ),
              );
            },
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
                      job.categoryName.toUpperCase(),
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    ChambaBadge(
                      label: job.status.displayLabel,
                      type: job.status == JobStatus.completed
                          ? ChambaBadgeType.confirmed
                          : ChambaBadgeType.counterReceived,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  job.title,
                  style: AppTypography.bodyLgMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.neutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cliente: ${job.clientName} • ${job.district}',
                  style: AppTypography.labelMd.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0x14202D33)),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'S/. ',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          job.budget.toStringAsFixed(0),
                          style: AppTypography.numericBid.copyWith(
                            color: AppColors.secondary,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.chat_bubble_outline, size: 20),
                          color: AppColors.primary,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(appState: widget.appState, job: job),
                              ),
                            );
                          },
                        ),
                        ChambaButton.pill(
                          label: 'Ver Detalles',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobTrackingScreen(appState: widget.appState, job: job),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
