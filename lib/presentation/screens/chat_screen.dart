import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:math';
import 'dart:convert';

import '../../data/services/voice_message_service.dart';
import '../../data/services/camera_image_service.dart';

import '../../data/services/chat_api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/chamba_button.dart';
import '../../core/widgets/price_dial_stepper.dart';
import '../../data/models/job_request.dart';
import '../../data/models/chat_message.dart';
import '../state/app_state.dart';
import 'job_tracking_screen.dart';

class ChatScreen extends StatefulWidget {
  final AppState appState;
  final JobRequest job;

  const ChatScreen({super.key, required this.appState, required this.job});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatApi = ChatApiService();
  final _voice = VoiceMessageService();
  bool _recording = false;
  bool _startingAudio = false;
  Timer? _audioTimer;
  DateTime? _recordingStart;
  String? _playingId;

  Future<void> _startVoice() async {
    if (_sending || _closed || _recording || _startingAudio) return;
    setState(() => _startingAudio = true);
    try {
      await _voice.start();
      if (!mounted || _closed) {
        await _voice.cancel();
        return;
      }
      setState(() {
        _recording = true;
        _recordingStart = DateTime.now();
      });
      _audioTimer = Timer(const Duration(seconds: 30), _finishVoice);
    } on MicrophonePermissionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permite el micrófono para enviar audios.'),
            action: e.blocked
                ? SnackBarAction(
                    label: 'Ajustes',
                    onPressed: CameraImageService.openSettings,
                  )
                : null,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar el micrófono.')),
        );
      }
    } finally {
      if (mounted) setState(() => _startingAudio = false);
    }
  }

  Future<void> _cancelVoice() async {
    _audioTimer?.cancel();
    if (mounted) setState(() => _recording = false);
    try {
      await _voice.cancel();
    } catch (_) {}
  }

  Future<void> _finishVoice() async {
    if (!_recording) return;
    _audioTimer?.cancel();
    setState(() => _recording = false);
    try {
      final bytes = await _voice.stop();
      if (!mounted || _closed) return;
      final seconds = DateTime.now()
          .difference(_recordingStart!)
          .inSeconds
          .clamp(1, 30);
      final user = widget.appState.currentUser!;
      final message = ChatMessage(
        id: List.generate(
          16,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        jobId: widget.job.id,
        senderId: user.id,
        senderName: user.fullName,
        isFromWorker: widget.appState.isWorker,
        text: 'Mensaje de voz',
        timestamp: DateTime.now(),
        audioBase64: base64Encode(bytes),
        audioDurationSeconds: seconds,
        deliveryStatus: MessageDeliveryStatus.sending,
      );
      setState(() => _remoteMessages.add(message));
      await _transmit(message);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo recuperar el audio. Intenta grabarlo nuevamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _playVoice(ChatMessage message) async {
    try {
      if (_playingId == message.id) {
        await _voice.stopPlayback();
        return;
      }
      setState(() => _playingId = message.id);
      await _voice.play(base64Decode(message.audioBase64!));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio.')),
        );
      }
    } finally {
      if (mounted && _playingId == message.id) setState(() => _playingId = null);
    }
  }

  final List<ChatMessage> _remoteMessages = [];
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _closed = false;
  bool _sending = false;
  String? _chatError;
  bool get _remote => widget.appState.authToken != null;

  Future<void> _refreshChat() async {
    if (!_remote || _refreshing || !mounted) return;
    _refreshing = true;
    try {
      final snapshot = await _chatApi.load(
        widget.job.id,
        widget.appState.authToken!,
      );
      if (!mounted) return;
      final pending = _remoteMessages
          .where(
            (m) =>
                m.deliveryStatus == MessageDeliveryStatus.failed ||
                m.deliveryStatus == MessageDeliveryStatus.sending,
          )
          .where(
            (m) => !snapshot.messages.any(
              (s) => s.id == m.id && s.senderId == m.senderId,
            ),
          )
          .toList();
      setState(() {
        _closed = snapshot.closed;
        _chatError = null;
        _remoteMessages
          ..clear()
          ..addAll(snapshot.messages)
          ..addAll(snapshot.closed ? [] : pending);
      });
      if (snapshot.closed) {
        await _cancelVoice();
        await _voice.stopPlayback();
        _messageController.clear();
        _refreshTimer?.cancel();
      } else {
        await _chatApi.delivered(
          widget.job.id,
          widget.appState.authToken!,
          snapshot.receivedIds,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _chatError = 'No se pudo actualizar el chat.');
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _transmit(ChatMessage message) async {
    if (_sending || _closed) return;
    setState(() {
      _sending = true;
      _chatError = null;
      final i = _remoteMessages.indexWhere((m) => m.id == message.id);
      if (i >= 0) {
        _remoteMessages[i] = message.copyWith(
          deliveryStatus: MessageDeliveryStatus.sending,
        );
      }
    });
    try {
      await _chatApi.send(
        widget.job.id,
        widget.appState.authToken!,
        message.id,
        message.text,
        audioBase64: message.audioBase64,
        audioDurationSeconds: message.audioDurationSeconds,
      );
      if (!mounted) return;
      setState(() {
        final i = _remoteMessages.indexWhere((m) => m.id == message.id);
        if (i >= 0) {
          _remoteMessages[i] = message.copyWith(
            deliveryStatus: MessageDeliveryStatus.sent,
          );
        }
      });
      await _refreshChat();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final i = _remoteMessages.indexWhere((m) => m.id == message.id);
        if (i >= 0) {
          _remoteMessages[i] = message.copyWith(
            deliveryStatus: MessageDeliveryStatus.failed,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateChange);
    if (_remote) {
      _refreshChat();
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _refreshChat(),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _audioTimer?.cancel();
    if (_remote) {
      _voice.cancel().catchError((_) {});
      _voice.stopPlayback().catchError((_) {});
    }
    _messageController.dispose();
    _scrollController.dispose();
    widget.appState.removeListener(_onStateChange);
    super.dispose();
  }

  void _sendTextMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || _closed || _recording) return;
    if (_remote) {
      final id = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final user = widget.appState.currentUser!;
      final message = ChatMessage(
        id: id,
        jobId: widget.job.id,
        senderId: user.id,
        senderName: user.fullName,
        isFromWorker: widget.appState.isWorker,
        text: text,
        timestamp: DateTime.now(),
        deliveryStatus: MessageDeliveryStatus.sending,
      );
      setState(() => _remoteMessages.add(message));
      _messageController.clear();
      _transmit(message);
      return;
    }

    widget.appState.sendChatMessage(jobId: widget.job.id, text: text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _showProposePriceModal() {
    final currentJob = widget.appState.jobs.firstWhere(
      (j) => j.id == widget.job.id,
      orElse: () => widget.job,
    );
    double proposed = currentJob.budget;

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
                    const SizedBox(height: 16),
                    Text(
                      'Enviar Contraoferta en Chat',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aparecerá como una tarjeta interactiva donde la otra parte podrá aceptar o contraofertar con 1 toque.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    PriceDialStepper(
                      currentPrice: proposed,
                      recommendedPrice: currentJob.budget,
                      minPrice: 15.0,
                      maxPrice: 1500.0,
                      label: 'Tu Propuesta de Precio en Soles',
                      onPriceChanged: (val) {
                        setModalState(() => proposed = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    ChambaButton(
                      label:
                          'Proponer S/. ${proposed.toStringAsFixed(0)} en el Chat',
                      leadingIcon: Icons.handshake_rounded,
                      onPressed: () {
                        widget.appState.sendInChatCounterOffer(
                          jobId: widget.job.id,
                          amount: proposed,
                        );
                        Navigator.of(context).pop();
                        _scrollToBottom();
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

  void _scrollToBottom({bool animate = false}) {
    if (!_scrollController.hasClients) return;
    if (animate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _remote
        ? _remoteMessages
        : widget.appState.messagesForJob(widget.job.id);
    final isClient = widget.appState.isClient;
    final currentJob = widget.appState.jobs.firstWhere(
      (j) => j.id == widget.job.id,
      orElse: () => widget.job,
    );

    final partnerName = isClient
        ? (currentJob.workerName ?? 'Trabajador asignado')
        : currentJob.clientName;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary,
              child: Text(
                partnerName.isNotEmpty ? partnerName[0] : 'T',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: AppTypography.bodyLgMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.tertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentJob.status.displayLabel,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Llamando al número verificado +51 974 812 345...',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppColors.primary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobTrackingScreen(
                    appState: widget.appState,
                    job: currentJob,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_remote)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  _closed ? 'Servicio finalizado. El chat está cerrado.' : 'Los mensajes se eliminan al finalizar el servicio. Si hay una disputa, se conservan hasta resolverla.',
                  style: AppTypography.labelSm,
                ),
              ),
            if (_chatError != null)
              Row(
                children: [
                  Expanded(child: Text(_chatError!)),
                  TextButton(
                    onPressed: _refreshChat,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            // Top sticky negotiation bar showing reactive agreed budget
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: [
                  const Icon(
                    Icons.handshake_rounded,
                    size: 22,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Presupuesto actual acordado',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          'S/. ${currentJob.budget.toStringAsFixed(0)}',
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_remote)
                    ChambaButton.pill(
                      label: '💲 Contraofertar',
                      onPressed: _showProposePriceModal,
                    ),
                ],
              ),
            ),

            // Messages list
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        _closed
                            ? 'La conversación finalizó.'
                            : 'Aún no hay mensajes en esta solicitud.',
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = _remote
                            ? msg.senderId == widget.appState.currentUser?.id
                            : (isClient ? !msg.isFromWorker : msg.isFromWorker);
                        return _buildMessageBubble(msg, isMe, currentJob);
                      },
                    ),
            ),

            // Bottom Input bar with Quick Counteroffer action
            if (_recording)
              Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Grabando audio · máximo 30 s'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancelar audio',
                    onPressed: _cancelVoice,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  TextButton(
                    onPressed: _finishVoice,
                    child: const Text('Enviar audio'),
                  ),
                ],
              ),
            if (!_closed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(
                    top: BorderSide(color: Color(0x14202D33), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // FEATURE 3: Enviar Contraoferta quick button
                    if (!_remote)
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _showProposePriceModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💲', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                'Enviar Contraoferta',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLength: 4000,
                        enabled: !_closed && !_recording,
                        decoration: InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppColors.canvas,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _sendTextMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_remote)
                      IconButton(
                        tooltip: 'Grabar audio',
                        onPressed: _sending || _recording || _startingAudio
                            ? null
                            : _startVoice,
                        icon: const Icon(Icons.mic_outlined),
                      ),
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: _sending || _recording
                            ? null
                            : _sendTextMessage,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    bool isMe,
    JobRequest currentJob,
  ) {
    final isSystem = msg.senderId == 'system';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.tertiary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.tertiary.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            msg.text,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.tertiary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // FEATURE 3: Interactivity for in-chat counteroffers
    if (msg.isCounterOffer || msg.proposalAmount != null) {
      final offerValue = msg.offerAmount ?? msg.proposalAmount ?? 50.0;
      final status = msg.counterOfferStatus ?? CounterOfferStatus.pending;

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: status == CounterOfferStatus.accepted
                  ? AppColors.tertiary
                  : status == CounterOfferStatus.rejected
                  ? Colors.red.shade300
                  : AppColors.secondary,
              width: 1.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handshake_rounded,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PROPUESTA DE PRECIO',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'S/. ${offerValue.toStringAsFixed(0)}',
                style: AppTypography.numericBidLarge.copyWith(
                  color: AppColors.primary,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                msg.text,
                style: AppTypography.labelSm.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),

              // Status badges & Action buttons
              if (status == CounterOfferStatus.accepted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '¡Trato Aceptado! Presupuesto fijado',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (status == CounterOfferStatus.rejected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        'Propuesta no aceptada',
                        style: AppTypography.labelSm.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // PENDING STATUS
                if (!isMe) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: ChambaButton(
                          label: 'Aceptar S/. ${offerValue.toStringAsFixed(0)}',
                          leadingIcon: Icons.check,
                          height: 38,
                          onPressed: () {
                            widget.appState.acceptInChatCounterOffer(
                              messageId: msg.id,
                              jobId: currentJob.id,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: ChambaButton.secondary(
                          label: 'Contraofertar',
                          leadingIcon: Icons.sync_alt,
                          height: 38,
                          onPressed: _showProposePriceModal,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Esperando respuesta a tu propuesta...',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Normal text message bubble
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: const Color(0x14202D33)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08173B4D),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (msg.audioBase64 != null)
              TextButton.icon(
                onPressed: _recording ? null : () => _playVoice(msg),
                icon: Icon(
                  _playingId == msg.id
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  color: isMe ? Colors.white : AppColors.primary,
                ),
                label: Text(
                  'Audio · ${msg.audioDurationSeconds ?? 0} s',
                  style: TextStyle(
                    color: isMe ? Colors.white : AppColors.primary,
                  ),
                ),
              )
            else
              Text(
                msg.text,
                style: AppTypography.bodyMd.copyWith(
                  color: isMe ? Colors.white : AppColors.neutral,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),
            if (_remote && isMe)
              TextButton(
                onPressed:
                    msg.deliveryStatus == MessageDeliveryStatus.failed &&
                        !_sending &&
                        !_closed
                    ? () => _transmit(
                        msg.copyWith(
                          deliveryStatus: MessageDeliveryStatus.sending,
                        ),
                      )
                    : null,
                child: Text(switch (msg.deliveryStatus) {
                  MessageDeliveryStatus.sending => 'Enviando…',
                  MessageDeliveryStatus.sent => 'Enviado',
                  MessageDeliveryStatus.delivered => 'Entregado',
                  MessageDeliveryStatus.failed => 'Reintentar',
                }, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            Text(
              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
              style: AppTypography.labelSm.copyWith(
                fontSize: 10,
                color: isMe ? Colors.white70 : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
