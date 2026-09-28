import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Respuesta del mayor a "¿guardo un resumen de nuestras conversaciones?"
/// (ADR-0030).
///
/// **Solo lo escribe el servidor** (`setConversationConsent`, con la hora del
/// servidor como prueba) y las reglas impiden que ningún cliente lo toque. Por
/// eso no tiene `toMap`: el cliente lo lee, nunca lo escribe.
///
/// `null` en el `UserModel` significa "nunca ha respondido", y es lo que hace
/// que el enrutador enseñe la pregunta. "Ahora no" es una respuesta: se guarda
/// con `granted: false` para no volver a preguntar.
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

  /// Fecha a partir de la cual lo guardado se borra, si retiró el
  /// consentimiento y no ha vuelto a darlo. La calcula el servidor al retirar
  /// (mitad del plazo de conservación, ADR-0030) y el mayor la ve en Ajustes.
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
