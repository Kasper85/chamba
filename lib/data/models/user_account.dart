class WorkerProfileData {
  final String id;
  final String? bio;
  final String? district;
  final String? specialty;
  final bool isAvailable;
  final double rating;
  final int completedJobs;

  const WorkerProfileData({
    required this.id,
    this.bio,
    this.district,
    this.specialty,
    this.isAvailable = true,
    this.rating = 5.0,
    this.completedJobs = 0,
  });

  factory WorkerProfileData.fromJson(Map<String, dynamic> json) {
    return WorkerProfileData(
      id: json['id'] as String,
      bio: json['bio'] as String?,
      district: json['district'] as String?,
      specialty: json['specialty'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobs: (json['completedJobs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bio': bio,
      'district': district,
      'specialty': specialty,
      'isAvailable': isAvailable,
      'rating': rating,
      'completedJobs': completedJobs,
    };
  }
}

class UserAccount {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? district;
  final String? address;
  final String status;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final WorkerProfileData? workerProfile;

  const UserAccount({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.district,
    this.address,
    this.status = 'ACTIVE',
    this.role = 'CLIENT',
    this.createdAt,
    this.updatedAt,
    this.workerProfile,
  });

  String get avatarInitials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'CH';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool get hasWorkerProfile => workerProfile != null;

  bool get isSupport => role.toUpperCase() == 'SUPPORT' || role.toUpperCase() == 'ADMIN';

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      district: json['district'] as String?,
      address: json['address'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      role: json['role'] as String? ?? 'CLIENT',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      workerProfile: json['workerProfile'] != null
          ? WorkerProfileData.fromJson(json['workerProfile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'district': district,
      'address': address,
      'status': status,
      'role': role,
      'createdAt':  createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'workerProfile': workerProfile?.toJson(),
    };
  }

  UserAccount copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? district,
    String? address,
    String? status,
    String? role,
    WorkerProfileData? workerProfile,
  }) {
    return UserAccount(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      district: district ?? this.district,
      address: address ?? this.address,
      status: status ?? this.status,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      workerProfile: workerProfile ?? this.workerProfile,
    );
  }
}
