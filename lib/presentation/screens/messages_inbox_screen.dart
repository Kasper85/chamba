import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_card.dart';
import '../state/app_state.dart';
import 'chat_screen.dart';

class MessagesInboxScreen extends StatefulWidget {
  final AppState appState;

  const MessagesInboxScreen({super.key, required this.appState});

  @override
  State<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends State<MessagesInboxScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final jobsWithConversations = widget.appState.jobs.where((job) {
      final messages = widget.appState.messagesForJob(job.id);
      final matchesSearch = job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (job.workerName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          job.categoryName.toLowerCase().contains(_searchQuery.toLowerCase());
      return messages.isNotEmpty && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mensajes',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por técnico o servicio...',
                hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.muted),
                prefixIcon: const Icon(Icons.search, color: AppColors.muted, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                filled: true,
                fillColor: AppColors.canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const Divider(height: 1, color: Color(0x14202D33)),

          // Conversations List or Empty State
          Expanded(
            child: jobsWithConversations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: jobsWithConversations.length,
                    itemBuilder: (context, index) {
                      final job = jobsWithConversations[index];
                      final messages = widget.appState.messagesForJob(job.id);
                      final lastMessage = messages.isNotEmpty ? messages.last : null;

                      final otherPartyName = widget.appState.isClient
                          ? (job.workerName ?? 'Especialista')
                          : job.clientName;
                      final otherPartyInitials = otherPartyName
                          .split(' ')
                          .map((e) => e.isNotEmpty ? e[0] : '')
                          .take(2)
                          .join();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ChambaCard(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  appState: widget.appState,
                                  job: job,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  otherPartyInitials.isNotEmpty ? otherPartyInitials : 'CH',
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
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            otherPartyName,
                                            style: AppTypography.bodyLgMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.neutral,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          'S/. ${job.budget.toStringAsFixed(0)}',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      job.title,
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      lastMessage?.text ?? 'Conversación activa',
                                      style: AppTypography.bodyMd.copyWith(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, color: AppColors.muted),
                            ],
                          ),
                        ),
                      );
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
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bandeja sin mensajes',
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando interactúes con una oferta o inicies una negociación, los chats aparecerán aquí.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
