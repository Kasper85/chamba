import 'bid.dart';
import 'job_state_machine.dart';

enum JobStatus {
  searching,       // BUSCANDO
  negotiating,     // NEGOCIANDO
  accepted,        // ACEPTADA
  onTheWay,        // EN_CAMINO
  onSite,          // EN_SITIO
  inProgress,      // EN_EJECUCION
  forConfirmation, // POR_CONFIRMAR
  completed,       // COMPLETADA
  inDispute,       // EN_DISPUTA
  cancelled,       // CANCELADA
  refunded,        // REEMBOLSADA
}

enum EscrowStatus {
  pendingDeposit,
  heldInEscrow,
  beforePhotoUploaded,
  afterPhotoUploaded,
  released,
  refunded,
}

extension EscrowStatusExtension on EscrowStatus {
  String get displayLabel {
    switch (this) {
      case EscrowStatus.pendingDeposit:
        return 'Pendiente de Depósito';
      case EscrowStatus.heldInEscrow:
        return 'Pago Protegido en Garantía';
      case EscrowStatus.beforePhotoUploaded:
        return 'Evidencia Inicial Registrada';
      case EscrowStatus.afterPhotoUploaded:
        return 'Evidencia Final Lista para Aprobación';
      case EscrowStatus.released:
        return 'Pago Liberado al Especialista';
      case EscrowStatus.refunded:
        return 'Garantía Reembolsada';
    }
  }
}

extension JobStatusExtension on JobStatus {
  String get displayLabel {
    switch (this) {
      case JobStatus.searching:
        return 'Buscando Técnicos';
      case JobStatus.negotiating:
        return 'Negociando Ofertas';
      case JobStatus.accepted:
        return 'Oferta Aceptada (Pendiente Depósito)';
      case JobStatus.onTheWay:
        return 'Especialista en Camino';
      case JobStatus.onSite:
        return 'Especialista en Sitio';
      case JobStatus.inProgress:
        return 'Servicio en Ejecución';
      case JobStatus.forConfirmation:
        return 'Por Confirmar';
      case JobStatus.completed:
        return 'Completado';
      case JobStatus.inDispute:
        return 'En Disputa';
      case JobStatus.cancelled:
        return 'Cancelado';
      case JobStatus.refunded:
        return 'Reembolsado';
    }
  }

  bool get isTerminal =>
      this == JobStatus.completed ||
      this == JobStatus.cancelled ||
      this == JobStatus.refunded;
}

class JobRequest {
  final String id;
  final String title;
  final String categoryId;
  final String categoryName;
  final String description;
  final double budget; // S/.
  final String district;
  final String address;
  final double distanceKm;
  final String urgency;
  final JobStatus status;
  final DateTime createdAt;
  final String clientId;
  final String clientName;
  final String confirmationCode;
  final List<Bid> bids;
  final String? acceptedBidId;
  final String? workerId;
  final String? workerName;

  final double latitude;
  final double longitude;
  final String reference;
  final String? paymentMethod;
  final int? rating;
  final String? reviewComment;
  final bool isPaid;

  // New SOS & Security PIN & Escrow fields
  final bool isSos;
  final DateTime? sosExpiresAt;
  final double urgencyMultiplier;
  final String securityPin;
  final bool isPinVerified;
  final EscrowStatus escrowStatus;
  final String? beforePhotoTag;
  final String? afterPhotoTag;

  const JobRequest({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.budget,
    required this.district,
    required this.address,
    this.latitude = -6.7760,
    this.longitude = -79.8436,
    this.reference = '',
    required this.distanceKm,
    required this.urgency,
    this.status = JobStatus.searching,
    required this.createdAt,
    required this.clientId,
    required this.clientName,
    required this.confirmationCode,
    this.bids = const [],
    this.acceptedBidId,
    this.workerId,
    this.workerName,
    this.paymentMethod,
    this.rating,
    this.reviewComment,
    this.isPaid = false,
    this.isSos = false,
    this.sosExpiresAt,
    this.urgencyMultiplier = 1.0,
    this.securityPin = '4829',
    this.isPinVerified = false,
    this.escrowStatus = EscrowStatus.pendingDeposit,
    this.beforePhotoTag,
    this.afterPhotoTag,
  });

