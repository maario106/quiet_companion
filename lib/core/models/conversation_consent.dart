import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Respuesta del mayor al consentimiento sobre sus conversaciones. Solo la
/// escribe el servidor; null en [UserModel] significa que nunca ha respondido.
class ConversationConsent {
  const ConversationConsent({
    required this.granted,
    this.answeredAt,
    this.textVersion = 0,
    this.revokedAt,
    this.deleteAfter,
  });

  final bool granted;
  final DateTime? answeredAt;

  /// Versión del texto que leyó el mayor al responder.
  final int textVersion;

  /// Solo si lo concedió y después lo retiró.
  final DateTime? revokedAt;

  /// Fecha de borrado de lo guardado tras retirar el consentimiento.
  final DateTime? deleteAfter;

  /// Retirado, con datos congelados a la espera de borrarse.
  bool get isPendingDeletion => !granted && deleteAfter != null;

  static ConversationConsent? fromMapOrNull(Object? raw) {
    if (raw is! Map) return null;
    final granted = raw['granted'];
    if (granted is! bool) return null;
    final version = raw['textVersion'];
    return ConversationConsent(
      granted: granted,
      answeredAt: _date(raw['answeredAt']),
      textVersion: version is num ? version.toInt() : 0,
      revokedAt: _date(raw['revokedAt']),
      deleteAfter: _date(raw['deleteAfter']),
    );
  }

  static DateTime? _date(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
