enum UserRole { elder, companion, unassigned }
enum AutonomyStatus { independent, dependent, linked, none }

class UserModel {
  final String id; // Proporcionado por Firebase
  final UserRole role;
  final AutonomyStatus autonomy;
  final String? linkCode;

  const UserModel({
    required this.id,
    this.role = UserRole.unassigned,
    this.autonomy = AutonomyStatus.none,
    this.linkCode,
  });

  UserModel copyWith ({
    String? id,
    UserRole? role,
    AutonomyStatus? autonomy,
    String? linkCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      role: role ?? this.role,
      autonomy: autonomy ?? this.autonomy,
      linkCode: linkCode ?? this.linkCode,
    );
  }
}