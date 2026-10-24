import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/job_request.dart';
import '../../data/models/worker_profile.dart';
import '../../data/models/bid.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/app_notification.dart';
import '../../data/mock/mock_data.dart';
import '../../data/models/user_account.dart';
import '../../data/services/session_storage.dart';
import '../../data/services/api_client.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/services/location_api_service.dart';
import '../../data/services/finance_api_service.dart';
import '../../data/services/storage_api_service.dart';
import '../../data/services/ai_api_service.dart';
import '../../data/models/wallet_summary.dart';
import '../../data/models/ai_diagnostic_result.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';

enum UserRole {
  client,
  worker,
}

class AppState extends ChangeNotifier {
  final SessionStorage _sessionStorage;
  final ApiClient _apiClient;
  late final AuthApiService _authApi;
  late final LocationApiService _locationApi;
  late final FinanceApiService _financeApi;
  late final StorageApiService _storageApi;
  late final AiApiService _aiApi;

  UserRole _currentRole = UserRole.client;
  final List<JobRequest> _jobs = List.from(MockData.initialJobs);
  final List<WorkerProfile> _workers = List.from(MockData.mockWorkers);
  final List<ChatMessage> _chatMessages = List.from(MockData.initialChatMessages);
  final List<AppNotification> _notifications = [];

  String? _activeJobId;

  // Real authenticated user & session
  UserAccount? _currentUser;
  String? _authToken;

  // Real Nearby Workers State (Fase 4 PostGIS)
  List<WorkerProfile> _nearbyWorkers = [];
  bool _isLoadingNearbyWorkers = false;
  String? _nearbyWorkersError;
  double _userLatitude = -6.7824;
  double _userLongitude = -79.8415;
  double _nearbyRadiusKm = 15.0;
  String? _selectedNearbySpecialty;
  bool _hasFetchedNearbyWorkers = false;

  // Mock fallbacks for demo & test compatibility
  String _mockClientName = 'Lucía Fernández';
  String _mockClientPhone = '+51 974 123 456';
  String _mockClientEmail = 'lucia.fernandez@gmail.com';
  String _mockClientDistrict = 'Santa Victoria, Chiclayo';
  String _mockClientAddress = 'Calle Los Pinos 342, Dpto 201';