  JobRequest copyWith({
    String? title,
    String? description,
    double? budget,
    String? district,
    String? address,
    double? latitude,
    double? longitude,
    String? reference,
    double? distanceKm,
    String? urgency,
    JobStatus? status,
    List<Bid>? bids,
    String? acceptedBidId,
    String? workerId,
    String? workerName,
    String? paymentMethod,
    int? rating,
    String? reviewComment,
    bool? isPaid,
    bool? isSos,
    DateTime? sosExpiresAt,
    double? urgencyMultiplier,
    String? securityPin,
    bool? isPinVerified,
    EscrowStatus? escrowStatus,
    String? beforePhotoTag,
    String? afterPhotoTag,
  }) {
    return JobRequest(
      id: id,
      title: title ?? this.title,
      categoryId: categoryId,
      categoryName: categoryName,
      description: description ?? this.description,
      budget: budget ?? this.budget,
      district: district ?? this.district,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reference: reference ?? this.reference,
      distanceKm: distanceKm ?? this.distanceKm,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      createdAt: createdAt,
      clientId: clientId,
      clientName: clientName,
      confirmationCode: confirmationCode,
      bids: bids ?? this.bids,
      acceptedBidId: acceptedBidId ?? this.acceptedBidId,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      isPaid: isPaid ?? this.isPaid,
      isSos: isSos ?? this.isSos,
      sosExpiresAt: sosExpiresAt ?? this.sosExpiresAt,
      urgencyMultiplier: urgencyMultiplier ?? this.urgencyMultiplier,
      securityPin: securityPin ?? this.securityPin,
      isPinVerified: isPinVerified ?? this.isPinVerified,
      escrowStatus: escrowStatus ?? this.escrowStatus,
      beforePhotoTag: beforePhotoTag ?? this.beforePhotoTag,
      afterPhotoTag: afterPhotoTag ?? this.afterPhotoTag,
    );
  }

  factory JobRequest.fromJson(Map<String, dynamic> json) {
    return JobRequest(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? 'cat-general',
      categoryName: json['categoryName'] as String? ?? json['category'] as String? ?? 'General',
      description: json['description'] as String? ?? '',
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      district: json['district'] as String? ?? 'Chiclayo',
      address: json['address'] as String? ?? 'Chiclayo, Perú',
      latitude: (json['latitude'] as num?)?.toDouble() ?? -6.7760,
      longitude: (json['longitude'] as num?)?.toDouble() ?? -79.8436,
      reference: json['reference'] as String? ?? '',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.5,
      urgency: json['urgency'] as String? ?? 'Media',
      status: json['status'] != null
          ? JobStateMachine.fromBackendName(json['status'].toString())
          : JobStatus.searching,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ??
          (json['client'] is Map ? json['client']['fullName']?.toString() ?? 'Cliente' : 'Cliente'),
      confirmationCode: json['confirmationCode'] as String? ?? 'CH-1234',
      bids: json['bids'] is List
          ? (json['bids'] as List)
              .map((b) => Bid.fromJson(b as Map<String, dynamic>))
              .toList()
          : const [],
      acceptedBidId: json['acceptedBidId'] as String?,
      workerId: json['workerId'] as String?,
      workerName: json['workerName'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      rating: json['rating'] as int?,
      reviewComment: json['reviewComment'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
      isSos: json['isSos'] as bool? ?? false,
      sosExpiresAt: json['sosExpiresAt'] != null
          ? DateTime.tryParse(json['sosExpiresAt'].toString())
          : null,
      urgencyMultiplier: (json['urgencyMultiplier'] as num?)?.toDouble() ?? 1.0,
      securityPin: json['securityPin'] as String? ?? '4829',
      isPinVerified: json['isPinVerified'] as bool? ?? false,
      escrowStatus: json['escrowStatus'] != null
          ? EscrowStatus.values.firstWhere(
              (e) => e.name.toLowerCase() == json['escrowStatus'].toString().toLowerCase(),
              orElse: () => EscrowStatus.pendingDeposit,
            )
          : EscrowStatus.pendingDeposit,
      beforePhotoTag: json['beforePhotoTag'] as String? ?? json['beforePhotoUrl'] as String?,
      afterPhotoTag: json['afterPhotoTag'] as String? ?? json['afterPhotoUrl'] as String?,
    );
  }
}
