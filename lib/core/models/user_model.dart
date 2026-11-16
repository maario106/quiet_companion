import 'package:quiet_companion/core/models/companion_sharing.dart';
import 'package:quiet_companion/core/models/conversation_consent.dart';
import 'package:quiet_companion/core/models/conversation_settings.dart';
import 'package:quiet_companion/core/models/emergency_contact.dart';
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

  /// Teléfono del familiar en E.164; al vincular se copia como contacto de emergencia.
  final String? phoneNumber;

  /// null si el mayor no ha configurado contacto.
  final EmergencyContact? emergencyContact;

  /// null si nunca ha respondido. Solo lo escribe el servidor.
  final ConversationConsent? conversationConsent;

  /// Qué ve el familiar del análisis. Solo lo escribe el mayor.
  final CompanionSharing? companionSharing;

  /// null = valores por defecto; usar [effectiveConversationSettings].
  final ConversationSettings? conversationSettings;

  const UserModel({
    required this.id,
    this.name,
    this.role = UserRole.unassigned,
    this.autonomy = AutonomyStatus.none,
    this.linkCode,
    this.linkedCompanionId,
    this.linkedElderId,
    this.preferences = const UserPreferences(),
    this.phoneNumber,
    this.emergencyContact,
    this.conversationConsent,
    this.companionSharing,
    this.conversationSettings,
  });

  ConversationSettings get effectiveConversationSettings =>
      conversationSettings ?? const ConversationSettings();

  /// Consentimiento vigente: el análisis corre y el familiar puede mirar.
  bool get hasConversationConsent => conversationConsent?.granted == true;

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
    Object? phoneNumber = _unset,
    Object? emergencyContact = _unset,
    Object? conversationConsent = _unset,
    Object? companionSharing = _unset,
    Object? conversationSettings = _unset,
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
      phoneNumber:
          phoneNumber == _unset ? this.phoneNumber : phoneNumber as String?,
      emergencyContact: emergencyContact == _unset
          ? this.emergencyContact
          : emergencyContact as EmergencyContact?,
      conversationConsent: conversationConsent == _unset
          ? this.conversationConsent
          : conversationConsent as ConversationConsent?,
      companionSharing: companionSharing == _unset
          ? this.companionSharing
          : companionSharing as CompanionSharing?,
      conversationSettings: conversationSettings == _unset
          ? this.conversationSettings
          : conversationSettings as ConversationSettings?,
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
      'phoneNumber': phoneNumber,
      if (emergencyContact != null)
        'emergencyContact': emergencyContact!.toMap(),
      if (companionSharing != null) 'companionSharing': companionSharing!.name,
      if (conversationSettings != null)
        'conversationSettings': conversationSettings!.toMap(),
      // conversationConsent nunca se escribe desde el cliente.
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
      phoneNumber: map['phoneNumber'] as String?,
      emergencyContact: EmergencyContact.fromMapOrNull(map['emergencyContact']),
      conversationConsent:
          ConversationConsent.fromMapOrNull(map['conversationConsent']),
      companionSharing: CompanionSharing.fromNameOrNull(map['companionSharing']),
      conversationSettings:
          ConversationSettings.fromMapOrNull(map['conversationSettings']),
    );
  }
}
