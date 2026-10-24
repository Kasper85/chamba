class WorkerReview {
  final String id;
  final String clientName;
  final double rating;
  final String comment;
  final String date;

  const WorkerReview({
    required this.id,
    required this.clientName,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

class BeforeAfterCase {
  final String id;
  final String title;
  final String category;
  final String beforeDescription;
  final String afterDescription;
  final String beforeImageUrl;
  final String afterImageUrl;
  final String timeSpent;
  final double cost;

  const BeforeAfterCase({
    required this.id,
    required this.title,
    required this.category,
    required this.beforeDescription,
    required this.afterDescription,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.timeSpent = '45 min',
    this.cost = 65.0,
  });
}

class WorkerProfile {
  final String id;
  final String? userId;
  final String name;
  final String avatarInitials;
  final double rating;
  final int completedJobs;
  final bool isVerified;
  final List<String> skills;
  final String bio;
  final double baseRate;
  final int serviceRadiusKm;
  final String district;
  final String phone;
  final String dni;
  final int experienceYears;
  final List<WorkerReview> reviews;

  // Escudo de Confianza flags
  final bool isIdVerified;
  final bool hasCleanRecord;
  final bool offersWarranty;

  // Real before & after work portfolio
  final List<BeforeAfterCase> portfolioCases;

  // Geolocation & Backend Origin (Fase 4 PostGIS)
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isRealBackendWorker;

  const WorkerProfile({
    required this.id,
    this.userId,
    required this.name,
    required this.avatarInitials,
    required this.rating,
    required this.completedJobs,
    required this.isVerified,
    required this.skills,
    required this.bio,
    required this.baseRate,
    required this.serviceRadiusKm,
    required this.district,
    required this.phone,
    required this.dni,
    required this.experienceYears,
    required this.reviews,
    this.isIdVerified = true,
    this.hasCleanRecord = true,
    this.offersWarranty = true,
    this.portfolioCases = const [],
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.isRealBackendWorker = false,
  });

  static String _extractInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'CH';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Construye un perfil a partir del endpoint GET /api/v1/location/nearby
  /// Cumpliendo estrictamente con las reglas de veracidad aprobadas:
  /// - baseRate = 0.0 (activa "Tarifa a convenir", nunca inventar S/ 40)
  /// - Sin sellos falsos de verificación (isVerified, isIdVerified, hasCleanRecord, offersWarranty en false)
  /// - experienceYears = 0 (oculto en UI para técnicos reales)
  /// - reviews y portfolio vacíos ("Aún sin reseñas")
  /// - No expone el email en campos del perfil
  factory WorkerProfile.fromNearbyJson(Map<String, dynamic> json) {
    final fullName = (json['fullName'] as String?)?.trim() ?? 'Técnico';
    final specialty = json['specialty'] as String?;
    final skillsList = <String>[];
    if (specialty != null && specialty.trim().isNotEmpty) {
      skillsList.add(specialty.trim());
    }

    final district = (json['workerDistrict'] as String?)?.trim() ??
        (json['userDistrict'] as String?)?.trim() ??
        'Chiclayo';

    return WorkerProfile(
      id: (json['workerProfileId'] as String?) ?? (json['id'] as String?) ?? '',
      userId: json['userId'] as String?,
      name: fullName,
      avatarInitials: _extractInitials(fullName),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
      isVerified: false,
      skills: skillsList,
      bio: (json['bio'] as String?) ?? '',
      baseRate: 0.0, // 0.0 -> "Tarifa a convenir"
      serviceRadiusKm: 15,
      district: district,
      phone: (json['phone'] as String?) ?? '',
      dni: '',
      experienceYears: 0,
      reviews: const [],
      isIdVerified: false,
      hasCleanRecord: false,
      offersWarranty: false,
      portfolioCases: const [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      isRealBackendWorker: true,
    );
  }

  WorkerProfile copyWith({
    String? id,
    String? userId,
    String? name,
    String? avatarInitials,
    double? rating,
    int? completedJobs,
    bool? isVerified,
    List<String>? skills,
    String? bio,
    double? baseRate,
    int? serviceRadiusKm,
    String? district,
    String? phone,
    String? dni,
    int? experienceYears,
    List<WorkerReview>? reviews,
    bool? isIdVerified,
    bool? hasCleanRecord,
    bool? offersWarranty,
    List<BeforeAfterCase>? portfolioCases,
    double? latitude,
    double? longitude,
    double? distanceKm,
    bool? isRealBackendWorker,
  }) {
    return WorkerProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      rating: rating ?? this.rating,
      completedJobs: completedJobs ?? this.completedJobs,
      isVerified: isVerified ?? this.isVerified,
      skills: skills ?? this.skills,
      bio: bio ?? this.bio,
      baseRate: baseRate ?? this.baseRate,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      district: district ?? this.district,
      phone: phone ?? this.phone,
      dni: dni ?? this.dni,
      experienceYears: experienceYears ?? this.experienceYears,
      reviews: reviews ?? this.reviews,
      isIdVerified: isIdVerified ?? this.isIdVerified,
      hasCleanRecord: hasCleanRecord ?? this.hasCleanRecord,
      offersWarranty: offersWarranty ?? this.offersWarranty,
      portfolioCases: portfolioCases ?? this.portfolioCases,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      isRealBackendWorker: isRealBackendWorker ?? this.isRealBackendWorker,
    );
  }
}
