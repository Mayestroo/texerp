import 'package:equatable/equatable.dart';

/// Request body for POST /auth/login.
class LoginRequest {
  const LoginRequest({required this.phone, required this.pin});

  final String phone;
  final String pin;

  Map<String, dynamic> toJson() => {'phone': phone, 'pin': pin};
}

/// Response body for POST /auth/login and POST /auth/refresh.
class LoginResponse extends Equatable {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserProfile user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return LoginResponse(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiresIn: data['expires_in'] as int? ?? 900,
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresIn, user];
}

/// Lightweight department reference returned with a user profile.
class Department extends Equatable {
  const Department({
    required this.id,
    required this.name,
    this.code,
    this.isActive,
    this.foremanName,
    this.workerCount,
  });

  final String id;
  final String name;
  final String? code;
  final bool? isActive;
  final String? foremanName;
  final int? workerCount;

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      isActive: json['is_active'] as bool?,
      foremanName: (json['foreman'] as Map<String, dynamic>?)?['full_name'] as String?,
      workerCount: json['worker_count'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, name, code, isActive, foremanName, workerCount];
}

/// Lightweight foreman reference returned with a worker profile.
class Foreman extends Equatable {
  const Foreman({required this.id, required this.fullName, this.phone});

  final String id;
  final String fullName;
  final String? phone;

  factory Foreman.fromJson(Map<String, dynamic> json) {
    return Foreman(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, fullName, phone];
}

/// Authenticated user profile shared between auth and profile features.
class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.workerCode,
    required this.role,
    required this.status,
    this.avatarUrl,
    this.department,
    this.foreman,
  });

  final String id;
  final String fullName;
  final String phone;
  final String workerCode;
  final String role;
  final String status;
  final String? avatarUrl;
  final Department? department;
  final Foreman? foreman;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String? ?? '',
      workerCode: json['worker_code'] as String? ?? '',
      role: json['role'] as String,
      status: json['status'] as String? ?? 'ACTIVE',
      avatarUrl: json['avatar_url'] as String?,
      department: json['department'] == null
          ? null
          : Department.fromJson(json['department'] as Map<String, dynamic>),
      foreman: json['foreman'] == null
          ? null
          : Foreman.fromJson(json['foreman'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        phone,
        workerCode,
        role,
        status,
        avatarUrl,
        department,
        foreman,
      ];
}
