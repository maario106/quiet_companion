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

  /// Teléfono propio del usuario en E.164. Hoy solo lo rellena el familiar
  /// en su registro; es la fuente de la desnormalización de [emergencyContact]
  /// en el documento del mayor al vincular.
  final String? phoneNumber;

  /// Contacto de emergencia del mayor. null es un estado legal y permanente:
  /// mayor que aún no ha configurado nada, o documento anterior a esta
  /// feature. El camino null-safe es el mismo en ambos casos.
  final EmergencyContact? emergencyContact;

  /// Respuesta del mayor a guardar sus conversaciones. null = nunca ha
  /// respondido, y el enrutador le enseña la pregunta (ADR-0030). Lo escribe
  /// solo el servidor: [toMap] no lo incluye nunca.
  final ConversationConsent? conversationConsent;

  /// Qué ve el familiar del análisis (ADR-0031). Lo escribe solo el mayor.
  final CompanionSharing? companionSharing;

  /// Plazos de la conversación (ADR-0034). null = valores por defecto; léase
  /// siempre por [effectiveConversationSettings].
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
      // Se omite la clave cuando es null para no crear el campo en los
      // documentos que no lo necesitan.
      if (emergencyContact != null)
        'emergencyContact': emergencyContact!.toMap(),
      if (companionSharing != null) 'companionSharing': companionSharing!.name,
      if (conversationSettings != null)
        'conversationSettings': conversationSettings!.toMap(),
      // `conversationConsent` no se escribe nunca desde aquí: es un registro
      // del servidor y las reglas deniegan que un cliente lo toque. Los únicos
      // `set()` completos que quedan (onboarding) ocurren antes de que exista.
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
