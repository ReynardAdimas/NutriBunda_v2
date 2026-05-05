import 'package:equatable/equatable.dart';
import '../user_model.dart';

/// Local User Model with sync tracking
/// Extends UserModel with local database fields
class LocalUserModel extends Equatable {
  final int? id; // Local SQLite ID
  final String? serverId; // Server UUID
  final String email;
  final String fullName;
  final double? weight;
  final double? height;
  final int? age;
  final bool isBreastfeeding;
  final String activityLevel;
  final String? profileImageUrl;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus; // 'synced', 'pending', 'failed'

  // --- Data bayi ---
  final DateTime? babyBirthDate;
  final double? babyWeightKg;

  const LocalUserModel({
    this.id,
    this.serverId,
    required this.email,
    required this.fullName,
    this.weight,
    this.height,
    this.age,
    this.isBreastfeeding = false,
    this.activityLevel = 'sedentary',
    this.profileImageUrl,
    this.timezone = 'WIB',
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
    this.babyBirthDate,
    this.babyWeightKg,
  });

  /// Create from UserModel (from server)
  factory LocalUserModel.fromUserModel(UserModel user) {
    return LocalUserModel(
      serverId: user.id,
      email: user.email,
      fullName: user.fullName,
      weight: user.weight,
      height: user.height,
      age: user.age,
      isBreastfeeding: user.isBreastfeeding,
      activityLevel: user.activityLevel,
      profileImageUrl: user.profileImageUrl,
      timezone: user.timezone,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      syncStatus: 'synced',
      babyBirthDate: user.babyBirthDate,
      babyWeightKg: user.babyWeightKg,
    );
  }

  /// Convert to UserModel (for API)
  UserModel toUserModel() {
    return UserModel(
      id: serverId ?? '',
      email: email,
      fullName: fullName,
      weight: weight,
      height: height,
      age: age,
      isBreastfeeding: isBreastfeeding,
      activityLevel: activityLevel,
      profileImageUrl: profileImageUrl,
      timezone: timezone,
      createdAt: createdAt,
      updatedAt: updatedAt,
      babyBirthDate: babyBirthDate,
      babyWeightKg: babyWeightKg,
    );
  }

  /// Create from SQLite map
  factory LocalUserModel.fromMap(Map<String, dynamic> map) {
    return LocalUserModel(
      id: map['id'] as int?,
      serverId: map['server_id'] as String?,
      email: map['email'] as String,
      fullName: map['full_name'] as String,
      weight: map['weight'] as double?,
      height: map['height'] as double?,
      age: map['age'] as int?,
      isBreastfeeding: (map['is_breastfeeding'] as int) == 1,
      activityLevel: map['activity_level'] as String? ?? 'sedentary',
      profileImageUrl: map['profile_image_url'] as String?,
      timezone: map['timezone'] as String? ?? 'WIB',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as String? ?? 'synced',
      babyBirthDate: map['baby_birth_date'] != null
          ? DateTime.tryParse(map['baby_birth_date'] as String)
          : null,
      babyWeightKg: map['baby_weight_kg'] as double?,
    );
  }

  /// Convert to SQLite map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'server_id': serverId,
      'email': email,
      'full_name': fullName,
      'weight': weight,
      'height': height,
      'age': age,
      'is_breastfeeding': isBreastfeeding ? 1 : 0,
      'activity_level': activityLevel,
      'profile_image_url': profileImageUrl,
      'timezone': timezone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
      'baby_birth_date': babyBirthDate?.toIso8601String().substring(0, 10),
      'baby_weight_kg': babyWeightKg,
    };
  }

  /// Copy with updated fields
  LocalUserModel copyWith({
    int? id,
    String? serverId,
    String? email,
    String? fullName,
    double? weight,
    double? height,
    int? age,
    bool? isBreastfeeding,
    String? activityLevel,
    String? profileImageUrl,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? syncStatus,
    DateTime? babyBirthDate,
    double? babyWeightKg,
  }) {
    return LocalUserModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      age: age ?? this.age,
      isBreastfeeding: isBreastfeeding ?? this.isBreastfeeding,
      activityLevel: activityLevel ?? this.activityLevel,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      babyBirthDate: babyBirthDate ?? this.babyBirthDate,
      babyWeightKg: babyWeightKg ?? this.babyWeightKg,
    );
  }

  @override
  List<Object?> get props => [
        id,
        serverId,
        email,
        fullName,
        weight,
        height,
        age,
        isBreastfeeding,
        activityLevel,
        profileImageUrl,
        timezone,
        createdAt,
        updatedAt,
        syncStatus,
        babyBirthDate,
        babyWeightKg,
      ];
}