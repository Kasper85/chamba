enum BidStatus {
  pending,
  countered,
  accepted,
  rejected,
}

class Bid {
  final String id;
  final String jobId;
  final String workerId;
  final String workerName;
  final String workerAvatar;
  final double workerRating;
  final int workerCompletedJobs;
  final bool isWorkerVerified;
  final double amount; // S/.
  final double? counterAmount; // Client or worker counter-bid
  final BidStatus status;
  final int etaMinutes;
  final String message;
  final DateTime createdAt;

  // New Phase 2 fields: Voice note & Quick Inclusion tags
  final bool hasVoiceNote;
  final int voiceDurationSeconds;
  final String? voiceTranscriptPreview;
  final bool includesMaterials;
  final String estimatedArrival;
  final List<String> inclusionTags;

  const Bid({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    required this.workerAvatar,
    required this.workerRating,
    required this.workerCompletedJobs,
    required this.isWorkerVerified,
    required this.amount,
    this.counterAmount,
    this.status = BidStatus.pending,
    required this.etaMinutes,
    required this.message,
    required this.createdAt,
    this.hasVoiceNote = false,
    this.voiceDurationSeconds = 0,
    this.voiceTranscriptPreview,
    this.includesMaterials = false,
    this.estimatedArrival = '25 min',
    this.inclusionTags = const [],
  });

  Bid copyWith({
    double? amount,
    double? counterAmount,
    BidStatus? status,
    int? etaMinutes,
    String? message,
    bool? hasVoiceNote,
    int? voiceDurationSeconds,
    String? voiceTranscriptPreview,
    bool? includesMaterials,
    String? estimatedArrival,
    List<String>? inclusionTags,
  }) {
    return Bid(
      id: id,
      jobId: jobId,
      workerId: workerId,
      workerName: workerName,
      workerAvatar: workerAvatar,
      workerRating: workerRating,
      workerCompletedJobs: workerCompletedJobs,
      isWorkerVerified: isWorkerVerified,
      amount: amount ?? this.amount,
      counterAmount: counterAmount ?? this.counterAmount,
      status: status ?? this.status,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      message: message ?? this.message,
      createdAt: createdAt,
      hasVoiceNote: hasVoiceNote ?? this.hasVoiceNote,
      voiceDurationSeconds: voiceDurationSeconds ?? this.voiceDurationSeconds,
      voiceTranscriptPreview: voiceTranscriptPreview ?? this.voiceTranscriptPreview,
      includesMaterials: includesMaterials ?? this.includesMaterials,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      inclusionTags: inclusionTags ?? this.inclusionTags,
    );
  }

  factory Bid.fromJson(Map<String, dynamic> json) {
    final worker = json['worker'] as Map<String, dynamic>?;
    final workerUser = worker?['user'] as Map<String, dynamic>?;
    final workerName = json['workerName']?.toString() ??
        workerUser?['fullName']?.toString() ??
        'Técnico Especialista';
    final workerAvatar = workerName.isNotEmpty ? workerName[0].toUpperCase() : 'T';

    final statusStr = json['status']?.toString().toUpperCase() ?? 'PENDIENTE';
    BidStatus bidStatus;
    switch (statusStr) {
      case 'CONTRAOFERTADA':
      case 'COUNTERED':
        bidStatus = BidStatus.countered;
        break;
      case 'ACEPTADA':
      case 'ACCEPTED':
        bidStatus = BidStatus.accepted;
        break;
      case 'RECHAZADA':
      case 'REJECTED':
        bidStatus = BidStatus.rejected;
        break;
      default:
        bidStatus = BidStatus.pending;
    }

    final amountNum = json['amount'];
    final amount = amountNum is num
        ? amountNum.toDouble()
        : double.tryParse(amountNum?.toString() ?? '0') ?? 0.0;
    final counterNum = json['counterAmount'];
    final counterAmount = counterNum is num
        ? counterNum.toDouble()
        : (counterNum != null ? double.tryParse(counterNum.toString()) : null);
    final eta = json['estimatedEtaMinutes'] is num
        ? (json['estimatedEtaMinutes'] as num).toInt()
        : (int.tryParse(json['etaMinutes']?.toString() ?? '') ?? 20);

    return Bid(
      id: json['id']?.toString() ?? '',
      jobId: json['jobRequestId']?.toString() ?? json['jobId']?.toString() ?? '',
      workerId: json['workerId']?.toString() ?? '',
      workerName: workerName,
      workerAvatar: workerAvatar,
      workerRating: (worker?['rating'] as num?)?.toDouble() ??
          (json['workerRating'] as num?)?.toDouble() ??
          5.0,
      workerCompletedJobs: (worker?['completedJobs'] as num?)?.toInt() ??
          (json['workerCompletedJobs'] as num?)?.toInt() ??
          0,
      isWorkerVerified: true,
      amount: amount,
      counterAmount: counterAmount,
      status: bidStatus,
      etaMinutes: eta,
      message: json['message']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      hasVoiceNote: json['voiceNoteUrl'] != null || json['hasVoiceNote'] == true,
      voiceTranscriptPreview: json['voiceTranscriptPreview']?.toString(),
      includesMaterials: json['includesMaterials'] == true,
      estimatedArrival: json['estimatedArrival']?.toString() ?? '$eta min',
      inclusionTags: (json['inclusionTags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobRequestId': jobId,
      'workerId': workerId,
      'amount': amount,
      'counterAmount': counterAmount,
      'status': status.name,
      'message': message,
      'estimatedEtaMinutes': etaMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
