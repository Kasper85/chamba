import 'api_client.dart';

class DisputeSettlement {
  final String verdict;
  final double totalCustody;
  final double refundClient;
  final double amountToWorker;
  final double commission;
  final double serviceFee;

  const DisputeSettlement({
    required this.verdict,
    required this.totalCustody,
    required this.refundClient,
    required this.amountToWorker,
    required this.commission,
    required this.serviceFee,
  });

  factory DisputeSettlement.fromJson(Map<String, dynamic> json) {
    return DisputeSettlement(
      verdict: json['verdict'] as String? ?? 'SPLIT',
      totalCustody: (json['totalCustody'] as num?)?.toDouble() ?? 0.0,
      refundClient: (json['refundClient'] as num?)?.toDouble() ?? 0.0,
      amountToWorker: (json['amountToWorker'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DisputeAuditInfo {
  final double totalCustody;
  final double refundClient;
  final double amountToWorker;
  final double commission;
  final double serviceFee;
  final double compensation;
  final double settledTotal;
  final bool invariantPassed;
  final String invariantFormula;
  final List<Map<String, dynamic>> entries;

  const DisputeAuditInfo({
    required this.totalCustody,
    required this.refundClient,
    required this.amountToWorker,
    required this.commission,
    required this.serviceFee,
    required this.compensation,
    required this.settledTotal,
    required this.invariantPassed,
    required this.invariantFormula,
    required this.entries,
  });

  factory DisputeAuditInfo.fromJson(Map<String, dynamic> json) {
    return DisputeAuditInfo(
      totalCustody: (json['totalCustody'] as num?)?.toDouble() ?? 0.0,
      refundClient: (json['refundClient'] as num?)?.toDouble() ?? 0.0,
      amountToWorker: (json['amountToWorker'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0.0,
      compensation: (json['compensation'] as num?)?.toDouble() ?? 0.0,
      settledTotal: (json['settledTotal'] as num?)?.toDouble() ?? 0.0,
      invariantPassed: json['invariantPassed'] as bool? ?? true,
      invariantFormula: json['invariantFormula'] as String? ?? '',
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
  }
}

class DisputeResolverInfo {
  final String id;
  final String email;
  final String fullName;
  final String role;

  const DisputeResolverInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory DisputeResolverInfo.fromJson(Map<String, dynamic> json) {
    return DisputeResolverInfo(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      role: json['role'] as String? ?? 'SUPPORT',
    );
  }
}

class DisputeDetailData {
  final String id;
  final String jobId;
  final String status;
  final String reason;
  final String? clientStatement;
  final String? workerStatement;
  final String? resolutionNotes;
  final String? resolvedAt;
  final DisputeSettlement? settlement;
  final DisputeAuditInfo? audit;
  final DisputeResolverInfo? resolvedBy;

  const DisputeDetailData({
    required this.id,
    required this.jobId,
    required this.status,
    required this.reason,
    this.clientStatement,
    this.workerStatement,
    this.resolutionNotes,
    this.resolvedAt,
    this.settlement,
    this.audit,
    this.resolvedBy,
  });

  bool get isResolved =>
      status.startsWith('RESUELTA') ||
      status == 'CERRADA' ||
      status == 'COMPLETADA' ||
      resolvedAt != null;

  factory DisputeDetailData.fromJson(Map<String, dynamic> json) {
    final disputeMap = json['dispute'] is Map<String, dynamic>
        ? json['dispute'] as Map<String, dynamic>
        : json;

    return DisputeDetailData(
      id: disputeMap['id'] as String? ?? '',
      jobId: disputeMap['jobRequestId'] as String? ?? '',
      status: disputeMap['status'] as String? ?? 'ABIERTA',
      reason: disputeMap['reason'] as String? ?? '',
      clientStatement: disputeMap['clientStatement'] as String?,
      workerStatement: disputeMap['workerStatement'] as String?,
      resolutionNotes: disputeMap['resolutionNotes'] as String?,
      resolvedAt: disputeMap['resolvedAt']?.toString(),
      settlement: json['settlement'] != null
          ? DisputeSettlement.fromJson(json['settlement'] as Map<String, dynamic>)
          : null,
      audit: json['audit'] != null
          ? DisputeAuditInfo.fromJson(json['audit'] as Map<String, dynamic>)
          : null,
      resolvedBy: json['resolvedBy'] != null
          ? DisputeResolverInfo.fromJson(json['resolvedBy'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DisputesApiService {
  final ApiClient apiClient;

  DisputesApiService({required this.apiClient});

  Future<DisputeDetailData?> getDisputeByJobId({
    required String jobId,
    String? token,
  }) async {
    if (token == null || token.isEmpty) return null;
    try {
      final response = await apiClient.get(
        '/api/v1/disputes/jobs/$jobId',
        token: token,
      );
      if (response.data is Map<String, dynamic>) {
        return DisputeDetailData.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<DisputeDetailData?> resolveDispute({
    required String disputeId,
    required String verdict,
    int? workerSplitPercent,
    String? notes,
    String? token,
  }) async {
    final response = await apiClient.post(
      '/api/v1/disputes/$disputeId/resolve',
      body: {
        'verdict': verdict,
        'workerSplitPercent': ?workerSplitPercent,
        'notes': ?notes,
      },
      token: token,
    );
    if (response.data is Map<String, dynamic>) {
      return DisputeDetailData.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }
}