  String get clientName => _currentUser?.fullName ?? _mockClientName;
  set clientName(String val) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(fullName: val);
    } else {
      _mockClientName = val;
    }
    notifyListeners();
  }

  String get clientPhone => _currentUser?.phone ?? _mockClientPhone;
  set clientPhone(String val) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(phone: val);
    } else {
      _mockClientPhone = val;
    }
    notifyListeners();
  }

  String get clientEmail => _currentUser?.email ?? _mockClientEmail;
  set clientEmail(String val) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(email: val);
    } else {
      _mockClientEmail = val;
    }
    notifyListeners();
  }

  String get clientDistrict => _currentUser?.district ?? _mockClientDistrict;
  set clientDistrict(String val) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(district: val);
    } else {
      _mockClientDistrict = val;
    }
    notifyListeners();
  }

  String get clientAddress => _currentUser?.address ?? _mockClientAddress;
  set clientAddress(String val) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(address: val);
    } else {
      _mockClientAddress = val;
    }
    notifyListeners();
  }

  String get userInitials => _currentUser?.avatarInitials ?? 'CH';
  UserAccount? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isAuthenticated => _currentUser != null && _authToken != null;

  // Real Wallet State (Fase 4 FinTech Ledger)
  WalletSummary? _walletSummary;
  bool _isLoadingWallet = false;
  String? _walletError;

  WalletSummary? get walletSummary => _walletSummary;
  bool get isLoadingWallet => _isLoadingWallet;
  String? get walletError => _walletError;
  FinanceApiService get financeApi => _financeApi;

  Future<void> fetchWallet() async {
    final token = _authToken;
    if (token == null) return;

    _isLoadingWallet = true;
    _walletError = null;
    notifyListeners();

    try {
      final summary = await _financeApi.getWallet(token: token);
      _walletSummary = summary;
    } catch (e) {
      _walletError = e.toString();
    } finally {
      _isLoadingWallet = false;
      notifyListeners();
    }
  }

  StorageApiService get storageApi => _storageApi;
  AiApiService get aiApi => _aiApi;

  /// Ejecuta el flujo integral de Diagnóstico:
  /// 1. Solicita URL prefirmada (GET /storage/upload-url)
  /// 2. Sube los bytes a Cloudflare R2 vía PUT
  ///    - Si falla la subida a R2, lanza una excepción: 'No se pudo subir la foto'
  /// 3. Solicita diagnóstico a Gemini (POST /ai/diagnose)
  /// Retorna AiDiagnosticResult con el source real ('gemini-2.5-flash' o motor de respaldo)
  Future<AiDiagnosticResult> runAiDiagnosticFlow({
    required Uint8List imageBytes,
    required String filename,
    String? prompt,
  }) async {
    // 1. Obtener URL prefirmada
    PresignedUploadData presigned;
    try {
      presigned = await _storageApi.getPresignedUploadUrl(
        filename: filename,
        contentType: 'image/jpeg',
        folder: 'diagnostics',
        token: _authToken,
      );
    } catch (_) {
      throw const ApiException('No se pudo subir la foto');
    }

    // 2. PUT directo a R2
    final uploadSuccess = await _storageApi.uploadFileToPresignedUrl(
      uploadUrl: presigned.uploadUrl,
      bytes: imageBytes,
      contentType: presigned.contentType,
    );

    if (!uploadSuccess) {
      throw const ApiException('No se pudo subir la foto');
    }

    // 3. POST /ai/diagnose
    return _aiApi.diagnose(
      imageUrl: presigned.publicUrl,
      prompt: prompt,
      token: _authToken,
    );
  }

  AppState({
    ApiClient? apiClient,
    SessionStorage? sessionStorage,
    AuthApiService? authApi,
    LocationApiService? locationApi,
    FinanceApiService? financeApi,
    StorageApiService? storageApi,
    AiApiService? aiApi,
  })  : _sessionStorage = sessionStorage ?? SessionStorage(),
        _apiClient = apiClient ??
            ApiClient() {
    _authApi = authApi ?? AuthApiService(apiClient: _apiClient);
    _locationApi = locationApi ?? LocationApiService(apiClient: _apiClient);
    _financeApi = financeApi ?? FinanceApiService(apiClient: _apiClient);
    _storageApi = storageApi ?? StorageApiService(apiClient: _apiClient);
    _aiApi = aiApi ?? AiApiService(apiClient: _apiClient);
    _activeJobId = _jobs.first.id;

    // Prepopulate realistic notifications
    _notifications.addAll([
      AppNotification(
        id: 'notif-1',
        title: '¡Nueva oferta recibida!',
        body: 'Jorge Quispe ha enviado una propuesta por S/. 75 para tu solicitud de Gasfitería.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        relatedJobId: 'job-101',
        icon: Icons.local_offer_rounded,
      ),
      AppNotification(
        id: 'notif-2',
        title: 'Oferta recibida de Manuel S.',
        body: 'Manuel Santisteban aceptó tu presupuesto de S/. 60. Llega en 40 min.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        relatedJobId: 'job-101',
        icon: Icons.handyman_rounded,
      ),
      AppNotification(
        id: 'notif-3',
        title: 'Servicio completado',
        body: 'Tu servicio de Cerrajería fue marcado como completado.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
        icon: Icons.check_circle_outline,
      ),
    ]);
  }

  // Real Nearby Workers (Fase 4 PostGIS)
  List<WorkerProfile> get nearbyWorkers => _nearbyWorkers;
  bool get isLoadingNearbyWorkers => _isLoadingNearbyWorkers;
  String? get nearbyWorkersError => _nearbyWorkersError;
  double get userLatitude => _userLatitude;
  double get userLongitude => _userLongitude;
  double get nearbyRadiusKm => _nearbyRadiusKm;
  String? get selectedNearbySpecialty => _selectedNearbySpecialty;
  bool get hasFetchedNearbyWorkers => _hasFetchedNearbyWorkers;
  LocationApiService get locationApi => _locationApi;
  ApiClient get apiClient => _apiClient;

  Future<void> fetchNearbyWorkers({
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? specialty,
  }) async {
    _isLoadingNearbyWorkers = true;
    _nearbyWorkersError = null;
    if (latitude != null) _userLatitude = latitude;
    if (longitude != null) _userLongitude = longitude;
    if (radiusKm != null) _nearbyRadiusKm = radiusKm;
    _selectedNearbySpecialty = specialty;
    notifyListeners();

    try {
      final workers = await _locationApi.getNearbyWorkers(
        lat: _userLatitude,
        lng: _userLongitude,
        radiusKm: _nearbyRadiusKm,
        specialty: _selectedNearbySpecialty,
      );
      _nearbyWorkers = workers;
      _hasFetchedNearbyWorkers = true;
    } catch (e) {
      _nearbyWorkersError = e.toString();
    } finally {
      _isLoadingNearbyWorkers = false;
      notifyListeners();
    }
  }

  void setUserCoordinates(double lat, double lng) {
    _userLatitude = lat;
    _userLongitude = lng;
    notifyListeners();
  }

  Future<bool> updateWorkerGpsLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await _locationApi.updateWorkerLocation(
        latitude: latitude,
        longitude: longitude,
        token: _authToken,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Sincroniza la ubicación geoespacial del trabajador (PostGIS)
  /// mediante PUT /api/v1/location/worker. Se dispara al abrir WorkerShell
  /// y al activarse como disponible.
  Future<bool> syncWorkerLocation({
    double? latitude,
    double? longitude,
    bool tryGps = false,
  }) async {
    double lat = latitude ?? _userLatitude;
    double lng = longitude ?? _userLongitude;

    if (tryGps) {
      try {
        LocationPermission permission = await Geolocator.checkPermission()
            .timeout(const Duration(milliseconds: 600));
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission()
              .timeout(const Duration(milliseconds: 600));
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {
        // Fallback a coordenadas actuales
      }
    }

    _userLatitude = lat;
    _userLongitude = lng;
    notifyListeners();

    return updateWorkerGpsLocation(latitude: lat, longitude: lng);
  }

  UserRole get currentRole => _currentRole;
  bool get isClient => _currentRole == UserRole.client;
  bool get isWorker => _currentRole == UserRole.worker;

  // Dynamic role-based design tokens
  Color get roleAccentColor => isClient ? AppColors.secondary : AppColors.workerAccent;
  Color get rolePrimaryColor => isClient ? AppColors.primary : AppColors.workerPrimary;
  Color get roleSurfaceColor => isClient ? AppColors.surfaceContainer : AppColors.workerSurfaceContainer;
  String get roleDisplayName => isClient ? 'Modo Cliente' : 'Modo Chamba (Técnico)';

  List<JobRequest> get jobs => List.unmodifiable(_jobs);
  List<WorkerProfile> get workers => List.unmodifiable(_workers);

  WorkerProfile get currentWorkerProfile {
    final user = _currentUser;
    if (user != null) {
      final wp = user.workerProfile;
      return WorkerProfile(
        id: wp?.id ?? 'worker-${user.id}',
        name: user.fullName,
        avatarInitials: user.avatarInitials,
        rating: wp?.rating ?? 5.0,
        completedJobs: wp?.completedJobs ?? 0,
        isVerified: true,
        isIdVerified: true,
        hasCleanRecord: true,
        offersWarranty: true,
        skills: wp?.specialty != null && wp!.specialty!.isNotEmpty
            ? [wp.specialty!, 'Mantenimiento del Hogar', 'Diagnóstico Técnico']
            : ['Servicios Generales', 'Mantenimiento'],
        bio: wp?.bio ?? 'Técnico especialista registrado en CHAMBA Perú.',
        baseRate: 40.0,
        serviceRadiusKm: 15,
        district: user.district ?? 'Chiclayo',
        phone: user.phone ?? '+51 974 000 000',
        dni: '45892314',
        experienceYears: 5,
        portfolioCases: _workers.first.portfolioCases,
        reviews: _workers.first.reviews,
      );
    }
    return _workers.first;
  }

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  JobRequest? get activeJob {
    if (_activeJobId == null) return null;
    return _jobs.firstWhere(
      (j) => j.id == _activeJobId,
      orElse: () => _jobs.first,
    );
  }

  List<JobRequest> get clientJobs {
    final currentId = _currentUser?.id ?? 'client-1';
    return _jobs.where((j) => j.clientId == currentId || j.clientId == 'client-1').toList();
  }

  List<JobRequest> get availableWorkerJobs =>
      _jobs.where((j) => j.status == JobStatus.searching || j.status == JobStatus.negotiating).toList();

  List<JobRequest> get workerActiveJobs {
    final workerId = currentWorkerProfile.id;
    return _jobs
        .where((j) =>
            j.workerId == workerId ||
            j.bids.any((b) => b.workerId == workerId) ||
            j.workerId == 'worker-1')
        .toList();
  }

  // Session lifecycle management
  Future<void> setSession(UserAccount user, String token) async {
    _currentUser = user;
    _authToken = token;
    await _sessionStorage.saveToken(token);
    await _sessionStorage.saveUser(user);
    notifyListeners();
  }

  Future<void> updateUser(UserAccount user) async {
    _currentUser = user;
    await _sessionStorage.saveUser(user);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _authToken = null;
    await _sessionStorage.clearSession();
    notifyListeners();
  }

  Future<bool> restoreSession() async {
    final token = await _sessionStorage.getToken();
    if (token == null || token.isEmpty) return false;

    // Try reading cached user first for immediate UI responsiveness
    final cachedUser = await _sessionStorage.getUser();
    if (cachedUser != null) {
      _currentUser = cachedUser;
      _authToken = token;
      notifyListeners();
    }

    try {
      final freshUser = await _authApi.getMe(token);
      _currentUser = freshUser;
      _authToken = token;
      await _sessionStorage.saveUser(freshUser);
      notifyListeners();
      return true;
    } catch (_) {
      if (cachedUser == null) {
        await _sessionStorage.clearSession();
        _currentUser = null;
        _authToken = null;
        notifyListeners();
        return false;
      }
      return true;
    }
  }

  Future<void> refreshUserProfile() async {
    if (_authToken == null) return;
    try {
      final freshUser = await _authApi.getMe(_authToken!);
      _currentUser = freshUser;
      await _sessionStorage.saveUser(freshUser);
      notifyListeners();
    } catch (_) {}
  }

  List<ChatMessage> messagesForJob(String jobId) =>
      _chatMessages.where((m) => m.jobId == jobId).toList();

  // List of distinct jobs that have chat messages (conversations inbox)
  List<JobRequest> get conversationJobs {
    final jobIdsWithMessages = _chatMessages.map((m) => m.jobId).toSet();
    return _jobs.where((j) => jobIdsWithMessages.contains(j.id) || j.status != JobStatus.searching).toList();
  }

  void switchRole(UserRole role) {
    if (_currentRole != role) {
      _currentRole = role;
      notifyListeners();
    }
  }

  void toggleUserRole() {
    _currentRole = _currentRole == UserRole.client ? UserRole.worker : UserRole.client;
    notifyListeners();
  }

  void setActiveJob(String jobId) {
    _activeJobId = jobId;
    notifyListeners();
  }

  JobRequest createJobRequest({
    required String title,
    required String categoryId,
    required String categoryName,
    required String description,
    required double budget,
    required String district,
    required String address,
    required String urgency,
    double latitude = -6.7760,
    double longitude = -79.8436,
    String reference = '',
    bool isSos = false,
    double urgencyMultiplier = 1.0,
  }) {
    final generatedPin = '${1000 + (DateTime.now().millisecond * 9) % 9000}';
    final newJob = JobRequest(
      id: 'job-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      categoryId: categoryId,
      categoryName: categoryName,
      description: description,
      budget: budget,
      district: district,
      address: address,
      latitude: latitude,
      longitude: longitude,
      reference: reference,
      distanceKm: 1.5,
      urgency: urgency,
      status: JobStatus.searching,
      createdAt: DateTime.now(),
      clientId: 'client-1',
      clientName: clientName,
      confirmationCode: generatedPin,
      securityPin: generatedPin,
      isPinVerified: false,
      isSos: isSos,
      urgencyMultiplier: urgencyMultiplier,
      sosExpiresAt: isSos ? DateTime.now().add(const Duration(minutes: 30)) : null,
      escrowStatus: EscrowStatus.heldInEscrow, // Auto-held for demo smoothness
      bids: [],
    );

    _jobs.insert(0, newJob);
    _activeJobId = newJob.id;

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: isSos ? '🚨 ¡Alerta SOS Activada (< 30 min)!' : '¡Solicitud publicada con éxito!',
        body: isSos
            ? 'Tu urgencia de "$title" fue enviada con máxima prioridad a especialistas en Chiclayo con llegada en < 30 min.'
            : 'Tu solicitud de "$title" está activa. Los especialistas cercanos están revisando tu presupuesto.',
        timestamp: DateTime.now(),
        relatedJobId: newJob.id,
        icon: isSos ? Icons.emergency_rounded : Icons.campaign_rounded,
      ),
    );

    notifyListeners();
    return newJob;
  }

  // Security PIN Verification (Face-to-face trust handshake)
  bool verifySecurityPin(String jobId, String enteredPin) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return false;

    final job = _jobs[jobIndex];
    if (job.securityPin.trim() == enteredPin.trim() || job.confirmationCode.trim() == enteredPin.trim()) {
      _jobs[jobIndex] = job.copyWith(
        isPinVerified: true,
        status: JobStatus.inProgress,
      );

      _notifications.insert(
        0,
        AppNotification(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          title: '🛡️ ¡PIN de Seguridad Validado!',
          body: 'Identidad presencial confirmada con éxito. El servicio ha iniciado de manera segura.',
          timestamp: DateTime.now(),
          relatedJobId: jobId,
          icon: Icons.verified_user_rounded,
        ),
      );

      notifyListeners();
      return true;
    }
    return false;
  }

  // Escrow Phase 1: Deposit funds into protected guarantee
  void depositEscrow({
    required String jobId,
    required String paymentMethod,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    _jobs[jobIndex] = job.copyWith(
      escrowStatus: EscrowStatus.heldInEscrow,
      paymentMethod: paymentMethod,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '🔒 Pago en Garantía Protegido',
        body: 'S/. ${job.budget.toStringAsFixed(0)} depositados en custodia Chamba vía $paymentMethod. Los fondos solo se liberarán cuando apruebes el trabajo.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.shield_rounded,
      ),
    );

    notifyListeners();
  }

  // Escrow Phase 3: Upload Before Evidence
  void uploadBeforeEvidence({
    required String jobId,
    required String tag,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    _jobs[jobIndex] = job.copyWith(
      beforePhotoTag: tag,
      escrowStatus: EscrowStatus.beforePhotoUploaded,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '📸 Evidencia del "Antes" Registrada',
        body: 'El estado inicial del desperfecto fue capturado y archivado en tu expediente de garantía.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.camera_alt_rounded,
      ),
    );

    notifyListeners();
  }

  // Escrow Phase 4: Upload After Evidence
  void uploadAfterEvidence({
    required String jobId,
    required String tag,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    _jobs[jobIndex] = job.copyWith(
      afterPhotoTag: tag,
      escrowStatus: EscrowStatus.afterPhotoUploaded,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '✨ Trabajo Concluido - Evidencia "Después"',
        body: 'El técnico finalizó la intervención. Revisa las fotos y confirma la conformidad para liberar el pago.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.check_circle_rounded,
      ),
    );

    notifyListeners();
  }

  // Escrow Final: Client approves conformity and releases payment
  void releaseEscrow(String jobId) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    _jobs[jobIndex] = job.copyWith(
      escrowStatus: EscrowStatus.released,
      status: JobStatus.completed,
      isPaid: true,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '🎉 ¡Pago Liberado al Especialista!',
        body: 'Se transfirieron S/. ${job.budget.toStringAsFixed(0)} a ${job.workerName ?? "el especialista"}. ¡Tu garantía Chamba de 7 días está activa!',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.monetization_on_rounded,
      ),
    );

    notifyListeners();
  }

  void cancelJob(String jobId, {String? reason}) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    _jobs[jobIndex] = job.copyWith(status: JobStatus.cancelled);

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Solicitud cancelada',
        body: 'Has cancelado la solicitud "${job.title}".',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.cancel_outlined,
      ),
    );

    notifyListeners();
  }

  void submitBid({
    required String jobId,
    required double amount,
    required int etaMinutes,
    required String message,
    bool hasVoiceNote = false,
    int voiceDurationSeconds = 0,
    String? voiceTranscriptPreview,
    bool includesMaterials = false,
    String estimatedArrival = '25 min',
    List<String> inclusionTags = const [],
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final newBid = Bid(
      id: 'bid-${DateTime.now().millisecondsSinceEpoch}',
      jobId: jobId,
      workerId: currentWorkerProfile.id,
      workerName: currentWorkerProfile.name,
      workerAvatar: currentWorkerProfile.avatarInitials,
      workerRating: currentWorkerProfile.rating,
      workerCompletedJobs: currentWorkerProfile.completedJobs,
      isWorkerVerified: currentWorkerProfile.isVerified,
      amount: amount,
      etaMinutes: etaMinutes,
      message: message,
      status: BidStatus.pending,
      createdAt: DateTime.now(),
      hasVoiceNote: hasVoiceNote,
      voiceDurationSeconds: voiceDurationSeconds,
      voiceTranscriptPreview: voiceTranscriptPreview,
      includesMaterials: includesMaterials,
      estimatedArrival: estimatedArrival,
      inclusionTags: inclusionTags,
    );

    final job = _jobs[jobIndex];
    final updatedBids = List<Bid>.from(job.bids)..add(newBid);

    _jobs[jobIndex] = job.copyWith(
      bids: updatedBids,
      status: JobStatus.negotiating,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '¡Oferta enviada!',
        body: 'Enviaste tu propuesta de S/. ${amount.toStringAsFixed(0)} para "${job.title}".',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.send_rounded,
      ),
    );

    notifyListeners();
  }

  void counterBid({
    required String jobId,
    required String bidId,
    required double counterAmount,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    final bidIndex = job.bids.indexWhere((b) => b.id == bidId);
    if (bidIndex == -1) return;

    final updatedBid = job.bids[bidIndex].copyWith(
      counterAmount: counterAmount,
      status: BidStatus.countered,
    );

    final updatedBids = List<Bid>.from(job.bids)..[bidIndex] = updatedBid;
    _jobs[jobIndex] = job.copyWith(bids: updatedBids);

    // Record in chat messages
    _chatMessages.add(
      ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        jobId: jobId,
        senderId: 'client-1',
        senderName: clientName,
        isFromWorker: false,
        text: 'He enviado una contraoferta por S/. ${counterAmount.toStringAsFixed(0)}',
        proposalAmount: counterAmount,
        timestamp: DateTime.now(),
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Contraoferta enviada',
        body: 'Propusiste S/. ${counterAmount.toStringAsFixed(0)} a ${job.bids[bidIndex].workerName}.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.sync_alt_rounded,
      ),
    );

    notifyListeners();
  }

  void rejectBid({
    required String jobId,
    required String bidId,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    final bidIndex = job.bids.indexWhere((b) => b.id == bidId);
    if (bidIndex == -1) return;

    final rejectedBid = job.bids[bidIndex].copyWith(status: BidStatus.rejected);
    final updatedBids = List<Bid>.from(job.bids)..[bidIndex] = rejectedBid;

    _jobs[jobIndex] = job.copyWith(bids: updatedBids);
    notifyListeners();
  }

  void acceptBid({
    required String jobId,
    required String bidId,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    final job = _jobs[jobIndex];
    final bidIndex = job.bids.indexWhere((b) => b.id == bidId);
    if (bidIndex == -1) return;

    final acceptedBid = job.bids[bidIndex];
    final updatedBid = acceptedBid.copyWith(status: BidStatus.accepted);
    final updatedBids = List<Bid>.from(job.bids)..[bidIndex] = updatedBid;

    final agreedPrice = acceptedBid.counterAmount ?? acceptedBid.amount;

    _jobs[jobIndex] = job.copyWith(
      status: JobStatus.onTheWay,
      acceptedBidId: bidId,
      workerId: acceptedBid.workerId,
      workerName: acceptedBid.workerName,
      budget: agreedPrice,
      bids: updatedBids,
    );

    _activeJobId = jobId;

    // Send agreement message to chat
    _chatMessages.add(
      ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        jobId: jobId,
        senderId: 'client-1',
        senderName: clientName,
        isFromWorker: false,
        text: '¡Trato cerrado por S/. ${agreedPrice.toStringAsFixed(0)}! Código de seguridad generado.',
        proposalAmount: agreedPrice,
        timestamp: DateTime.now(),
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '¡Especialista contratado!',
        body: '${acceptedBid.workerName} aceptó el servicio por S/. ${agreedPrice.toStringAsFixed(0)} y va en camino.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.two_wheeler_rounded,
      ),
    );

    notifyListeners();
  }

  void confirmArrival(String jobId) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    _jobs[jobIndex] = _jobs[jobIndex].copyWith(status: JobStatus.inProgress);

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '¡Especialista en el domicilio!',
        body: 'El especialista ha llegado y el trabajo ha iniciado.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.handyman_rounded,
      ),
    );

    notifyListeners();
  }

  void completeJob(String jobId) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    _jobs[jobIndex] = _jobs[jobIndex].copyWith(status: JobStatus.completed);

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '¡Chamba Finalizada!',
        body: 'El trabajo fue completado con éxito. Por favor confirma tu método de pago.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.check_circle_rounded,
      ),
    );

    notifyListeners();
  }

  void registerPayment({
    required String jobId,
    required String paymentMethod,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    _jobs[jobIndex] = _jobs[jobIndex].copyWith(
      paymentMethod: paymentMethod,
      isPaid: true,
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Pago registrado',
        body: 'Pago de S/. ${_jobs[jobIndex].budget.toStringAsFixed(0)} registrado mediante $paymentMethod.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.payments_outlined,
      ),
    );

    notifyListeners();
  }

  void rateJob({
    required String jobId,
    required int rating,
    String? reviewComment,
  }) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    _jobs[jobIndex] = _jobs[jobIndex].copyWith(
      rating: rating,
      reviewComment: reviewComment,
    );

    notifyListeners();
  }

  void updateJobStatus(String jobId, JobStatus newStatus) {
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex == -1) return;

    _jobs[jobIndex] = _jobs[jobIndex].copyWith(status: newStatus);
    notifyListeners();
  }

  void sendChatMessage({
    required String jobId,
    required String text,
    double? proposalAmount,
  }) {
    final isFromWorker = _currentRole == UserRole.worker;
    final senderName = isFromWorker ? currentWorkerProfile.name : clientName;
    final senderId = isFromWorker ? currentWorkerProfile.id : (_currentUser?.id ?? 'client-1');

    final message = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      jobId: jobId,
      senderId: senderId,
      senderName: senderName,
      isFromWorker: isFromWorker,
      text: text,
      proposalAmount: proposalAmount,
      timestamp: DateTime.now(),
    );

    _chatMessages.add(message);
    notifyListeners();
  }

  void sendInChatCounterOffer({
    required String jobId,
    required double amount,
  }) {
    final isFromWorker = _currentRole == UserRole.worker;
    final senderName = isFromWorker ? currentWorkerProfile.name : clientName;
    final senderId = isFromWorker ? currentWorkerProfile.id : (_currentUser?.id ?? 'client-1');

    final message = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      jobId: jobId,
      senderId: senderId,
      senderName: senderName,
      isFromWorker: isFromWorker,
      text: 'Propuesta directa en chat: S/. ${amount.toStringAsFixed(0)}',
      proposalAmount: amount,
      isCounterOffer: true,
      offerAmount: amount,
      counterOfferStatus: CounterOfferStatus.pending,
      timestamp: DateTime.now(),
    );

    _chatMessages.add(message);

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '💬 Nueva Contraoferta en Chat',
        body: '$senderName propuso cerrar el servicio por S/. ${amount.toStringAsFixed(0)}.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.handshake_rounded,
      ),
    );

    notifyListeners();
  }

  void acceptInChatCounterOffer({
    required String messageId,
    required String jobId,
  }) {
    final msgIndex = _chatMessages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final originalMsg = _chatMessages[msgIndex];
    final agreedAmount = originalMsg.offerAmount ?? originalMsg.proposalAmount ?? 50.0;

    _chatMessages[msgIndex] = originalMsg.copyWith(
      counterOfferStatus: CounterOfferStatus.accepted,
    );

    // Update job budget
    final jobIndex = _jobs.indexWhere((j) => j.id == jobId);
    if (jobIndex != -1) {
      _jobs[jobIndex] = _jobs[jobIndex].copyWith(
        budget: agreedAmount,
      );
    }

    // Add confirmation system message to chat
    _chatMessages.add(
      ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        jobId: jobId,
        senderId: 'system',
        senderName: 'Chamba Oficial',
        isFromWorker: false,
        text: '🤝 ¡Trato Cerrado! Se ha fijado el precio final en S/. ${agreedAmount.toStringAsFixed(0)}.',
        proposalAmount: agreedAmount,
        timestamp: DateTime.now(),
      ),
    );

    _notifications.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: '🎉 ¡Contraoferta Aceptada!',
        body: 'El precio del trabajo fue actualizado a S/. ${agreedAmount.toStringAsFixed(0)}.',
        timestamp: DateTime.now(),
        relatedJobId: jobId,
        icon: Icons.check_circle_rounded,
      ),
    );

    notifyListeners();
  }

  void rejectInChatCounterOffer({
    required String messageId,
    required String jobId,
  }) {
    final msgIndex = _chatMessages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;

    final isFromWorker = _currentRole == UserRole.worker;
    final senderName = isFromWorker ? currentWorkerProfile.name : clientName;

    _chatMessages[msgIndex] = _chatMessages[msgIndex].copyWith(
      counterOfferStatus: CounterOfferStatus.rejected,
    );

    _chatMessages.add(
      ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        jobId: jobId,
        senderId: isFromWorker ? currentWorkerProfile.id : (_currentUser?.id ?? 'client-1'),
        senderName: senderName,
        isFromWorker: isFromWorker,
        text: 'La propuesta de precio no fue aceptada. Puedes enviar otra oferta.',
        timestamp: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void updateWorkerProfile(WorkerProfile profile) {
    if (_currentUser != null) {
      final currentWp = _currentUser!.workerProfile;
      final updatedWp = WorkerProfileData(
        id: currentWp?.id ?? 'worker-${_currentUser!.id}',
        bio: profile.bio,
        district: profile.district,
        specialty: profile.skills.isNotEmpty ? profile.skills.first : 'Servicios Generales',
        isAvailable: profile.isVerified,
        rating: currentWp?.rating ?? profile.rating,
        completedJobs: currentWp?.completedJobs ?? profile.completedJobs,
      );
      _currentUser = _currentUser!.copyWith(
        fullName: profile.name,
        phone: profile.phone,
        district: profile.district,
        workerProfile: updatedWp,
      );
      _sessionStorage.saveUser(_currentUser!);
    }
    final index = _workers.indexWhere((w) => w.id == profile.id);
    if (index != -1) {
      _workers[index] = profile;
    } else {
      _workers.add(profile);
    }
    notifyListeners();
  }

  void markAllNotificationsAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }
}
