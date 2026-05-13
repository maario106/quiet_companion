import 'package:quiet_companion/core/models/user_preferences.dart';

enum UserRole { elder, companion, unassigned }
enum AutonomyStatus { independent, dependent, linked, none }

class UserModel {
  final String id;
  final String? name;
  final UserRole role;
  final AutonomyStatus autonomy;
  final String? linkCode;
  final String? linkedCompanionId;
  final String? linkedElderId;
  final UserPreferences preferences;

  const UserModel({
    required this.id,
    this.name,
    this.role = UserRole.unassigned,
    this.autonomy = AutonomyStatus.none,
    this.linkCode,
    this.linkedCompanionId,
    this.linkedElderId,
    this.preferences = const UserPreferences(),
  });

  static const _unset = Object();

  UserModel copyWith({
    String? id,
    Object? name = _unset,
    UserRole? role,
    AutonomyStatus? autonomy,
    Object? linkCode = _unset,
    Object? linkedCompanionId = _unset,
    Object? linkedElderId = _unset,
    UserPreferences? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name == _unset ? this.name : name as String?,
      role: role ?? this.role,
      autonomy: autonomy ?? this.autonomy,
      linkCode: linkCode == _unset ? this.linkCode : linkCode as String?,
      linkedCompanionId: linkedCompanionId == _unset
          ? this.linkedCompanionId
          : linkedCompanionId as String?,
      linkedElderId: linkedElderId == _unset
          ? this.linkedElderId
          : linkedElderId as String?,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role.name,
      'autonomy': autonomy.name,
      'linkCode': linkCode,
      'linkedCompanionId': linkedCompanionId,
      'linkedElderId': linkedElderId,
      'preferences': preferences.toMap(),
    };
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      id: id,
      name: map['name'] as String?,
      role: UserRole.values.byName(map['role'] as String? ?? 'unassigned'),
      autonomy: AutonomyStatus.values.byName(map['autonomy'] as String? ?? 'none'),
      linkCode: map['linkCode'] as String?,
      linkedCompanionId: map['linkedCompanionId'] as String?,
      linkedElderId: map['linkedElderId'] as String?,
      preferences: map['preferences'] != null
          ? UserPreferences.fromMap(map['preferences'])
          : const UserPreferences(),
    );
  }
}
